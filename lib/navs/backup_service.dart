import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../dbases/localdatabase.dart';

class BackupService {
  static final db = AppDatabase();

  static Future<String?> exportBackup() async {
    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
        await Permission.manageExternalStorage.request();
      }
      final karyawan = await db.select(db.karyawan).get();
      final kategori = await db.select(db.kategoriKaryawan).get();
      final absensi = await db.select(db.absensi).get();
      final gaji = await db.select(db.gajiMingguan).get();
      final bintang = await db.select(db.bintangHarian).get();
      final kasbon = await db.select(db.kasbonHarian).get();
      final laporan = await db.select(db.laporanHarian).get();

      final Map<String, dynamic> data = {
        'versi': 1,
        'tanggal': DateTime.now().toIso8601String(),
        'kategoriKaryawan': kategori.map((e) => e.toJson()).toList(),
        'karyawan': karyawan.map((e) => e.toJson()).toList(),
        'absensi': absensi.map((e) => e.toJson()).toList(),
        'bintangHarian': bintang.map((e) => e.toJson()).toList(),
        'kasbonHarian': kasbon.map((e) => e.toJson()).toList(),
        'gajiMingguan': gaji.map((e) => e.toJson()).toList(),
        'laporanHarian': laporan.map((e) => e.toJson()).toList(),
      };

      Directory dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) dir = Directory('/storage/emulated/0/Download');
      
      final file = File('${dir.path}/TB_SLAMET_JAYA_${DateTime.now().millisecondsSinceEpoch}.bskro');
      await file.writeAsString(jsonEncode(data), flush: true);
      return file.path;
    } catch (e) {
      print('Backup error $e');
      return null;
    }
  }

  // FIX RESTORE YANG GAGAL
  static Future<bool> importBackup() async {
    try {
      // 1. Picker harus allow .bskro
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // jangan custom, biar kebaca di Download
        allowMultiple: false,
      );
      if (result == null) return false;

      File file;
      if (result.files.single.path != null) {
        file = File(result.files.single.path!);
      } else {
        // Android 13+ bytes only
        final bytes = result.files.single.bytes;
        if (bytes == null) return false;
        final temp = File('/storage/emulated/0/Download/temp_restore.bskro');
        await temp.writeAsBytes(bytes);
        file = temp;
      }

      if (!await file.exists()) return false;
      final jsonStr = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(jsonStr);

      // 2. RESTORE - HAPUS DULU BARU INSERT (transaction biar adil)
      await db.transaction(() async {
        // hapus semua child dulu
        await db.delete(db.gajiMingguan).go();
        await db.delete(db.laporanHarian).go();
        await db.delete(db.kasbonHarian).go();
        await db.delete(db.bintangHarian).go();
        await db.delete(db.absensi).go();
        await db.delete(db.karyawan).go();
        await db.delete(db.kategoriKaryawan).go();

        // insert kategori dulu (parent)
        for (var m in (json['kategoriKaryawan'] ?? [])) {
          await db.into(db.kategoriKaryawan).insert(
            KategoriKaryawanCompanion(
              id: Value(m['id']),
              namaKategori: Value(m['namaKategori']),
              tarifPerHari: Value(m['tarifPerHari']),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (var m in (json['karyawan'] ?? [])) {
          await db.into(db.karyawan).insert(
            KaryawanCompanion(
              id: Value(m['id']),
              nama: Value(m['nama']),
              kategoriId: Value(m['kategoriId']),
              fotoPath: Value(m['fotoPath']),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        // ... lanjutkan untuk absensi, bintangHarian, kasbon, gajiMingguan, laporan
        // pakai insertOrReplace biar id sama
      });

      return true;
    } catch (e) {
      print('Restore error: $e');
      return false;
    }
  }
}