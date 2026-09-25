import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension SetOwnerExtension on AppDatabase {
  // ================= KATEGORI / JABATAN =================

  /// Mengambil aliran data (Stream) seluruh Kategori Karyawan secara real-time
  Stream<List<KategoriKaryawanData>> watchKategori() {
    return select(kategoriKaryawan).watch();
  }

  /// Menambahkan Kategori / Jabatan Baru
  Future<int> tambahKategori(String nama, int tarif) {
    return into(kategoriKaryawan).insert(
      KategoriKaryawanCompanion.insert(
        namaKategori: nama,
        tarifPerHari: tarif,
      ),
    );
  }

  /// Memperbarui Data Kategori / Jabatan
  Future<bool> updateKategori(int id, String nama, int tarif) {
    return update(kategoriKaryawan).replace(
      KategoriKaryawanData(
        id: id,
        namaKategori: nama,
        tarifPerHari: tarif,
      ),
    );
  }

  /// Menghapus Kategori Berdasarkan ID
  Future<int> hapusKategori(int id) {
    return (delete(kategoriKaryawan)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ================= KARYAWAN =================

  /// Mengambil aliran data (Stream) seluruh Karyawan secara real-time
  Stream<List<KaryawanData>> watchKaryawan() {
    return select(karyawan).watch();
  }

  /// Menambahkan Karyawan Baru
  Future<int> tambahKaryawan(String nama, int kategoriId, String? fotoPath) {
    return into(karyawan).insert(
      KaryawanCompanion.insert(
        nama: nama,
        kategoriId: kategoriId,
        fotoPath: Value(fotoPath),
      ),
    );
  }

  /// Memperbarui Data Karyawan
  Future<bool> updateKaryawan(int id, String nama, int kategoriId, String? fotoPath) {
    return update(karyawan).replace(
      KaryawanData(
        id: id,
        nama: nama,
        kategoriId: kategoriId,
        fotoPath: fotoPath,
      ),
    );
  }

  /// Menghapus Karyawan Berdasarkan ID
  Future<int> hapusKaryawan(int id) {
    return (delete(karyawan)..where((tbl) => tbl.id.equals(id))).go();
  }
}
