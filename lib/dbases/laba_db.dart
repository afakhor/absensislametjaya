import 'localdatabase.dart';
import 'package:drift/drift.dart';

extension LabaDao on AppDatabase {
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
}