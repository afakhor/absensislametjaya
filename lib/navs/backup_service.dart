import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupService {
  // 1. UPLOAD / EXPORT / BACKUP DATA TO .bskro
  static Future<String?> exportBackup() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dbFolder.path, 'tb_slamet_jaya_v8_clean'); // Nama file DB Drift Anda
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception("File database tidak ditemukan.");
      }

      // Buat nama file backup dengan timestamp dan ekstensi .bskro
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final backupFileName = 'backup_slamet_jaya_$dateStr.bskro';

      // Simpan ke folder dokumen/penyimpanan eksternal
      final targetDir = await getExternalStorageDirectory();
      final backupPath = p.join(targetDir!.path, backupFileName);

      await dbFile.copy(backupPath);
      return backupPath; // Mengembalikan lokasi file .bskro yang berhasil dibuat
    } catch (e) {
      print("Gagal backup: $e");
      return null;
    }
  }

  // 2. IMPORT / RESTORE DATA FROM .bskro
  static Future<bool> importBackup() async {
    try {
      // Buka file picker khusus ekstensi bskro
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bskro'],
      );

      if (result != null && result.files.single.path != null) {
        final selectedFilePath = result.files.single.path!;
        final selectedFile = File(selectedFilePath);

        final dbFolder = await getApplicationDocumentsDirectory();
        final dbPath = p.join(dbFolder.path, 'tb_slamet_jaya_v8_clean');

        // Timpa file database lama dengan file .bskro
        await selectedFile.copy(dbPath);
        
        return true; // Berhasil di-restore
      }
      return false;
    } catch (e) {
      print("Gagal restore: $e");
      return false;
    }
  }
}
