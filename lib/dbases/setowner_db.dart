import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension SetOwnerDbExtension on AppDatabase {
  // ===========================================================================
  // KATEGORI / JABATAN KARYAWAN
  // ===========================================================================

  /// Stream daftar kategori untuk auto-update UI / Autocomplete
  Stream<List<KategoriKaryawanData>> watchKategori() {
    return select(kategoriKaryawan).watch();
  }

  /// Menambahkan kategori / jabatan baru
  Future<int> tambahKategori(String nama, int tarif) {
    return into(kategoriKaryawan).insert(
      KategoriKaryawanCompanion.insert(
        namaKategori: nama,
        tarifPerHari: tarif,
      ),
    );
  }

  /// Menghapus kategori berdasarkan ID
  Future<int> hapusKategori(int id) {
    return (delete(kategoriKaryawan)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ===========================================================================
  // KARYAWAN
  // ===========================================================================

  /// Stream daftar karyawan untuk ListView pada OwnerPage
  Stream<List<KaryawanData>> watchKaryawan() {
    return select(karyawan).watch();
  }

  /// Menambahkan karyawan baru
  Future<int> tambahKaryawan(String nama, int kategoriId, String? fotoPath) {
    return into(karyawan).insert(
      KaryawanCompanion.insert(
        nama: nama,
        kategoriId: kategoriId,
        fotoPath: Value(fotoPath),
      ),
    );
  }

  /// Menghapus karyawan berdasarkan ID
  Future<int> hapusKaryawan(int id) {
    return (delete(karyawan)..where((tbl) => tbl.id.equals(id))).go();
  }
}
