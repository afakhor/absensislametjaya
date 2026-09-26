import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension LabaDao on AppDatabase {
  /// Menghitung akumulasi Laba Rugi Bulanan berdasarkan data LaporanHarian
  Future<Map<String, int>> hitungLabaBulanan(DateTime bulan) async {
    final awal = DateTime(bulan.year, bulan.month, 1, 0, 0, 0);
    final akhir = DateTime(bulan.year, bulan.month + 1, 0, 23, 59, 59, 999);

    // Ambil semua laporan harian dalam rentang bulan yang dipilih
    final laporanList = await (select(laporanHarian)
          ..where((t) => t.tanggal.isBiggerOrEqualValue(awal))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(akhir)))
        .get();

    int totalOmset = 0;
    int totalPemasukanLain = 0;
    int totalBebanOps = 0;
    int totalBebanGaji = 0;

    for (var l in laporanList) {
      totalOmset += l.totalPenjualan;
      totalPemasukanLain += l.tambahanLain;
      totalBebanOps += l.bebanOperasional;
      totalBebanGaji += l.totalGajiHariIni;
    }

    // Kalkulasi Margin Laba Kotor 10%
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

  /// Menghitung total beban gaji mingguan berdasarkan rentang tanggal tertentu
  Future<int> hitungBebanGajiPeriode(DateTime mulai, DateTime selesai) async {
    final start = DateTime(mulai.year, mulai.month, mulai.day, 0, 0, 0);
    final end = DateTime(selesai.year, selesai.month, selesai.day, 23, 59, 59, 999);

    final data = await (select(gajiMingguan)
          ..where((t) => t.mingguMulai.isBiggerOrEqualValue(start))
          ..where((t) => t.mingguSelesai.isSmallerOrEqualValue(end)))
        .get();

    return data.fold<int>(0, (sum, e) => sum + e.totalGaji);
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
