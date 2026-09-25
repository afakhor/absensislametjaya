import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension AbsenDao on AppDatabase {
  /// Cek apakah karyawan sudah absen pada tanggal tertentu
  Future<bool> sudahAbsenHariIni(int karyawanId, DateTime tgl) async {
    final start = DateTime(tgl.year, tgl.month, tgl.day, 0, 0, 0);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59, 999);

    final cek = await (select(absensi)
          ..where((t) => t.karyawanId.equals(karyawanId))
          ..where((t) => t.jamMasuk.isBiggerOrEqualValue(start))
          ..where((t) => t.jamMasuk.isSmallerOrEqualValue(end)))
        .getSingleOrNull();

    return cek != null;
  }

  /// Watch/Stream absensi harian seluruh karyawan pada tanggal tertentu
  Stream<List<AbsensiData>> watchAbsensiHari(DateTime tgl) {
    final start = DateTime(tgl.year, tgl.month, tgl.day, 0, 0, 0);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59, 999);

    return (select(absensi)
          ..where((t) => t.jamMasuk.isBiggerOrEqualValue(start))
          ..where((t) => t.jamMasuk.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.jamMasuk)]))
        .watch();
  }

  /// Watch/Stream seluruh riwayat absensi milik 1 karyawan tertentu
  Stream<List<AbsensiData>> watchAbsensiKaryawan(int karyawanId) {
    return (select(absensi)
          ..where((t) => t.karyawanId.equals(karyawanId))
          ..orderBy([(t) => OrderingTerm.desc(t.jamMasuk)]))
        .watch();
  }

  /// Eksekusi simpan absensi baru (Fingerprint / Manual)
  Future<void> absenFingerprint(
    int karyawanId, {
    String tipe = 'FULL',
    String alasan = '',
    String metode = 'FINGERPRINT',
  }) async {
    final sekarang = DateTime.now();

    if (await sudahAbsenHariIni(karyawanId, sekarang)) {
      throw Exception('SUDAH_ABSEN');
    }

    final jamKerja = (tipe == 'FULL') ? 8.0 : 4.0;

    await into(absensi).insert(
      AbsensiCompanion.insert(
        karyawanId: karyawanId,
        jamMasuk: sekarang,
        totalJamKerja: Value(jamKerja),
        metode: metode,
        keterangan: Value(alasan.isEmpty ? 'Valid' : alasan),
        tipeKerja: Value(tipe),
      ),
    );
  }

  /// Hapus data absensi jika ada kesalahan input
  Future<void> hapusAbsen(int id) async {
    await (delete(absensi)..where((t) => t.id.equals(id))).go();
  }
}
