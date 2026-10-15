import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../dbases/localdatabase.dart';

class BackupService {
  static final db = AppDatabase();

  static Map<String, dynamic> _fix(Map<String, dynamic> m) {
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
      final transaksi = await db.select(db.transaksi).get();
      final audit = await db.select(db.auditLog).get();
      final laba = await db.select(db.simulasiLaba).get();
      final bintang = await db.select(db.bintangHarian).get();
      final laporan = await db.select(db.laporanHarian).get();
      final kasbon = await db.select(db.kasbonHarian).get();

      final data = {
        'versi': 10,
        'tanggal': DateTime.now().toIso8601String(),
        'kategoriKaryawan': kategori.map((e) => _fix(e.toJson())).toList(),
        'karyawan': karyawan.map((e) => _fix(e.toJson())).toList(),
        'absensi': absensi.map((e) => _fix(e.toJson())).toList(),
        'gajiMingguan': gaji.map((e) => _fix(e.toJson())).toList(),
        'transaksi': transaksi.map((e) => _fix(e.toJson())).toList(),
        'auditLog': audit.map((e) => _fix(e.toJson())).toList(),
        'simulasiLaba': laba.map((e) => _fix(e.toJson())).toList(),
        'bintangHarian': bintang.map((e) => _fix(e.toJson())).toList(),
        'laporanHarian': laporan.map((e) => _fix(e.toJson())).toList(),
        'kasbonHarian': kasbon.map((e) => _fix(e.toJson())).toList(),
      };

      final jsonString = jsonEncode(data);
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = 'TB_SLAMET_JAYA_${DateTime.now().millisecondsSinceEpoch}.bskro';
      final fileDoc = File('${docDir.path}/$fileName');
      await fileDoc.writeAsString(jsonString, flush: true);

      try {
        final down = Directory('/storage/emulated/0/Download');
        if (await down.exists()) {
          final f = File('${down.path}/$fileName');
          await f.writeAsString(jsonString, flush: true);
          return f.path;
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

      final jsonStr = utf8.decode(bytes, allowMalformed: true);
      final Map<String, dynamic> json = jsonDecode(jsonStr);

      DateTime parseTgl(dynamic v) {
        if (v == null) return DateTime.now();
        try { return DateTime.parse(v.toString()); } catch (_) { return DateTime.now(); }
      }

      await db.transaction(() async {
        await db.delete(db.kasbonHarian).go();
        await db.delete(db.laporanHarian).go();
        await db.delete(db.bintangHarian).go();
        await db.delete(db.simulasiLaba).go();
        await db.delete(db.auditLog).go();
        await db.delete(db.transaksi).go();
        await db.delete(db.gajiMingguan).go();
        await db.delete(db.absensi).go();
        await db.delete(db.karyawan).go();
        await db.delete(db.kategoriKaryawan).go();

        for (var m in (json['kategoriKaryawan']?? [])) {
          final tarif = m['tarifPerHari'] is int? m['tarifPerHari'] : int.tryParse('${m['tarifPerHari']}')?? 0;
          await db.into(db.kategoriKaryawan).insert(KategoriKaryawanCompanion.insert(id: Value(m['id']?? 0), namaKategori: m['namaKategori']?? '', tarifPerHari: tarif), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['karyawan']?? [])) {
          await db.into(db.karyawan).insert(KaryawanCompanion.insert(id: Value(m['id']?? 0), nama: m['nama']?? '', kategoriId: m['kategoriId']?? 1, fotoPath: Value(m['fotoPath'])), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['absensi']?? [])) {
          await db.into(db.absensi).insert(AbsensiCompanion.insert(id: Value(m['id']?? 0), karyawanId: m['karyawanId']?? 0, jamMasuk: parseTgl(m['jamMasuk']), jamPulang: Value(m['jamPulang']!=null? parseTgl(m['jamPulang']) : null), totalJamKerja: Value((m['totalJamKerja']?? 8).toDouble()), metode: m['metode']?? 'manual', keterangan: Value(m['keterangan']?? ''), tipeKerja: Value(m['tipeKerja']?? 'FULL')), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['gajiMingguan']?? [])) {
          await db.into(db.gajiMingguan).insert(GajiMingguanCompanion.insert(id: Value(m['id']?? 0), karyawanId: m['karyawanId']?? 0, mingguMulai: parseTgl(m['mingguMulai']), mingguSelesai: parseTgl(m['mingguSelesai']), totalGaji: m['totalGaji']?? 0, totalHariEfektif: Value((m['totalHariEfektif']?? 0).toDouble()), totalHariMasuk: Value(m['totalHariMasuk']?? 0), totalJam: Value((m['totalJam']?? 0).toDouble()), totalGajiPokok: Value(m['totalGajiPokok']?? 0), bonusMingguan: Value(m['bonusMingguan']?? 0), totalBonus: Value(m['totalBonus']?? 0), statusBayar: Value(m['statusBayar']?? 'BELUM'), tanggalBayar: Value(m['tanggalBayar']!=null? parseTgl(m['tanggalBayar']) : null)), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['transaksi']?? [])) {
          await db.into(db.transaksi).insert(TransaksiCompanion.insert(id: Value(m['id']?? 0), jenis: m['jenis']?? '', keterangan: m['keterangan']?? '', nominal: m['nominal']?? 0, tanggal: parseTgl(m['tanggal'])), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['bintangHarian']?? [])) {
          await db.into(db.bintangHarian).insert(BintangHarianCompanion.insert(id: Value(m['id']?? 0), karyawanId: m['karyawanId']?? 0, tanggal: parseTgl(m['tanggal']), bintang: Value(m['bintang']?? 0)), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['laporanHarian']?? [])) {
          await db.into(db.laporanHarian).insert(LaporanHarianCompanion.insert(id: Value(m['id']?? 0), tanggal: parseTgl(m['tanggal']), totalPenjualan: Value(m['totalPenjualan']?? 0), cash: Value(m['cash']?? 0), piutangBaru: Value(m['piutangBaru']?? 0), namaPelangganBon: Value(m['namaPelangganBon']?? ''), bebanOperasional: Value(m['bebanOperasional']?? 0), kasbonKaryawan: Value(m['kasbonKaryawan']?? 0), tambahanLain: Value(m['tambahanLain']?? 0), keteranganTambahan: Value(m['keteranganTambahan']?? ''), saldoPiutangKemarin: Value(m['saldoPiutangKemarin']?? 0), totalGajiHariIni: Value(m['totalGajiHariIni']?? 0), labaKotor: Value(m['labaKotor']?? 0), labaBersih: Value(m['labaBersih']?? 0), kasHariIni: Value(m['kasHariIni']?? 0), totalPiutangAkhir: Value(m['totalPiutangAkhir']?? 0)), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['kasbonHarian']?? [])) {
          await db.into(db.kasbonHarian).insert(KasbonHarianCompanion.insert(id: Value(m['id']?? 0), karyawanId: m['karyawanId']?? 0, tanggal: parseTgl(m['tanggal']), nominal: Value(m['nominal']?? 0), keterangan: Value(m['keterangan']?? '')), mode: InsertMode.insertOrReplace);
        }
      });
      return 'SUKSES';
    } catch (e) {
      print('RESTORE FAIL $e');
      return 'GAGAL: $e';
    }
  }
}