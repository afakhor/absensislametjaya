import 'localdatabase.dart';
import 'package:drift/drift.dart';

extension LabaDao on AppDatabase {
  // KODE LAMAMU - TETAP DIPAKAI
  Future<Map<String, int>> hitungLabaBulanan(DateTime bulan) async {
    final awal = DateTime(bulan.year, bulan.month, 1);
    final akhir = DateTime(bulan.year, bulan.month + 1, 0, 23, 59);
    final gajiBulan = await (select(gajiMingguan)..where((t) => t.mingguMulai.isBiggerOrEqualValue(awal) & t.mingguMulai.isSmallerOrEqualValue(akhir))).get();
    int bebanGaji = gajiBulan.fold(0, (p, e) => p + e.totalGaji);
    final pendapatanList = await (select(transaksi)..where((t) => t.jenis.equals('PENDAPATAN') & t.tanggal.isBetweenValues(awal, akhir))).get();
    int pendapatan = pendapatanList.fold(0, (p, e) => p + e.nominal);
    final bebanOpsList = await (select(transaksi)..where((t) => t.jenis.equals('BEBAN_OPERASIONAL') & t.tanggal.isBetweenValues(awal, akhir))).get();
    int bebanOps = bebanOpsList.fold(0, (p, e) => p + e.nominal);
    return {'pendapatan': pendapatan, 'bebanGaji': bebanGaji, 'bebanOps': bebanOps, 'labaKotor': pendapatan - bebanGaji, 'labaBersih': pendapatan - bebanGaji - bebanOps};
  }

  // KODE BARU - KALKULATOR SIMULASI PER PERIODE
  Future<int> hitungBebanGajiPeriode(DateTime mulai, DateTime selesai) async {
    final data = await (select(gajiMingguan)..where((t) => t.mingguMulai.isBiggerOrEqualValue(mulai) & t.mingguSelesai.isSmallerOrEqualValue(selesai))).get();
    return data.fold<int>(0, (sum, e) => sum + e.totalGaji);
  }

  Future<int> simpanSimulasi(SimulasiLabaCompanion data) => into(simulasiLaba).insert(data);
  Future<void> updateSimulasi(int id, SimulasiLabaCompanion data) => (update(simulasiLaba)..where((t) => t.id.equals(id))).write(data);
  Future<void> hapusSimulasi(int id) => (delete(simulasiLaba)..where((t) => t.id.equals(id))).go();
  Stream<List<SimulasiLabaData>> watchSimulasi() => (select(simulasiLaba)..orderBy([(t) => OrderingTerm.desc(t.tanggalSimulasi)])).watch();
}