import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../dbases/localdatabase.dart';

class BackupService {
  static final db = AppDatabase();

  static Map<String, dynamic> _fixMap(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v is DateTime) out[k] = v.toIso8601String();
      else out[k] = v;
    });
    return out;
  }

  static Future<String?> exportBackup() async {
    try {
      final kategori = await db.select(db.kategoriKaryawan).get();
      final karyawan = await db.select(db.karyawan).get();
      final absensi = await db.select(db.absensi).get();
      final gaji = await db.select(db.gajiMingguan).get();
      final bintang = await db.select(db.bintangHarian).get();
      final kasbon = await db.select(db.kasbonHarian).get();
      final laporan = await db.select(db.laporanHarian).get();

      final data = {
        'versi': 6,
        'tanggal': DateTime.now().toIso8601String(),
        'kategoriKaryawan': kategori.map((e) => _fixMap(e.toJson())).toList(),
        'karyawan': karyawan.map((e) => _fixMap(e.toJson())).toList(),
        'absensi': absensi.map((e) => _fixMap(e.toJson())).toList(),
        'bintangHarian': bintang.map((e) => _fixMap(e.toJson())).toList(),
        'kasbonHarian': kasbon.map((e) => _fixMap(e.toJson())).toList(),
        'gajiMingguan': gaji.map((e) => _fixMap(e.toJson())).toList(),
        'laporanHarian': laporan.map((e) => _fixMap(e.toJson())).toList(),
      };

      final jsonString = jsonEncode(data);
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = 'TB_SLAMET_JAYA_${DateTime.now().millisecondsSinceEpoch}.bskro';
      final fileDoc = File('${docDir.path}/$fileName');
      await fileDoc.writeAsString(jsonString, flush: true);

      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final fileDown = File('${downloadDir.path}/$fileName');
          await fileDown.writeAsString(jsonString, flush: true);
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
      final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: false);
      if (result == null) return 'BATAL';
      final path = result.files.single.path;
      if (path == null) return 'GAGAL: path null';

      final bytes = await File(path).readAsBytes();
      final head = utf8.decode(bytes.take(20).toList(), allowMalformed: true);

      // JIKA FILE.bskro ISINYA DB MENTAH
      if (head.startsWith('SQLite format 3')) {
        try {
          await db.close();
          final docs = await getApplicationDocumentsDirectory();
          final dbFile = File('${docs.path}/tb_slamet_jaya_v8_clean');
          await File(path).copy(dbFile.path);
          return 'SUKSES RESTORE DB MENTAH - Restart aplikasi';
        } catch (e) {
          return 'GAGAL COPY DB: $e';
        }
      }

      // FIX: jsonStr baru di-assign di sini, jadi gak error non-nullable lagi
      final jsonStr = utf8.decode(bytes, allowMalformed: true);
      final Map<String, dynamic> json = jsonDecode(jsonStr);

      await db.transaction(() async {
        await db.delete(db.gajiMingguan).go();
        await db.delete(db.laporanHarian).go();
        await db.delete(db.kasbonHarian).go();
        await db.delete(db.bintangHarian).go();
        await db.delete(db.absensi).go();
        await db.delete(db.karyawan).go();
        await db.delete(db.kategoriKaryawan).go();

        for (var m in (json['kategoriKaryawan']?? [])) {
          final tarif = m['tarifPerHari'] is int? m['tarifPerHari'] : int.tryParse(m['tarifPerHari'].toString())?? 0;
          await db.into(db.kategoriKaryawan).insert(KategoriKaryawanCompanion.insert(id: Value(m['id']?? 0), namaKategori: m['namaKategori']?? '', tarifPerHari: tarif), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['karyawan']?? [])) {
          await db.into(db.karyawan).insert(KaryawanCompanion.insert(id: Value(m['id']?? 0), nama: m['nama']?? '', kategoriId: m['kategoriId']?? 1, fotoPath: Value(m['fotoPath'])), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['absensi']?? [])) {
          await db.into(db.absensi).insert(AbsensiCompanion.insert(id: Value(m['id']?? 0), karyawanId: m['karyawanId']?? 0, tanggal: DateTime.tryParse(m['tanggal'].toString())?? DateTime.now(), tipe: m['tipe']?? 'masuk'), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['bintangHarian']?? [])) {
          await db.into(db.bintangHarian).insert(BintangHarianCompanion.insert(id: Value(m['id']?? 0), karyawanId: m['karyawanId']?? 0, tanggal: DateTime.tryParse(m['tanggal'].toString())?? DateTime.now(), bintang: m['bintang']?? 0), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['kasbonHarian']?? [])) {
          await db.into(db.kasbonHarian).insert(KasbonHarianCompanion.insert(id: Value(m['id']?? 0), karyawanId: m['karyawanId']?? 0, tanggal: DateTime.tryParse(m['tanggal'].toString())?? DateTime.now(), jumlah: m['jumlah']?? 0), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['laporanHarian']?? [])) {
          await db.into(db.laporanHarian).insert(LaporanHarianCompanion.insert(id: Value(m['id']?? 0), tanggal: DateTime.tryParse(m['tanggal'].toString())?? DateTime.now(), catatan: Value(m['catatan']?? '')), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['gajiMingguan']?? [])) {
          await db.into(db.gajiMingguan).insert(GajiMingguanCompanion.insert(id: Value(m['id']?? 0), mingguKe: m['mingguKe']?? 0, tahun: m['tahun']?? DateTime.now().year), mode: InsertMode.insertOrReplace);
        }
      });
      return 'SUKSES';
    } catch (e) {
      return 'GAGAL: $e';
    }
  }
}