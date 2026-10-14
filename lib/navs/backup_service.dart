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

      // pakai toJson() biar bisa di-encode
      final data = {
        'versi': 2,
        'tanggal': DateTime.now().toIso8601String(),
        'kategoriKaryawan': kategori.map((e) => e.toJson()).toList(),
        'karyawan': karyawan.map((e) => e.toJson()).toList(),
        'absensi': absensi.map((e) => e.toJson()).toList(),
        'bintangHarian': bintang.map((e) => e.toJson()).toList(),
        'kasbonHarian': kasbon.map((e) => e.toJson()).toList(),
        'gajiMingguan': gaji.map((e) => e.toJson()).toList(),
        'laporanHarian': laporan.map((e) => e.toJson()).toList(),
      };

      final docDir = await getApplicationDocumentsDirectory();
      final fileName = 'TB_SLAMET_JAYA_${DateTime.now().millisecondsSinceEpoch}.bskro';
      final fileDoc = File('${docDir.path}/$fileName');
      await fileDoc.writeAsString(jsonEncode(data));

      // copy ke Download biar keliatan
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final fileDown = File('${downloadDir.path}/$fileName');
          await fileDown.writeAsString(jsonEncode(data), flush: true);
          return fileDown.path;
        }
      } catch (_) {}

      return fileDoc.path;
    } catch (e, s) {
      print('Backup error $e $s');
      return null;
    }
  }

    static Future<String> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
      );
      if (result == null) return 'BATAL';
      final path = result.files.single.path;
      if (path == null) return 'GAGAL: path null';
      if (!path.toLowerCase().endsWith('.bskro')) return 'GAGAL: Bukan .bskro';

      String jsonStr;
      try {
        // coba baca normal dulu (untuk backup baru)
        jsonStr = await File(path).readAsString();
      } catch (_) {
        // kalau gagal (backup lama yang bikin error offset 98) baca paksa
        final bytes = await File(path).readAsBytes();
        jsonStr = utf8.decode(bytes, allowMalformed: true);
      }

      // bersihin karakter aneh dari backup lama kalau ada
      jsonStr = jsonStr.replaceAll(RegExp(r'[^\x20-\x7E\x0A\x0D]'), '');

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
              id: Value(m['id'] ?? 0),
              namaKategori: m['namaKategori'] ?? m['nama'] ?? '',
              tarifPerHari: (m['tarifPerHari'] as int? ?? 0),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (var m in (json['karyawan'] ?? [])) {
          await db.into(db.karyawan).insert(
            KaryawanCompanion.insert(
              id: Value(m['id'] ?? 0),
              nama: m['nama'] ?? '',
              kategoriId: m['kategoriId'] ?? 1,
              fotoPath: Value(m['fotoPath']),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
      return 'SUKSES';
    } catch (e) {
      return 'GAGAL: $e';
    }
  }
}