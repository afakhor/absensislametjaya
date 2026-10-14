import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../dbases/localdatabase.dart';

class BackupService {
  static final db = AppDatabase();

  static Future<String?> exportBackup() async {
    try {
      final karyawan = await db.select(db.karyawan).get();
      final kategori = await db.select(db.kategoriKaryawan).get();
      final absensi = await db.select(db.absensi).get();
      final gaji = await db.select(db.gajiMingguan).get();
      final bintang = await db.select(db.bintangHarian).get();
      final kasbon = await db.select(db.kasbonHarian).get();
      final laporan = await db.select(db.laporanHarian).get();

      final data = {
        'versi': 2,
        'tanggal': DateTime.now().toIso8601String(),
        'kategoriKaryawan': kategori,
        'karyawan': karyawan,
        'absensi': absensi,
        'bintangHarian': bintang,
        'kasbonHarian': kasbon,
        'gajiMingguan': gaji,
        'laporanHarian': laporan,
      };

      // Tulis ke Documents dulu (pasti bisa), baru copy ke Download
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = 'TB_SLAMET_JAYA_${DateTime.now().millisecondsSinceEpoch}.bskro';
      
      final fileDoc = File('${docDir.path}/$fileName');
      await fileDoc.writeAsString(jsonEncode(data));

      // Coba copy ke Download biar keliatan di File Manager
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final fileDown = File('${downloadDir.path}/$fileName');
          await fileDown.writeAsString(jsonEncode(data), flush: true);
          print('BACKUP OK di Download: ${fileDown.path}');
          return fileDown.path;
        }
      } catch (_) {}

      print('BACKUP OK di Documents: ${fileDoc.path}');
      return fileDoc.path;
    } catch (e, s) {
      print('Backup error $e $s');
      return null;
    }
  }

  // RETURN STRING BIAR TAU ERRORNYA, BUKAN BOOL
  static Future<String> importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bskro'],
        withData: true, // WAJIB true di Android 13+
      );
      if (result == null) return 'BATAL';

      String jsonStr;
      if (result.files.single.bytes != null) {
        jsonStr = utf8.decode(result.files.single.bytes!);
      } else {
        final path = result.files.single.path!;
        jsonStr = await File(path).readAsString();
      }

      final Map<String, dynamic> json = jsonDecode(jsonStr);

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
            KategoriKaryawanCompanion.insert(
              namaKategori: m['namaKategori'] ?? m['nama'] ?? '',
              tarifPerHari: (m['tarifPerHari'] ?? 0) as int,
              id: Value(m['id'] as int? ?? 0),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (var m in (json['karyawan'] ?? [])) {
          await db.into(db.karyawan).insert(
            KaryawanCompanion.insert(
              nama: m['nama'] ?? '',
              kategoriId: (m['kategoriId'] ?? 1) as int,
              fotoPath: Value(m['fotoPath']),
              id: Value(m['id'] as int? ?? 0),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      return 'SUKSES';
    } catch (e, s) {
      print('RESTORE FAIL $e $s');
      return 'GAGAL: $e';
    }
  }
}