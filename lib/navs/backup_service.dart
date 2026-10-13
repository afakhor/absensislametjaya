import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../dbases/localdatabase.dart';

class BackupService {
  static final db = AppDatabase();

  static Future<String?> exportBackup() async {
    try {
      if (Platform.isAndroid) {
        // Android 11+ butuh manageExternalStorage
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
        if (await Permission.storage.isDenied) {
          await Permission.storage.request();
        }
      }

      // Ambil semua data drift - sesuaikan nama tabel kamu
      final karyawan = await db.select(db.karyawan).get();
      final kategori = await db.select(db.kategoriKaryawan).get();
      final absensi = await db.select(db.absensi).get();
      final gaji = await db.select(db.gajiMingguan).get();

      Map<String, dynamic> backup = {
        'tanggal': DateTime.now().toIso8601String(),
        'karyawan': karyawan.map((e) => e.toJson()).toList(),
        'kategoriKaryawan': kategori.map((e) => e.toJson()).toList(),
        'absensi': absensi.map((e) => e.toJson()).toList(),
        'gajiMingguan': gaji.map((e) => e.toJson()).toList(),
      };

      // Coba kasbon jika ada
      try {
        final kasbon = await db.select(db.kasbonHarian).get();
        backup['kasbonHarian'] = kasbon.map((e) => e.toJson()).toList();
      } catch (_) {}

      final jsonStr = jsonEncode(backup);

      // === SIMPAN KE /storage/emulated/0/Download ===
      Directory targetDir = Directory('/storage/emulated/0/Download');
      if (!await targetDir.exists()) {
        // fallback kalau folder Download tidak ada
        targetDir = await getExternalStorageDirectory()?? await getApplicationDocumentsDirectory();
      }

      final fileName = 'TB_SLAMET_JAYA_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.bskro';
      final file = File('${targetDir.path}/$fileName');
      await file.writeAsString(jsonStr, flush: true);

      return file.path;
    } catch (e) {
      print('Export Error: $e');
      return null;
    }
  }

  static Future<bool> importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bskro'],
        allowMultiple: false,
      );
      if (result == null) return false;

      final file = File(result.files.single.path!);
      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // TODO: restore sesuai DB kamu - contoh sederhana
      // await db.delete(db.karyawan).go();
      // for (var item in data['karyawan']) {... }

      return true;
    } catch (e) {
      print('Import Error: $e');
      return false;
    }
  }
}