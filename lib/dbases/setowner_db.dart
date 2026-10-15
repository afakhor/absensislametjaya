import 'package:drift/drift.dart';
import 'localdatabase.dart';

// FIX: File ini sebelumnya duplikat dengan method di localdatabase.dart
// Sekarang dikosongkan biar tidak error duplicate definition
// Semua method watchKategori, tambahKategori, watchKaryawan, tambahKaryawan, hapusKaryawan 
// sudah ada di AppDatabase utama (localdatabase.dart)
// Jadi extension ini hanya untuk tambahan khusus owner jika perlu

extension SetOwnerDbExtension on AppDatabase {
  // Tambahan khusus owner - tidak duplikat
  // hapusKategori yang lama gak ada di localdatabase, jadi aman taro sini
  Future<int> hapusKategoriOwner(int id) {
    return (delete(kategoriKaryawan)..where((tbl) => tbl.id.equals(id))).go();
  }

  // Jika mau pindah kategori, pakai yang di localdatabase.dart:
  // pindahKategoriKaryawan(karyawanId, kategoriBaruId)
  // bersihkanIdNol()
}