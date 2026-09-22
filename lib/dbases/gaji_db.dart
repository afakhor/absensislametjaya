import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension GajiDao on AppDatabase {
  Future<void> prosesHitungGajiMingguan() async {
    final now = DateTime.now();
    final senin = now.subtract(Duration(days: now.weekday - 1));
    final seninStart = DateTime(senin.year, senin.month, senin.day);
    final mingguEnd = seninStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    final allKaryawan = await select(karyawan).get();
    for (var kar in allKaryawan) {
      final kat = await (select(kategoriKaryawan)..where((t) => t.id.equals(kar.kategoriId))).getSingleOrNull();
      if (kat == null) continue;

      final absenMinggu = await (select(absensi)
            ..where((t) => t.karyawanId.equals(kar.id) & t.jamMasuk.isBetweenValues(seninStart, mingguEnd)))
          .get();

      if (absenMinggu.isEmpty) {
        await (delete(gajiMingguan)..where((t) => t.karyawanId.equals(kar.id) & t.mingguMulai.equals(seninStart))).go();
        continue;
      }

      double totalJam = absenMinggu.fold(0.0, (p, e) => p + e.totalJamKerja);
      int totalBonus = absenMinggu.fold(0, (p, e) => p + e.bonus);
      int gajiPokok = (totalJam * kat.tarifPerJam).toInt();
      int totalGaji = gajiPokok + totalBonus;

      final existing = await (select(gajiMingguan)
            ..where((t) => t.karyawanId.equals(kar.id) & t.mingguMulai.equals(seninStart)))
          .getSingleOrNull();

      if (existing == null) {
        await into(gajiMingguan).insert(GajiMingguanCompanion.insert(
          karyawanId: kar.id,
          mingguMulai: seninStart,
          mingguSelesai: mingguEnd,
          totalJam: totalJam,
          totalGaji: totalGaji,
          totalBonus: Value(totalBonus),
          totalHariMasuk: Value(absenMinggu.length),
        ));
      } else {
        await (update(gajiMingguan)..where((t) => t.id.equals(existing.id))).write(
          GajiMingguanCompanion(
            totalJam: Value(totalJam),
            totalGaji: Value(totalGaji),
            totalBonus: Value(totalBonus),
            totalHariMasuk: Value(absenMinggu.length),
          ),
        );
      }
    }
  }

  Stream<List<GajiMingguanData>> watchGaji() => select(gajiMingguan).watch();

  Future<int> getTotalGajianSemua() async {
    final all = await select(gajiMingguan).get();
    int total = 0;
    for (var e in all) { total += e.totalGaji; }
    return total;
  }
}