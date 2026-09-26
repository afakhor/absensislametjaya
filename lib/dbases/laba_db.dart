import 'package:drift/drift.dart';
import 'localdatabase.dart';
import 'gaji_db.dart';

extension LabaDao on AppDatabase {
  /// Menghitung akumulasi Laba Rugi Bulanan berdasarkan LaporanHarian & Transaksi
  Future<Map<String, int>> hitungLabaBulanan(DateTime bulan) async {
    // Batas awal bulan (Tgl 1 jam 00:00:00)
    final awal = DateTime(bulan.year, bulan.month, 1, 0, 0, 0);
    // Batas akhir bulan (Tgl terakhir jam 23:59:59.999) secara akurat
    final akhir = DateTime(bulan.year, bulan.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));

    // 1. Ambil data dari Laporan Harian
    final laporanList = await (select(laporanHarian)
          ..where((t) => t.tanggal.isBiggerOrEqualValue(awal))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(akhir)))
        .get();

    int totalOmset = 0;
    int totalPemasukanLain = 0;
    int totalBebanOps = 0;
    int totalBebanGaji = 0;

    if (laporanList.isNotEmpty) {
      for (var l in laporanList) {
        totalOmset += l.totalPenjualan;
        totalPemasukanLain += l.tambahanLain;
        totalBebanOps += l.bebanOperasional;
        totalBebanGaji += l.totalGajiHariIni;
      }
    } else {
      // 2. Fallback: Ambil data dari tabel Transaksi jika Laporan Harian belum direkap
      final transaksiList = await (select(transaksi)
            ..where((t) => t.tanggal.isBiggerOrEqualValue(awal))
            ..where((t) => t.tanggal.isSmallerOrEqualValue(akhir)))
          .get();

      for (var trx in transaksiList) {
        if (trx.jenis.toUpperCase() == 'PEMASUKAN' || trx.jenis.toUpperCase() == 'OMSET') {
          totalOmset += trx.nominal;
        } else if (trx.jenis.toUpperCase() == 'PENGELUARAN' || trx.jenis.toUpperCase() == 'BEBAN') {
          totalBebanOps += trx.nominal;
        } else if (trx.jenis.toUpperCase() == 'LAIN') {
          totalPemasukanLain += trx.nominal;
        }
      }

      // Hitung beban gaji dari rekapitulasi penggajian/absensi periode bulan ini
      totalBebanGaji = await hitungBebanGajiPeriode(awal, akhir);
    }

    // Perhitungan Laba Kotor (10% dari total omset)
    int labaKotor = (totalOmset * 0.10).round();

    // LABA BERSIH = Laba Kotor + Pemasukan Lain - Beban Gaji - Beban Operasional
    int labaBersih = labaKotor + totalPemasukanLain - totalBebanGaji - totalBebanOps;

    return {
      'pendapatan': totalOmset,
      'pemasukanLain': totalPemasukanLain,
      'bebanGaji': totalBebanGaji,
      'bebanOps': totalBebanOps,
      'labaKotor': labaKotor,
      'labaBersih': labaBersih,
    };
  }

  /// Menghitung total beban gaji berdasarkan rentang tanggal
  Future<int> hitungBebanGajiPeriode(DateTime mulai, DateTime selesai) async {
    final start = DateTime(mulai.year, mulai.month, mulai.day, 0, 0, 0);
    final end = DateTime(selesai.year, selesai.month, selesai.day, 23, 59, 59, 999);

    final data = await (select(gajiMingguan)
          ..where((t) => t.mingguMulai.isBiggerOrEqualValue(start))
          ..where((t) => t.mingguSelesai.isSmallerOrEqualValue(end)))
        .get();

    if (data.isNotEmpty) {
      return data.fold<int>(0, (sum, e) => sum + e.totalGaji);
    }

    // Jika gaji mingguan belum dihitung, hitung dari absensi harian
    final absenList = await (select(absensi)
          ..where((t) => t.jamMasuk.isBiggerOrEqualValue(start))
          ..where((t) => t.jamMasuk.isSmallerOrEqualValue(end)))
        .get();

    if (absenList.isEmpty) return 0;

    final allKar = await select(karyawan).get();
    final allKat = await select(kategoriKaryawan).get();

    int totalGajiAbsen = 0;
    for (var a in absenList) {
      final kar = allKar.where((k) => k.id == a.karyawanId).firstOrNull;
      if (kar == null) continue;
      final kat = allKat.where((k) => k.id == kar.kategoriId).firstOrNull;
      if (kat == null) continue;

      int tarif = kat.tarifPerHari;
      totalGajiAbsen += (a.tipeKerja == 'FULL' ? tarif : (tarif ~/ 2));
    }

    return totalGajiAbsen;
  }

  // --- Simulasi Laba ---
  Future<int> simpanSimulasi(SimulasiLabaCompanion data) =>
      into(simulasiLaba).insert(data);

  Future<void> updateSimulasi(int id, SimulasiLabaCompanion data) =>
      (update(simulasiLaba)..where((t) => t.id.equals(id))).write(data);

  Future<void> hapusSimulasi(int id) =>
      (delete(simulasiLaba)..where((t) => t.id.equals(id))).go();

  Stream<List<SimulasiLabaData>> watchSimulasi() =>
      (select(simulasiLaba)
            ..orderBy([(t) => OrderingTerm.desc(t.tanggalSimulasi)]))
          .watch();
}
