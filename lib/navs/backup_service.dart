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

  static DateTime _parseTgl(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is int) {
      if (v > 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
      } else {
        return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true).toLocal();
      }
    }
    try {
      final asInt = int.tryParse(v.toString());
      if (asInt != null && asInt > 1000000000) {
        if (asInt > 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true).toLocal();
        } else {
          return DateTime.fromMillisecondsSinceEpoch(asInt * 1000, isUtc: true).toLocal();
        }
      }
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  static dynamic _get(Map m, List<String> keys) {
    for (var k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k];
    }
    return null;
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
          final support = await getApplicationSupportDirectory();
          for (var p in ['${docs.path}/tb_slamet_jaya_v8_clean', '${support.path}/tb_slamet_jaya_v8_clean']) {
            try {
              final wal = File('$p-wal'); if (await wal.exists()) await wal.delete();
              final shm = File('$p-shm'); if (await shm.exists()) await shm.delete();
              final dbf = File(p); if (await dbf.exists()) await dbf.delete();
            } catch (_) {}
          }
          await File(path).copy('${docs.path}/tb_slamet_jaya_v8_clean');
          try { await File(path).copy('${support.path}/tb_slamet_jaya_v8_clean'); } catch (_) {}
          return 'SUKSES RESTORE DB MENTAH - Tutup total app lalu buka lagi';
        } catch (e) {
          return 'GAGAL COPY DB: $e';
        }
      }

      final jsonStr = utf8.decode(bytes, allowMalformed: true);
      final Map<String, dynamic> json = jsonDecode(jsonStr);

      final validKaryawanIds = <int>{};
      for (var m in (json['karyawan'] ?? [])) {
        final id = _get(m, ['id']) ?? 0;
        if (id != 0) validKaryawanIds.add(id is int ? id : int.tryParse('$id') ?? 0);
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

        for (var m in (json['kategoriKaryawan'] ?? [])) {
          final id = _get(m, ['id']) ?? 0; if (id == 0) continue;
          final nama = _get(m, ['namaKategori', 'nama_kategori']) ?? '';
          final tarif = _get(m, ['tarifPerHari', 'tarif_per_hari']) ?? 0;
          final t = tarif is int ? tarif : int.tryParse('$tarif') ?? 0;
          await db.into(db.kategoriKaryawan).insert(KategoriKaryawanCompanion.insert(id: Value(id), namaKategori: nama, tarifPerHari: t), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['karyawan'] ?? [])) {
          final id = _get(m, ['id']) ?? 0; if (id == 0) continue;
          final nama = _get(m, ['nama']) ?? '';
          final katId = _get(m, ['kategoriId', 'kategori_id']) ?? 1;
          final foto = _get(m, ['fotoPath', 'foto_path']);
          await db.into(db.karyawan).insert(KaryawanCompanion.insert(id: Value(id), nama: nama, kategoriId: katId is int ? katId : int.tryParse('$katId') ?? 1, fotoPath: Value(foto)), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['absensi'] ?? [])) {
          final id = _get(m, ['id']) ?? 0; if (id == 0) continue;
          final kId = _get(m, ['karyawanId', 'karyawan_id']) ?? 0;
          final kIdInt = kId is int ? kId : int.tryParse('$kId') ?? 0;
          if (kIdInt == 0 || !validKaryawanIds.contains(kIdInt)) continue;
          await db.into(db.absensi).insert(AbsensiCompanion.insert(id: Value(id), karyawanId: kIdInt, jamMasuk: _parseTgl(_get(m, ['jamMasuk', 'jam_masuk'])), jamPulang: Value(_get(m, ['jamPulang', 'jam_pulang']) != null ? _parseTgl(_get(m, ['jamPulang', 'jam_pulang'])) : null), totalJamKerja: Value((_get(m, ['totalJamKerja', 'total_jam_kerja']) ?? 8).toDouble()), metode: _get(m, ['metode']) ?? 'FINGERPRINT', keterangan: Value(_get(m, ['keterangan']) ?? ''), tipeKerja: Value(_get(m, ['tipeKerja', 'tipe_kerja']) ?? 'FULL')), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['gajiMingguan'] ?? [])) {
          final id = _get(m, ['id']) ?? 0; if (id == 0) continue;
          final kId = _get(m, ['karyawanId', 'karyawan_id']) ?? 0;
          final kIdInt = kId is int ? kId : int.tryParse('$kId') ?? 0;
          if (kIdInt == 0 || !validKaryawanIds.contains(kIdInt)) continue;
          await db.into(db.gajiMingguan).insert(GajiMingguanCompanion.insert(id: Value(id), karyawanId: kIdInt, mingguMulai: _parseTgl(_get(m, ['mingguMulai', 'minggu_mulai'])), mingguSelesai: _parseTgl(_get(m, ['mingguSelesai', 'minggu_selesai'])), totalGaji: _get(m, ['totalGaji', 'total_gaji']) ?? 0, totalHariEfektif: Value((_get(m, ['totalHariEfektif', 'total_hari_efektif']) ?? 0).toDouble()), totalHariMasuk: Value(_get(m, ['totalHariMasuk', 'total_hari_masuk']) ?? 0), totalJam: Value((_get(m, ['totalJam', 'total_jam']) ?? 0).toDouble()), totalGajiPokok: Value(_get(m, ['totalGajiPokok', 'total_gaji_pokok']) ?? 0), bonusMingguan: Value(_get(m, ['bonusMingguan', 'bonus_mingguan']) ?? 0), totalBonus: Value(_get(m, ['totalBonus', 'total_bonus']) ?? 0), statusBayar: Value(_get(m, ['statusBayar', 'status_bayar']) ?? 'BELUM'), tanggalBayar: Value(_get(m, ['tanggalBayar', 'tanggal_bayar']) != null ? _parseTgl(_get(m, ['tanggalBayar', 'tanggal_bayar'])) : null)), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['transaksi'] ?? [])) {
          final id = _get(m, ['id']) ?? 0; if (id == 0) continue;
          await db.into(db.transaksi).insert(TransaksiCompanion.insert(id: Value(id), jenis: _get(m, ['jenis']) ?? '', keterangan: _get(m, ['keterangan']) ?? '', nominal: _get(m, ['nominal']) ?? 0, tanggal: _parseTgl(_get(m, ['tanggal']))), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['bintangHarian'] ?? [])) {
          final id = _get(m, ['id']) ?? 0; if (id == 0) continue;
          final kId = _get(m, ['karyawanId', 'karyawan_id']) ?? 0; final kIdInt = kId is int ? kId : int.tryParse('$kId') ?? 0;
          if (kIdInt == 0 || !validKaryawanIds.contains(kIdInt)) continue;
          await db.into(db.bintangHarian).insert(BintangHarianCompanion.insert(id: Value(id), karyawanId: kIdInt, tanggal: _parseTgl(_get(m, ['tanggal'])), bintang: Value(_get(m, ['bintang']) ?? 0)), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['laporanHarian'] ?? [])) {
          final id = _get(m, ['id']) ?? 0; if (id == 0) continue;
          await db.into(db.laporanHarian).insert(LaporanHarianCompanion.insert(id: Value(id), tanggal: _parseTgl(_get(m, ['tanggal'])), totalPenjualan: Value(_get(m, ['totalPenjualan', 'total_penjualan']) ?? 0), cash: Value(_get(m, ['cash']) ?? 0), piutangBaru: Value(_get(m, ['piutangBaru', 'piutang_baru']) ?? 0), namaPelangganBon: Value(_get(m, ['namaPelangganBon', 'nama_pelanggan_bon']) ?? ''), bebanOperasional: Value(_get(m, ['bebanOperasional', 'beban_operasional']) ?? 0), kasbonKaryawan: Value(_get(m, ['kasbonKaryawan', 'kasbon_karyawan']) ?? 0), tambahanLain: Value(_get(m, ['tambahanLain', 'tambahan_lain']) ?? 0), keteranganTambahan: Value(_get(m, ['keteranganTambahan', 'keterangan_tambahan']) ?? ''), saldoPiutangKemarin: Value(_get(m, ['saldoPiutangKemarin', 'saldo_piutang_kemarin']) ?? 0), totalGajiHariIni: Value(_get(m, ['totalGajiHariIni', 'total_gaji_hari_ini']) ?? 0), labaKotor: Value(_get(m, ['labaKotor', 'laba_kotor']) ?? 0), labaBersih: Value(_get(m, ['labaBersih', 'laba_bersih']) ?? 0), kasHariIni: Value(_get(m, ['kasHariIni', 'kas_hari_ini']) ?? 0), totalPiutangAkhir: Value(_get(m, ['totalPiutangAkhir', 'total_piutang_akhir']) ?? 0)), mode: InsertMode.insertOrReplace);
        }
        for (var m in (json['kasbonHarian'] ?? [])) {
          final id = _get(m, ['id']) ?? 0; if (id == 0) continue;
          final kId = _get(m, ['karyawanId', 'karyawan_id']) ?? 0; final kIdInt = kId is int ? kId : int.tryParse('$kId') ?? 0;
          if (kIdInt == 0 || !validKaryawanIds.contains(kIdInt)) continue;
          await db.into(db.kasbonHarian).insert(KasbonHarianCompanion.insert(id: Value(id), karyawanId: kIdInt, tanggal: _parseTgl(_get(m, ['tanggal'])), nominal: Value(_get(m, ['nominal']) ?? 0), keterangan: Value(_get(m, ['keterangan']) ?? '')), mode: InsertMode.insertOrReplace);
        }
      });
      return 'SUKSES - ${validKaryawanIds.length} karyawan, tanpa ID:0, periode fix WIB';
    } catch (e, s) {
      print('RESTORE FAIL $e $s');
      return 'GAGAL: $e';
    }
  }
}
