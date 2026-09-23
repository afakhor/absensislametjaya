import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension SetOwnerDao on AppDatabase {
  Stream<List<KategoriKaryawanData>> watchKategori() => select(kategoriKaryawan).watch();
  Stream<List<KaryawanData>> watchKaryawan() => select(karyawan).watch();

  Future<int> tambahKategori(String nama, int tarif) =>
      into(kategoriKaryawan).insert(KategoriKaryawanCompanion.insert(namaKategori: nama, tarifPerHari: tarif));
  Future<void> updateTarifKategori(int id, int tarif) =>
      (update(kategoriKaryawan)..where((t) => t.id.equals(id))).write(KategoriKaryawanCompanion(tarifPerHari: Value(tarif)));
  Future<int> tambahKaryawan(String nama, int kategoriId, String? fotoPath) =>
      into(karyawan).insert(KaryawanCompanion.insert(nama: nama, kategoriId: kategoriId, fotoPath: Value(fotoPath)));
  Future<void> hapusKaryawan(int id) => (delete(karyawan)..where((t) => t.id.equals(id))).go();
}