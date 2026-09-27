import 'package:drift/drift.dart';
import 'localdatabase.dart';
import 'gaji_db.dart';

extension LabaDao on AppDatabase {
  /// Menghitung akumulasi Laba Rugi Bulanan secara konsisten
  /// Sinkron dengan logika tanggal pada Kalender Absensi
  Future<Map<String, int>> hitungLabaBulanan(DateTime bulan) async {
    // Batas awal bulan (00:00:00 hari pertama)
    final awal = DateTime(bulan.year, bulan.month, 1, 0, 0, 0);
    // Batas akhir bulan (23:59:59 hari terakhir bulan tersebut)
    final akhir = DateTime(bulan.year, bulan.month + 1, 0, 23, 59, 59, 999);

    int totalOmset = 0;
    int totalPemasukanLain = 0;
    int totalBebanOps = 0;
    int totalBebanGaji = 0;

    // -------------------------------------------------------------
    // 1. Ambil Data dari Laporan Harian
    // -------------------------------------------------------------
    final laporanList = await (select(laporanHarian)
          ..where((t) => t.tanggal.isBiggerOrEqualValue(awal))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(akhir)))
        .get();

    for (var l in laporanList) {
      totalOmset += l.totalPenjualan;
      totalPemasukanLain += l.tambahanLain;
      totalBebanOps += l.bebanOperasional;
      totalBebanGaji += l.totalGajiHariIni;
    }

    // -------------------------------------------------------------
    // 2. Ambil Data Tambahan dari Tabel Transaksi (jika ada)
    // -------------------------------------------------------------
    final transaksiList = await (select(transaksi)
          ..where((t) => t.tanggal.isBiggerOrEqualValue(awal))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(akhir)))
        .get();

    for (var trx in transaksiList) {
      final jenis = trx.jenis.toUpperCase();
      if (jenis == 'PEMASUKAN' || jenis == 'OMSET') {
        totalOmset += trx.nominal;
      } else if (jenis == 'PENGELUARAN' || jenis == 'BEBAN') {
        totalBebanOps += trx.nominal;
      } else if (jenis == 'LAIN') {
        totalPemasukanLain += trx.nominal;
      }
    }

    // -------------------------------------------------------------
    // 3. Jika Beban Gaji masih 0, Hitung Langsung dari Absensi Harian
    // -------------------------------------------------------------
    if (totalBebanGaji == 0) {
      totalBebanGaji = await hitungBebanGajiPeriode(awal, akhir);
    }

    // Kalkulasi Laba Kotor (10% dari Omset Penjualan)
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

  /// Menghitung total beban gaji karyawan berdasarkan rentang tanggal
  Future<int> hitungBebanGajiPeriode(DateTime mulai, DateTime selesai) async {
    final start = DateTime(mulai.year, mulai.month, mulai.day, 0, 0, 0);
    final end = DateTime(selesai.year, selesai.month, selesai.day, 23, 59, 59, 999);

    // Kueri 1: Cek Rekapitulasi Gaji Mingguan
    final dataGaji = await (select(gajiMingguan)
          ..where((t) => t.mingguMulai.isBiggerOrEqualValue(start))
          ..where((t) => t.mingguSelesai.isSmallerOrEqualValue(end)))
        .get();

    if (dataGaji.isNotEmpty) {
      final sumGaji = dataGaji.fold<int>(0, (sum, e) => sum + e.totalGaji);
      if (sumGaji > 0) return sumGaji;
    }

    // Kueri 2: Hitung langsung dari Log Absensi (Normalized Date Matching)
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

  // --- CRUD Simulasi Laba ---
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
