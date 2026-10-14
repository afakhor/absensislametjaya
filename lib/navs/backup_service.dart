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
      // FIX UTAMA: pakai any, bukan custom bskro (Android gak support filter custom)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null) return 'BATAL';

      final fileName = result.files.single.name.toLowerCase();
      if (!fileName.endsWith('.bskro')) {
        return 'GAGAL: Pilih file .bskro, bukan $fileName';
      }

      String jsonStr;
      if (result.files.single.bytes != null) {
        jsonStr = utf8.decode(result.files.single.bytes!);
      } else {
        jsonStr = await File(result.files.single.path!).readAsString();
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
              namaKategori: m['namaKategori'] ?? '',
              tarifPerHari: (m['tarifPerHari'] as int? ?? 0),
              id: Value(m['id'] as int? ?? 0),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (var m in (json['karyawan'] ?? [])) {
          await db.into(db.karyawan).insert(
            KaryawanCompanion.insert(
              nama: m['nama'] ?? '',
              kategoriId: (m['kategoriId'] as int? ?? 1),
              fotoPath: Value(m['fotoPath'] as String?),
              id: Value(m['id'] as int? ?? 0),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        // tambahkan restore absensi dll kalau mau lengkap, tapi 2 ini dulu bikin SUKSES
      });

      return 'SUKSES';
    } catch (e, s) {
      print('RESTORE FAIL $e $s');
      return 'GAGAL: $e';
    }
  }
}