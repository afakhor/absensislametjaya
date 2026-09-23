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

      final absenMinggu = await (select(absensi)..where((t) => t.karyawanId.equals(kar.id) & t.jamMasuk.isBetweenValues(seninStart, mingguEnd))).get();
      if (absenMinggu.isEmpty) continue;

      double hariEfektif = 0;
      for (var a in absenMinggu) { hariEfektif += (a.tipeKerja == 'SETENGAH' ? 0.5 : 1.0); }
      int gajiPokok = (hariEfektif * kat.tarifPerHari).toInt();

      final existing = await (select(gajiMingguan)..where((t) => t.karyawanId.equals(kar.id) & t.mingguMulai.equals(seninStart))).getSingleOrNull();
      if (existing == null) {
        await into(gajiMingguan).insert(GajiMingguanCompanion.insert(
          karyawanId: kar.id, mingguMulai: seninStart, mingguSelesai: mingguEnd,
          totalHariEfektif: Value(hariEfektif), totalHariMasuk: Value(absenMinggu.length),
          totalJam: Value(absenMinggu.fold(0.0, (p, e) => p + e.totalJamKerja)),
          totalGajiPokok: Value(gajiPokok), bonusMingguan: const Value(0), totalGaji: gajiPokok, totalBonus: const Value(0),
          statusBayar: const Value('BELUM'),
        ));
      } else {
        await (update(gajiMingguan)..where((t) => t.id.equals(existing.id))).write(
          GajiMingguanCompanion(
            totalHariEfektif: Value(hariEfektif), totalHariMasuk: Value(absenMinggu.length),
            totalGajiPokok: Value(gajiPokok), totalGaji: Value(gajiPokok + existing.bonusMingguan),
          ),
        );
      }
    }
  }

  Future<void> inputBonusMingguan(int gajiId, int bonus) async {
    final g = await (select(gajiMingguan)..where((t) => t.id.equals(gajiId))).getSingle();
    await (update(gajiMingguan)..where((t) => t.id.equals(gajiId))).write(
      GajiMingguanCompanion(bonusMingguan: Value(bonus), totalBonus: Value(bonus), totalGaji: Value(g.totalGajiPokok + bonus)),
    );
  }

  Future<void> tandaiBayar(int gajiId, String status) async {
    await (update(gajiMingguan)..where((t) => t.id.equals(gajiId))).write(
      GajiMingguanCompanion(statusBayar: Value(status), tanggalBayar: Value(DateTime.now())),
    );
  }

  Stream<List<GajiMingguanData>> watchGaji() => select(gajiMingguan).watch();
  Future<int> getTotalGajianSemua() async => (await select(gajiMingguan).get()).fold(0, (p, e) => p + e.totalGaji);

  // UNTUK HALAMAN LABA - AKUMULASI DARI AWAL SAMPAI CONTINUE
  Future<int> getAkumulasiBebanGaji({int? karyawanId, int? kategoriId, DateTime? mulai, DateTime? selesai}) async {
    var q = select(gajiMingguan);
    if (karyawanId != null) q.where((t) => t.karyawanId.equals(karyawanId));
    if (mulai != null) q.where((t) => t.mingguMulai.isBiggerOrEqualValue(mulai));
    if (selesai != null) q.where((t) => t.mingguSelesai.isSmallerOrEqualValue(selesai));
    var list = await q.get();
    if (kategoriId != null) {
      final ids = (await (select(karyawan)..where((k) => k.kategoriId.equals(kategoriId))).get()).map((e) => e.id).toSet();
      list = list.where((g) => ids.contains(g.karyawanId)).toList();
    }
    return list.fold(0, (p, e) => p + e.totalGaji);
  }
}