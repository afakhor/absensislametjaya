import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension GajiDao on AppDatabase {
  Future<void> prosesHitungGajiMingguan() async {
    final allKar = await select(karyawan).get();
    final allAbsen = await select(absensi).get();
    final allKat = await select(kategoriKaryawan).get();
    for(var kar in allKar){
      final kat = allKat.where((k)=>k.id==kar.kategoriId).firstOrNull;
      if(kat==null) continue;
      final tarif = kat.tarifPerHari;
      final absenKar = allAbsen.where((a)=>a.karyawanId==kar.id).toList()..sort((a,b)=>a.jamMasuk.compareTo(b.jamMasuk));
      if(absenKar.isEmpty) continue;
      Map<DateTime, List<AbsensiData>> perMinggu = {};
      for(var a in absenKar){
        final senin = a.jamMasuk.subtract(Duration(days: a.jamMasuk.weekday-1));
        final key = DateTime(senin.year, senin.month, senin.day);
        perMinggu.putIfAbsent(key, ()=>[]).add(a);
      }
      for(var entry in perMinggu.entries){
        final mingguMulai = entry.key;
        final mingguSelesai = mingguMulai.add(const Duration(days: 6, hours: 23, minutes: 59));
        final list = entry.value;
        double efektif = 0; for(var a in list){ efektif += a.tipeKerja=='FULL'?1.0:0.5; }
        final bintangMinggu = await (select(bintangHarian)..where((t)=>t.karyawanId.equals(kar.id))..where((t)=>t.tanggal.isBiggerOrEqualValue(mingguMulai))..where((t)=>t.tanggal.isSmallerOrEqualValue(mingguSelesai))).get();
        double rataBintang = 0; if(bintangMinggu.isNotEmpty) rataBintang = bintangMinggu.map((e)=>e.bintang).reduce((a,b)=>a+b) / bintangMinggu.length;
        int bonusOtomatis = 0;
        if(rataBintang >= 4.5) bonusOtomatis = (tarif * efektif * 0.15).toInt();
        else if(rataBintang >= 4.0) bonusOtomatis = (tarif * efektif * 0.10).toInt();
        else if(rataBintang >= 3.5) bonusOtomatis = (tarif * efektif * 0.05).toInt();
        final gajiPokok = (tarif * efektif).toInt();
        final existing = await (select(gajiMingguan)..where((t)=>t.karyawanId.equals(kar.id))..where((t)=>t.mingguMulai.equals(mingguMulai))).getSingleOrNull();
        if(existing==null){
          await into(gajiMingguan).insert(GajiMingguanCompanion.insert(
            karyawanId: kar.id, mingguMulai: mingguMulai, mingguSelesai: mingguSelesai,
            totalHariEfektif: Value(efektif), totalHariMasuk: Value(list.length), totalJam: Value(efektif*8),
            totalGajiPokok: Value(gajiPokok), bonusMingguan: Value(bonusOtomatis), totalGaji: gajiPokok+bonusOtomatis, totalBonus: Value(bonusOtomatis),
          ));
        } else {
          final bonusDipakai = existing.bonusMingguan==0? bonusOtomatis : existing.bonusMingguan;
          await (update(gajiMingguan)..where((t)=>t.id.equals(existing.id))).write(GajiMingguanCompanion(
            totalHariEfektif: Value(efektif), totalHariMasuk: Value(list.length), totalJam: Value(efektif*8),
            totalGajiPokok: Value(gajiPokok), bonusMingguan: Value(bonusDipakai), totalGaji: Value(gajiPokok + bonusDipakai), totalBonus: Value(bonusDipakai),
          ));
        }
      }
    }
  }

  Future<int> getTotalGajianSemua() async {
    final all = await select(gajiMingguan).get();
    return all.fold<int>(0, (p,e)=> p + e.totalGaji);
  }
  Future<void> inputBonusMingguan(int gajiId, int bonus) async {
    final g = await (select(gajiMingguan)..where((t)=>t.id.equals(gajiId))).getSingle();
    await (update(gajiMingguan)..where((t)=>t.id.equals(gajiId))).write(GajiMingguanCompanion(bonusMingguan: Value(bonus), totalBonus: Value(bonus), totalGaji: Value(g.totalGajiPokok + bonus)));
  }
  Future<void> tandaiBayar(int gajiId, String status) async {
    await (update(gajiMingguan)..where((t)=>t.id.equals(gajiId))).write(GajiMingguanCompanion(statusBayar: Value(status), tanggalBayar: Value(status!='BELUM'?DateTime.now():null)));
  }

  // BINTANG & LAPORAN - PINDAHAN DARI live_db
  Future<void> setBintang(int karyawanId, DateTime tgl, int bintang) async {
    final day = DateTime(tgl.year, tgl.month, tgl.day);
    final ex = await (select(bintangHarian)..where((t)=>t.karyawanId.equals(karyawanId))..where((t)=>t.tanggal.equals(day))).getSingleOrNull();
    if(ex==null) await into(bintangHarian).insert(BintangHarianCompanion.insert(karyawanId: karyawanId, tanggal: day, bintang: Value(bintang)));
    else await (update(bintangHarian)..where((t)=>t.id.equals(ex.id))).write(BintangHarianCompanion(bintang: Value(bintang)));
  }
  Stream<List<BintangHarianData>> watchBintangHari(DateTime tgl){
    final day = DateTime(tgl.year, tgl.month, tgl.day);
    return (select(bintangHarian)..where((t)=>t.tanggal.equals(day))).watch();
  }
  Future<Map<int,int>> getAkumulasiBintang() async {
    final all = await select(bintangHarian).get(); Map<int,int> map = {};
    for(var b in all){ map[b.karyawanId] = (map[b.karyawanId]??0) + b.bintang; } return map;
  }
  Future<double> getRataBintangMingguan(int karyawanId, DateTime mulai, DateTime selesai) async {
    final list = await (select(bintangHarian)..where((t)=>t.karyawanId.equals(karyawanId))..where((t)=>t.tanggal.isBiggerOrEqualValue(DateTime(mulai.year, mulai.month, mulai.day)))..where((t)=>t.tanggal.isSmallerOrEqualValue(DateTime(selesai.year, selesai.month, selesai.day)))).get();
    if(list.isEmpty) return 0; return list.map((e)=>e.bintang).reduce((a,b)=>a+b) / list.length;
  }
  Future<int> hitungGajiHariIni(DateTime tgl) async {
    final start = DateTime(tgl.year, tgl.month, tgl.day); final end = DateTime(tgl.year, tgl.month, tgl.day, 23,59,59);
    final absen = await select(absensi).get(); final hariIni = absen.where((a)=> a.jamMasuk.isAfter(start.subtract(const Duration(seconds:1))) && a.jamMasuk.isBefore(end.add(const Duration(seconds:1)))).toList();
    int total = 0; for(var a in hariIni){ final kar = await (select(karyawan)..where((t)=>t.id.equals(a.karyawanId))).getSingleOrNull(); if(kar==null) continue; final kat = await (select(kategoriKaryawan)..where((t)=>t.id.equals(kar.kategoriId))).getSingleOrNull(); if(kat==null) continue; total += a.tipeKerja=='FULL'? kat.tarifPerHari : kat.tarifPerHari~/2; } return total;
  }
  Future<void> simpanLaporanHarian(DateTime tgl, int penjualan, int bebanOps, int tambahan, String ket, int gajiHari, int kotor, int bersih) async {
    final day = DateTime(tgl.year, tgl.month, tgl.day); final ex = await (select(laporanHarian)..where((t)=>t.tanggal.equals(day))).getSingleOrNull();
    final comp = LaporanHarianCompanion(tanggal: Value(day), totalPenjualan: Value(penjualan), bebanOperasional: Value(bebanOps), tambahanLain: Value(tambahan), keteranganTambahan: Value(ket), totalGajiHariIni: Value(gajiHari), labaKotor: Value(kotor), labaBersih: Value(bersih));
    if(ex==null) await into(laporanHarian).insert(comp); else await (update(laporanHarian)..where((t)=>t.id.equals(ex.id))).write(comp);
  }
  Stream<LaporanHarianData?> watchLaporanHari(DateTime tgl){ final day = DateTime(tgl.year, tgl.month, tgl.day); return (select(laporanHarian)..where((t)=>t.tanggal.equals(day))).watchSingleOrNull(); }
  Future<void> updateTipeAbsen(int absenId, String tipeBaru) async { final jam = tipeBaru=='FULL'? 8.0 : 4.0; await (update(absensi)..where((t)=>t.id.equals(absenId))).write(AbsensiCompanion(tipeKerja: Value(tipeBaru), totalJamKerja: Value(jam))); }
}