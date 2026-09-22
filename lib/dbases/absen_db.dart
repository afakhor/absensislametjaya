import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension AbsenDao on AppDatabase {
  // FIX: yang benar cuma 1 argumen ID, biar auto sync ID, Nama, Kategori
  Future<void> absenFingerprint(int karyawanId) async {
    await into(absensi).insert(AbsensiCompanion.insert(
      karyawanId: karyawanId,
      jamMasuk: DateTime.now(),
      totalJamKerja: const Value(8.0),
      metode: 'FINGERPRINT',
      keterangan: const Value('Valid - Auto sync ID'),
    ));
  }

  Future<void> absenManualOwner(int karyawanId, String alasan) async {
    await into(absensi).insert(AbsensiCompanion.insert(
      karyawanId: karyawanId,
      jamMasuk: DateTime.now(),
      totalJamKerja: const Value(8.0),
      metode: 'MANUAL_OWNER',
      keterangan: Value(alasan),
    ));
  }

  Stream<List<AbsensiData>> watchAbsensiKaryawan(int karyawanId) {
    return (select(absensi)..where((t) => t.karyawanId.equals(karyawanId))).watch();
  }
}