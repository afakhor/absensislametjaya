import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension AbsenDao on AppDatabase {
  Future<bool> sudahAbsenHariIni(int karyawanId, DateTime tgl) async {
    final start = DateTime(tgl.year, tgl.month, tgl.day);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59);
    final cek = await (select(absensi)
      ..where((t) => t.karyawanId.equals(karyawanId))
      ..where((t) => t.jamMasuk.isBiggerOrEqualValue(start))
      ..where((t) => t.jamMasuk.isSmallerOrEqualValue(end))
    ).getSingleOrNull();
    return cek != null;
  }

  Stream<List<AbsensiData>> watchAbsensiHari(DateTime tgl) {
    final start = DateTime(tgl.year, tgl.month, tgl.day);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59);
    return (select(absensi)
      ..where((t) => t.jamMasuk.isBiggerOrEqualValue(start))
      ..where((t) => t.jamMasuk.isSmallerOrEqualValue(end))
    ).watch();
  }

  Stream<List<AbsensiData>> watchAbsensiKaryawan(int karyawanId) {
    return (select(absensi)..where((t) => t.karyawanId.equals(karyawanId))).watch();
  }

  Future<void> absenFingerprint(int karyawanId, {String tipe = 'FULL', String alasan = ''}) async {
    if(await sudahAbsenHariIni(karyawanId, DateTime.now())) throw Exception('SUDAH_ABSEN');
    await into(absensi).insert(AbsensiCompanion.insert(
      karyawanId: karyawanId, jamMasuk: DateTime.now(),
      totalJamKerja: Value(tipe == 'FULL'? 8.0 : 4.0),
      metode: 'FINGERPRINT', keterangan: Value(alasan.isEmpty? 'Valid' : alasan), tipeKerja: Value(tipe),
    ));
  }
}