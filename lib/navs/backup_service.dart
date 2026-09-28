import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupService {
  // Helper untuk mendapatkan path DB sqlite Drift yang presisi
  static Future<File?> _getDatabaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    
    // Cek path dengan ekstensi .sqlite (standar drift_flutter)
    final pathWithExt = p.join(dbFolder.path, 'tb_slamet_jaya_v8_clean.sqlite');
    final fileWithExt = File(pathWithExt);
    if (await fileWithExt.exists()) return fileWithExt;

    // Fallback cek path tanpa ekstensi
    final pathNoExt = p.join(dbFolder.path, 'tb_slamet_jaya_v8_clean');
    final fileNoExt = File(pathNoExt);
    if (await fileNoExt.exists()) return fileNoExt;

    return null;
  }

  // 1. EXPORT / BACKUP DATA TO .bskro
  static Future<String?> exportBackup() async {
    try {
      final dbFile = await _getDatabaseFile();
      if (dbFile == null) {
        throw Exception("File database tidak ditemukan di direktori lokal.");
      }

      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final backupFileName = 'backup_slamet_jaya_$dateStr.bskro';

      // Menggunakan folder Downloads atau External Storage Publik
      Directory? targetDir = await getDownloadsDirectory();
      targetDir ??= await getExternalStorageDirectory();

      if (targetDir == null) {
        throw Exception("Direktori penyimpanan tidak tersedia.");
      }

      final backupPath = p.join(targetDir.path, backupFileName);
      await dbFile.copy(backupPath);
      
      return backupPath;
    } catch (e) {
      print("Gagal backup: $e");
      return null;
    }
  }

  // 2. IMPORT / RESTORE DATA FROM .bskro
  static Future<bool> importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Mencegah filter ekstensi diblokir oleh OS Android tertentu
      );

      if (result != null && result.files.single.path != null) {
        final selectedFilePath = result.files.single.path!;
        
        // Validasi ekstensi secara manual
        if (!selectedFilePath.endsWith('.bskro') && !selectedFilePath.endsWith('.sqlite')) {
          print("Format file salah. Harus ber-ekstensi .bskro");
          return false;
        }

        final selectedFile = File(selectedFilePath);
        final dbFolder = await getApplicationDocumentsDirectory();
        
        // Target lokasi overwrite DB Drift
        final targetPath = p.join(dbFolder.path, 'tb_slamet_jaya_v8_clean.sqlite');
        
        await selectedFile.copy(targetPath);
        return true;
      }
      return false;
    } catch (e) {
      print("Gagal restore: $e");
      return false;
    }
  }
}
