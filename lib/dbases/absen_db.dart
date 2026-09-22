import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension AbsenDao on AppDatabase {
  // VERSI BARU - dengan 1 hari / ½ hari + bonus owner - PAKAI INI UNTUK REQUIRED HARIAN
  Future<void> absenFingerprint(int karyawanId, {double jam = 8.0, String tipe = 'FULL', int bonus = 0}) async {
    await into(absensi).insert(AbsensiCompanion.insert(
      karyawanId: karyawanId,
      jamMasuk: DateTime.now(),
      totalJamKerja: Value(jam),
      metode: 'FINGERPRINT',
      keterangan: const Value('Valid - Auto sync ID'),
      tipeKerja: Value(tipe),
      bonus: Value(bonus),
    ));
  }

  // VERSI LAMA TETAP ADA - biar kode lama gak error, ini wrapper ke versi baru
  Future<void> absenFingerprintLama(int karyawanId) async {
    await absenFingerprint(karyawanId, jam: 8.0, tipe: 'FULL', bonus: 0);
  }

  // MANUAL OWNER - VERSI LAMA TETAP ADA + VERSI BARU DENGAN TIPE & BONUS
  Future<void> absenManualOwner(int karyawanId, String alasan, {double jam = 8.0, String tipe = 'FULL', int bonus = 0}) async {
    await into(absensi).insert(AbsensiCompanion.insert(
      karyawanId: karyawanId,
      jamMasuk: DateTime.now(),
      totalJamKerja: Value(jam),
      metode: 'MANUAL_OWNER',
      keterangan: Value(alasan),
      tipeKerja: Value(tipe),
      bonus: Value(bonus),
    ));
  }

  // WATCH KARYAWAN - DARI FILE 1
  Stream<List<KaryawanData>> watchKaryawan() => select(karyawan).watch();

  // REQUIRED HARIAN - WATCH ABSEN PER TANGGAL - DARI FILE 1 - UNTUK FITUR GAK ABSEN = GAK MASUK
  Stream<List<AbsensiData>> watchAbsensiHari(DateTime tgl) {
    final start = DateTime(tgl.year, tgl.month, tgl.day);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59);
    return (select(absensi)..where((a) => a.jamMasuk.isBetweenValues(start, end))).watch();
  }

  // WATCH ABSENSI PER KARYAWAN - DARI FILE 2 - TETAP ADA
  Stream<List<AbsensiData>> watchAbsensiKaryawan(int karyawanId) {
    return (select(absensi)..where((t) => t.karyawanId.equals(karyawanId))).watch();
  }
}