import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension GajiDao on AppDatabase {
  /// Input atau Update Kasbon Harian Karyawan
  Future<void> simpanKasbonHarian(int karyawanId, DateTime tgl, int nominal, String ket) async {
    final start = DateTime(tgl.year, tgl.month, tgl.day, 0, 0, 0);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59, 999);

    final ex = await (select(kasbonHarian)
          ..where((t) => t.karyawanId.equals(karyawanId))
          ..where((t) => t.tanggal.isBiggerOrEqualValue(start))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(end)))
        .getSingleOrNull();

    if (ex == null) {
      await into(kasbonHarian).insert(KasbonHarianCompanion.insert(
        karyawanId: karyawanId,
        tanggal: start,
        nominal: Value(nominal),
        keterangan: Value(ket),
      ));
    } else {
      await (update(kasbonHarian)..where((t) => t.id.equals(ex.id))).write(
        KasbonHarianCompanion(
          nominal: Value(nominal),
          keterangan: Value(ket),
        ),
      );
    }
  }

  /// Ambil Total Kasbon Karyawan dalam Rentang Tanggal Mingguan
  Future<int> getKasbonPeriode(int karyawanId, DateTime mulai, DateTime selesai) async {
    final start = DateTime(mulai.year, mulai.month, mulai.day, 0, 0, 0);
    final end = DateTime(selesai.year, selesai.month, selesai.day, 23, 59, 59, 999);

    final list = await (select(kasbonHarian)
          ..where((t) => t.karyawanId.equals(karyawanId))
          ..where((t) => t.tanggal.isBiggerOrEqualValue(start))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(end)))
        .get();

    return list.fold<int>(0, (sum, item) => sum + item.nominal);
  }

  /// Stream Kasbon Hari Ini untuk Live Dashboard
  Stream<List<KasbonHarianData>> watchKasbonHariIni(DateTime tgl) {
    final start = DateTime(tgl.year, tgl.month, tgl.day, 0, 0, 0);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59, 999);
    return (select(kasbonHarian)
          ..where((t) => t.tanggal.isBiggerOrEqualValue(start))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(end)))
        .watch();
  }

  Future<void> prosesHitungGajiMingguan() async {
    await transaction(() async {
      final allKar = await select(karyawan).get();
      final allAbsen = await select(absensi).get();
      final allKat = await select(kategoriKaryawan).get();

      for (var kar in allKar) {
        KategoriKaryawanData? kat;
        try {
          kat = allKat.firstWhere((k) => k.id == kar.kategoriId);
        } catch (_) {
          kat = null;
        }
        if (kat == null) continue;

        final tarif = kat.tarifPerHari;
        final absenKar = allAbsen.where((a) => a.karyawanId == kar.id).toList()
          ..sort((a, b) => a.jamMasuk.compareTo(b.jamMasuk));
        if (absenKar.isEmpty) continue;

        Map<DateTime, List<AbsensiData>> perMinggu = {};
        for (var a in absenKar) {
          final tgl = a.jamMasuk;
          final senin = DateTime(tgl.year, tgl.month, tgl.day).subtract(Duration(days: tgl.weekday - 1));
          final key = DateTime(senin.year, senin.month, senin.day, 0, 0, 0);
          perMinggu.putIfAbsent(key, () => []).add(a);
        }

        for (var entry in perMinggu.entries) {
          final mingguMulai = entry.key;
          final mingguSelesai = DateTime(mingguMulai.year, mingguMulai.month, mingguMulai.day + 6, 23, 59, 59, 999);
          final list = entry.value;

          double efektif = 0;
          for (var a in list) {
            efektif += (a.tipeKerja == 'FULL' ? 1.0 : 0.5);
          }

          final bintangMinggu = await (select(bintangHarian)
                ..where((t) => t.karyawanId.equals(kar.id))
                ..where((t) => t.tanggal.isBiggerOrEqualValue(mingguMulai))
                ..where((t) => t.tanggal.isSmallerOrEqualValue(mingguSelesai)))
              .get();

          double rataBintang = 0;
          if (bintangMinggu.isNotEmpty) {
            rataBintang = bintangMinggu.map((e) => e.bintang).reduce((a, b) => a + b) / bintangMinggu.length;
          }

          int bonusOtomatis = 0;
          if (rataBintang >= 4.5) {
            bonusOtomatis = (tarif * efektif * 0.15).toInt();
          } else if (rataBintang >= 4.0) {
            bonusOtomatis = (tarif * efektif * 0.10).toInt();
          } else if (rataBintang >= 3.5) {
            bonusOtomatis = (tarif * efektif * 0.05).toInt();
          }

          final gajiPokok = (tarif * efektif).toInt();
          final existing = await (select(gajiMingguan)
                ..where((t) => t.karyawanId.equals(kar.id))
                ..where((t) => t.mingguMulai.equals(mingguMulai)))
              .getSingleOrNull();

          if (existing == null) {
            await into(gajiMingguan).insert(GajiMingguanCompanion.insert(
              karyawanId: kar.id,
              mingguMulai: mingguMulai,
              mingguSelesai: mingguSelesai,
              totalHariEfektif: Value(efektif),
              totalHariMasuk: Value(list.length),
              totalJam: Value(efektif * 8),
              totalGajiPokok: Value(gajiPokok),
              bonusMingguan: Value(bonusOtomatis),
              totalGaji: gajiPokok + bonusOtomatis,
              totalBonus: Value(bonusOtomatis),
            ));
          } else {
            final bonusDipakai = existing.bonusMingguan > 0 ? existing.bonusMingguan : bonusOtomatis;
            final totalGajiBaru = gajiPokok + bonusDipakai;

            await (update(gajiMingguan)..where((t) => t.id.equals(existing.id))).write(
              GajiMingguanCompanion(
                mingguSelesai: Value(mingguSelesai),
                totalHariEfektif: Value(efektif),
                totalHariMasuk: Value(list.length),
                totalJam: Value(efektif * 8),
                totalGajiPokok: Value(gajiPokok),
                bonusMingguan: Value(bonusDipakai),
                totalGaji: Value(totalGajiBaru),
                totalBonus: Value(bonusDipakai),
              ),
            );
          }
        }
      }
    });
  }

  Future<int> getTotalGajianSemua() async {
    final all = await select(gajiMingguan).get();
    return all.fold<int>(0, (p, e) => p + e.totalGaji);
  }

  Future<void> inputBonusMingguan(int gajiId, int bonus) async {
    final g = await (select(gajiMingguan)..where((t) => t.id.equals(gajiId))).getSingleOrNull();
    if (g == null) return;
    await (update(gajiMingguan)..where((t) => t.id.equals(gajiId))).write(GajiMingguanCompanion(
      bonusMingguan: Value(bonus),
      totalBonus: Value(bonus),
      totalGaji: Value(g.totalGajiPokok + bonus),
    ));
  }

  Future<void> tandaiBayar(int gajiId, String status) async {
    await (update(gajiMingguan)..where((t) => t.id.equals(gajiId))).write(GajiMingguanCompanion(
      statusBayar: Value(status),
      tanggalBayar: Value(status != 'BELUM' ? DateTime.now() : null),
    ));
  }

  Future<double> getRataBintangMingguan(int karyawanId, DateTime mulai, DateTime selesai) async {
    final start = DateTime(mulai.year, mulai.month, mulai.day, 0, 0, 0);
    final end = DateTime(selesai.year, selesai.month, selesai.day, 23, 59, 59, 999);

    final list = await (select(bintangHarian)
          ..where((t) => t.karyawanId.equals(karyawanId))
          ..where((t) => t.tanggal.isBiggerOrEqualValue(start))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(end)))
        .get();

    if (list.isEmpty) return 0.0;
    return list.map((e) => e.bintang).reduce((a, b) => a + b) / list.length;
  }
}
