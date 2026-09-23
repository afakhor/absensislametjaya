import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension AbsenDao on AppDatabase {
  Future<void> absenFingerprint(int karyawanId, {String tipe = 'FULL', String alasan = ''}) async {
    await into(absensi).insert(AbsensiCompanion.insert(
      karyawanId: karyawanId,
      jamMasuk: DateTime.now(),
      totalJamKerja: Value(tipe == 'FULL'? 8.0 : 4.0),
      metode: 'FINGERPRINT',
      keterangan: Value(alasan.isEmpty? 'Valid - Auto sync ID' : alasan),
      tipeKerja: Value(tipe),
    ));
  }

  Future<void> absenManualOwner(int karyawanId, String alasan, {String tipe = 'FULL'}) async {
    await into(absensi).insert(AbsensiCompanion.insert(
      karyawanId: karyawanId,
      jamMasuk: DateTime.now(),
      totalJamKerja: Value(tipe == 'FULL'? 8.0 : 4.0),
      metode: 'MANUAL_OWNER',
      keterangan: Value(alasan),
      tipeKerja: Value(tipe),
    ));
  }

  // watchKaryawan() DIHAPUS DARI SINI, PINDAH KE setowner_db.dart BIAR GAK DOUBLE
  Stream<List<AbsensiData>> watchAbsensiHari(DateTime tgl) {
    final start = DateTime(tgl.year, tgl.month, tgl.day);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59);
    // FIX: PAKAI MAP BIAR BUILD RELEASE LOLOS, JANGAN PAKAI isBetweenValues
    return select(absensi).watch().map((list) => list.where((a) => a.jamMasuk.isAfter(start.subtract(const Duration(seconds:1))) && a.jamMasuk.isBefore(end.add(const Duration(seconds:1)))).toList());
  }

  Stream<List<AbsensiData>> watchAbsensiKaryawan(int karyawanId) {
    return (select(absensi)..where((t) => t.karyawanId.equals(karyawanId))).watch();
  }
}