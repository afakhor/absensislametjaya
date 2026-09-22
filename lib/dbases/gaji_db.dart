import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension GajiDao on AppDatabase {
  Future<void> prosesHitungGajiMingguan() async {
    final now = DateTime.now();
    final senin = now.subtract(Duration(days: now.weekday - 1));
    final seninStart = DateTime(senin.year, senin.month, senin.day);
    final mingguEnd = seninStart.add(const Duration(days: 6, hours: 23, minutes: 59));
    for (var kat in await select(kategoriKaryawan).get()) {
      for (var kar in await (select(karyawan)..where((t) => t.kategoriId.equals(kat.id))).get()) {
        final absenMinggu = await (select(absensi)..where((t) => t.karyawanId.equals(kar.id) & t.jamMasuk.isBiggerOrEqualValue(seninStart) & t.jamMasuk.isSmallerOrEqualValue(mingguEnd))).get();
        double totalJam = absenMinggu.fold(0.0, (p, e) => p + e.totalJamKerja);
        int totalGaji = (totalJam * kat.tarifPerJam).toInt();
        await (delete(gajiMingguan)..where((t) => t.karyawanId.equals(kar.id) & t.mingguMulai.equals(seninStart))).go();
        if (totalJam > 0) {
          await into(gajiMingguan).insert(GajiMingguanCompanion.insert(karyawanId: kar.id, mingguMulai: seninStart, mingguSelesai: mingguEnd, totalJam: totalJam, totalGaji: totalGaji));
        }
      }
    }
  }

  Stream<List<GajiMingguanData>> watchGaji() => select(gajiMingguan).watch();
}