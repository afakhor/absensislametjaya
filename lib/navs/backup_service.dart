import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../dbases/localdatabase.dart';

class BackupService {
  static final db = AppDatabase();

  static Future<Directory> _getDownloadDir() async {
    // Android 11+ wajib pakai ini, bukan hardcode /storage/emulated/0/Download
    if (Platform.isAndroid) {
      Directory? dir = await getDownloadsDirectory();
      if (dir != null && await dir.exists()) return dir;
      // fallback
      dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }
    return await getApplicationDocumentsDirectory();
  }

  static Future<String?> exportBackup() async {
    try {
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.status.isDenied) {
          await Permission.manageExternalStorage.request();
        }
        if (await Permission.storage.status.isDenied) {
          await Permission.storage.request();
        }
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

      final dir = await _getDownloadDir();
      final fileName = 'TB_SLAMET_JAYA_${DateTime.now().millisecondsSinceEpoch}.bskro';
      final file = File('${dir.path}/$fileName');
      
      await file.writeAsString(jsonEncode(data), flush: true);

      // Biar muncul di file manager
      if (await file.exists()) {
        print('BACKUP SUKSES: ${file.path} - size: ${await file.length()}');
        return file.path;
      } else {
        print('BACKUP GAGAL: file tidak tercipta');
        return null;
      }
    } catch (e) {
      print('Backup error $e');
      return null;
    }
  }

  static Future<bool> importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bskro'],
        withData: true,
      );
      if (result == null) return false;

      File file;
      // Ambil file
      if (result.files.single.path != null) {
        file = File(result.files.single.path!);
      } else {
        final bytes = result.files.single.bytes;
        if (bytes == null) throw Exception('Bytes null');
        final dir = await _getDownloadDir();
        final temp = File('${dir.path}/temp_restore.bskro');
        await temp.writeAsBytes(bytes, flush: true);
        file = temp;
      }

      if (!await file.exists()) {
        print('File tidak ada: ${file.path}');
        throw Exception('File tidak ada');
      }

      final jsonStr = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(jsonStr);

      // Validasi
      if (!json.containsKey('karyawan') && !json.containsKey('kategoriKaryawan')) {
        throw Exception('Format .bskro salah');
      }

      await db.transaction(() async {
        await db.delete(db.gajiMingguan).go();
        await db.delete(db.laporanHarian).go();
        await db.delete(db.kasbonHarian).go();
        await db.delete(db.bintangHarian).go();
        await db.delete(db.absensi).go();
        await db.delete(db.karyawan).go();
        await db.delete(db.kategoriKaryawan).go();

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
        // TODO: lanjutkan absensi, bintang, kasbon, gaji, laporan sama seperti di atas
      });

      print('RESTORE SUKSES dari ${file.path}');
      return true;
    } catch (e) {
      print('Restore error: $e');
      return false;
    }
  }
}