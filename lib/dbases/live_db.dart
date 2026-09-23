import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension LiveDao on AppDatabase {
  // BINTANG
  Future<void> setBintang(int karyawanId, DateTime tgl, int bintang) async {
    final day = DateTime(tgl.year, tgl.month, tgl.day);
    final ex = await (select(bintangHarian)..where((t)=>t.karyawanId.equals(karyawanId))..where((t)=>t.tanggal.equals(day))).getSingleOrNull();
    if(ex==null){
      await into(bintangHarian).insert(BintangHarianCompanion.insert(karyawanId: karyawanId, tanggal: day, bintang: Value(bintang)));
    } else {
      await (update(bintangHarian)..where((t)=>t.id.equals(ex.id))).write(BintangHarianCompanion(bintang: Value(bintang)));
    }
  }
  Stream<List<BintangHarianData>> watchBintangHari(DateTime tgl){
    final day = DateTime(tgl.year, tgl.month, tgl.day);
    return (select(bintangHarian)..where((t)=>t.tanggal.equals(day))).watch();
  }
  Future<Map<int,int>> getAkumulasiBintang() async {
    final all = await select(bintangHarian).get();
    Map<int,int> map = {};
    for(var b in all){ map[b.karyawanId] = (map[b.karyawanId]??0) + b.bintang; }
    return map;
  }

  // LAPORAN HARIAN
  Future<void> simpanLaporanHarian(DateTime tgl, int penjualan, int bebanOps, int tambahan, String ket, int gajiHari, int kotor, int bersih) async {
    final day = DateTime(tgl.year, tgl.month, tgl.day);
    final ex = await (select(laporanHarian)..where((t)=>t.tanggal.equals(day))).getSingleOrNull();
    final comp = LaporanHarianCompanion(
      tanggal: Value(day), totalPenjualan: Value(penjualan), bebanOperasional: Value(bebanOps),
      tambahanLain: Value(tambahan), keteranganTambahan: Value(ket),
      totalGajiHariIni: Value(gajiHari), labaKotor: Value(kotor), labaBersih: Value(bersih),
    );
    if(ex==null) await into(laporanHarian).insert(comp);
    else await (update(laporanHarian)..where((t)=>t.id.equals(ex.id))).write(comp);
  }
  Stream<LaporanHarianData?> watchLaporanHari(DateTime tgl){
    final day = DateTime(tgl.year, tgl.month, tgl.day);
    return (select(laporanHarian)..where((t)=>t.tanggal.equals(day))).watchSingleOrNull();
  }

  // UPDATE TIPE KERJA FULL <-> SETENGAH
  Future<void> updateTipeAbsen(int absenId, String tipeBaru) async {
    final jam = tipeBaru=='FULL'? 8.0 : 4.0;
    await (update(absensi)..where((t)=>t.id.equals(absenId))).write(AbsensiCompanion(tipeKerja: Value(tipeBaru), totalJamKerja: Value(jam)));
  }

  // HITUNG GAJI HARIAN BUAT LABA
  Future<int> hitungGajiHariIni(DateTime tgl) async {
    final start = DateTime(tgl.year, tgl.month, tgl.day);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23,59,59);
    final absen = await select(absensi).get();
    final hariIni = absen.where((a)=> a.jamMasuk.isAfter(start.subtract(const Duration(seconds:1))) && a.jamMasuk.isBefore(end.add(const Duration(seconds:1)))).toList();
    int total = 0;
    for(var a in hariIni){
      final kar = await (select(karyawan)..where((t)=>t.id.equals(a.karyawanId))).getSingleOrNull();
      if(kar==null) continue;
      final kat = await (select(kategoriKaryawan)..where((t)=>t.id.equals(kar.kategoriId))).getSingleOrNull();
      if(kat==null) continue;
      total += a.tipeKerja=='FULL'? kat.tarifPerHari : kat.tarifPerHari~/2;
    }
    return total;
  }
}