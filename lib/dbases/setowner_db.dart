import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension SetOwnerDao on AppDatabase {
  // Kategori
  Future<int> tambahKategori(String nama, int tarif) => into(kategoriKaryawan).insert(KategoriKaryawanCompanion.insert(namaKategori: nama, tarifPerJam: tarif));
  Future<void> updateTarifKategori(int id, int tarif) => (update(kategoriKaryawan)..where((t) => t.id.equals(id))).write(KategoriKaryawanCompanion(tarifPerJam: Value(tarif)));
  Stream<List<KategoriKaryawanData>> watchKategori() => select(kategoriKaryawan).watch();

  // Karyawan + Foto
  Future<int> tambahKaryawan(String nama, int kategoriId, String? fotoPath) => into(karyawan).insert(KaryawanCompanion.insert(nama: nama, kategoriId: kategoriId, fotoPath: Value(fotoPath)));
  Stream<List<KaryawanData>> watchKaryawan() => select(karyawan).watch();
  Future<void> hapusKaryawan(int id) => (delete(karyawan)..where((t) => t.id.equals(id))).go();
}