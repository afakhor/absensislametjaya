import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'localdatabase.g.dart';

class KategoriKaryawan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get namaKategori => text()();
  IntColumn get tarifPerHari => integer()();
}

class Karyawan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nama => text()();
  IntColumn get kategoriId =>
      integer().customConstraint('REFERENCES kategori_karyawan(id) NOT NULL')();
  TextColumn get fotoPath => text().nullable()();
}

class Absensi extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get karyawanId =>
      integer().customConstraint('REFERENCES karyawan(id) NOT NULL')();
  DateTimeColumn get jamMasuk => dateTime()();
  DateTimeColumn get jamPulang => dateTime().nullable()();
  RealColumn get totalJamKerja => real().withDefault(const Constant(8.0))();
  TextColumn get metode => text()();
  TextColumn get keterangan => text().withDefault(const Constant(''))();
  TextColumn get tipeKerja => text().withDefault(const Constant('FULL'))();
}

class GajiMingguan extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get karyawanId =>
      integer().customConstraint('REFERENCES karyawan(id) NOT NULL')();
  DateTimeColumn get mingguMulai => dateTime()();
  DateTimeColumn get mingguSelesai => dateTime()();
  RealColumn get totalHariEfektif => real().withDefault(const Constant(0))();
  IntColumn get totalHariMasuk => integer().withDefault(const Constant(0))();
  RealColumn get totalJam => real().withDefault(const Constant(0))();
  IntColumn get totalGajiPokok => integer().withDefault(const Constant(0))();
  IntColumn get bonusMingguan => integer().withDefault(const Constant(0))();
  IntColumn get totalGaji => integer()();
  IntColumn get totalBonus => integer().withDefault(const Constant(0))();
  TextColumn get statusBayar => text().withDefault(const Constant('BELUM'))();
  DateTimeColumn get tanggalBayar => dateTime().nullable()();
}

class Transaksi extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get jenis => text()();
  TextColumn get keterangan => text()();
  IntColumn get nominal => integer()();
  DateTimeColumn get tanggal => dateTime()();
}

class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get waktu => dateTime().withDefault(currentDateAndTime)();
  TextColumn get aktor => text()();
  TextColumn get aksi => text()();
  TextColumn get target => text()();
  TextColumn get detail => text()();
  TextColumn get status => text()();
}

class SimulasiLaba extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get tanggalSimulasi =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get periodeMulai => dateTime()();
  DateTimeColumn get periodeSelesai => dateTime()();
  IntColumn get omset => integer()();
  IntColumn get pemasukanLain => integer()();
  IntColumn get bebanOperasional => integer()();
  IntColumn get bebanLain => integer()();
  IntColumn get bebanGaji => integer()();
  IntColumn get totalPemasukan => integer()();
  IntColumn get totalBeban => integer()();
  IntColumn get labaKotor => integer()();
  IntColumn get labaBersih => integer()();
  TextColumn get catatan => text().nullable()();
}

class BintangHarian extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get karyawanId => integer().customConstraint(
      'REFERENCES karyawan(id) ON DELETE CASCADE NOT NULL')();
  DateTimeColumn get tanggal => dateTime()();
  IntColumn get bintang => integer().withDefault(const Constant(0))();
}

class LaporanHarian extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get tanggal => dateTime().unique()();
  IntColumn get totalPenjualan => integer().withDefault(const Constant(0))();
  IntColumn get cash => integer().withDefault(const Constant(0))();
  IntColumn get piutangBaru => integer().withDefault(const Constant(0))();
  TextColumn get namaPelangganBon => text().withDefault(const Constant(''))();
  IntColumn get bebanOperasional => integer().withDefault(const Constant(0))();
  IntColumn get kasbonKaryawan => integer().withDefault(const Constant(0))();
  IntColumn get tambahanLain => integer().withDefault(const Constant(0))();
  TextColumn get keteranganTambahan => text().withDefault(const Constant(''))();
  IntColumn get saldoPiutangKemarin =>
      integer().withDefault(const Constant(0))();
  IntColumn get totalGajiHariIni => integer().withDefault(const Constant(0))();
  IntColumn get labaKotor => integer().withDefault(const Constant(0))();
  IntColumn get labaBersih => integer().withDefault(const Constant(0))();
  IntColumn get kasHariIni => integer().withDefault(const Constant(0))();
  IntColumn get totalPiutangAkhir =>
      integer().withDefault(const Constant(0))();
}

class KasbonHarian extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get karyawanId => integer().customConstraint(
      'REFERENCES karyawan(id) ON DELETE CASCADE NOT NULL')();
  DateTimeColumn get tanggal => dateTime()();
  IntColumn get nominal => integer().withDefault(const Constant(0))();
  TextColumn get keterangan => text().withDefault(const Constant(''))();

  @override
  List<String> get customConstraints => [
        'UNIQUE(karyawan_id, tanggal)'
      ];
}

@DriftDatabase(tables: [
  KategoriKaryawan,
  Karyawan,
  Absensi,
  GajiMingguan,
  Transaksi,
  AuditLog,
  SimulasiLaba,
  BintangHarian,
  LaporanHarian,
  KasbonHarian
])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal()
      : super(driftDatabase(name: 'tb_slamet_jaya_v8_clean'));

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => await m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(simulasiLaba);
          if (from < 3) {
            await m.addColumn(absensi, absensi.tipeKerja);
            await m.addColumn(gajiMingguan, gajiMingguan.totalBonus);
            await m.addColumn(gajiMingguan, gajiMingguan.totalHariMasuk);
          }
          if (from < 4) {
            await m.addColumn(kategoriKaryawan, kategoriKaryawan.tarifPerHari);
            await m.addColumn(gajiMingguan, gajiMingguan.totalHariEfektif);
            await m.addColumn(gajiMingguan, gajiMingguan.totalGajiPokok);
            await m.addColumn(gajiMingguan, gajiMingguan.bonusMingguan);
            await m.addColumn(gajiMingguan, gajiMingguan.statusBayar);
            await m.addColumn(gajiMingguan, gajiMingguan.tanggalBayar);
          }
          if (from < 5) {
            await m.createTable(bintangHarian);
            await m.createTable(laporanHarian);
          }
          if (from < 8) {
            await m.addColumn(laporanHarian, laporanHarian.cash);
            await m.addColumn(laporanHarian, laporanHarian.piutangBaru);
            await m.addColumn(laporanHarian, laporanHarian.namaPelangganBon);
            await m.addColumn(laporanHarian, laporanHarian.kasbonKaryawan);
            await m.addColumn(
                laporanHarian, laporanHarian.saldoPiutangKemarin);
            await m.addColumn(laporanHarian, laporanHarian.kasHariIni);
            await m.addColumn(laporanHarian, laporanHarian.totalPiutangAkhir);
          }
          if (from < 9) {
            await m.createTable(kasbonHarian);
          }
          if (from < 10) {
            // Fix kasbon biar bisa update per karyawan per hari
            await m.createTable(kasbonHarian);
          }
        },
      );

  // --- HELPER METHODS DASHBOARD ---

  Future<void> updateTipeAbsen(int idAbsensi, String tipe) async {
    await (update(absensi)..where((t) => t.id.equals(idAbsensi))).write(
      AbsensiCompanion(
        tipeKerja: Value(tipe.toUpperCase().trim()),
      ),
    );
  }

  Future<void> setBintang(int karyawanId, DateTime tgl, int rating) async {
    final start = DateTime(tgl.year, tgl.month, tgl.day, 0, 0, 0);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59, 999);
    final existing = await (select(bintangHarian)
         ..where((t) => t.karyawanId.equals(karyawanId))
         ..where((t) => t.tanggal.isBiggerOrEqualValue(start))
         ..where((t) => t.tanggal.isSmallerOrEqualValue(end)))
       .getSingleOrNull();
    if (existing!= null) {
      await (update(bintangHarian)..where((t) => t.id.equals(existing.id)))
         .write(BintangHarianCompanion(bintang: Value(rating)));
    } else {
      await into(bintangHarian).insert(
        BintangHarianCompanion.insert(
          karyawanId: karyawanId,
          tanggal: start,
          bintang: Value(rating),
        ),
      );
    }
  }

  Stream<List<BintangHarianData>> watchBintangHari(DateTime tgl) {
    final start = DateTime(tgl.year, tgl.month, tgl.day, 0, 0, 0);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59, 999);
    return (select(bintangHarian)
         ..where((t) => t.tanggal.isBiggerOrEqualValue(start))
         ..where((t) => t.tanggal.isSmallerOrEqualValue(end)))
       .watch();
  }

  Stream<LaporanHarianData?> watchLaporanHari(DateTime tgl) {
    final start = DateTime(tgl.year, tgl.month, tgl.day, 0, 0, 0);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59, 999);
    return (select(laporanHarian)
         ..where((t) => t.tanggal.isBiggerOrEqualValue(start))
         ..where((t) => t.tanggal.isSmallerOrEqualValue(end)))
       .watchSingleOrNull();
  }

  Future<int> hitungGajiHariIni(DateTime tgl) async {
    final start = DateTime(tgl.year, tgl.month, tgl.day, 0, 0, 0);
    final end = DateTime(tgl.year, tgl.month, tgl.day, 23, 59, 59, 999);
    final absensiList = await (select(absensi)
         ..where((t) => t.jamMasuk.isBiggerOrEqualValue(start))
         ..where((t) => t.jamMasuk.isSmallerOrEqualValue(end)))
       .get();
    final listKategori = await select(kategoriKaryawan).get();
    final mapKategori = {for (var k in listKategori) k.id: k.tarifPerHari};
    final listKaryawan = await select(karyawan).get();
    final mapKaryawan = {for (var k in listKaryawan) k.id: k.kategoriId};
    int totalGaji = 0;
    for (var abs in absensiList) {
      final katId = mapKaryawan[abs.karyawanId];
      final tarif = mapKategori[katId]?? 0;
      final tipe = abs.tipeKerja.toUpperCase().trim();
      if (tipe == 'HALF' || tipe == 'HALF_DAY' || tipe == 'SETENGAH' || tipe == '½ HARI') {
        totalGaji += (tarif / 2).round();
      } else {
        totalGaji += tarif;
      }
    }
    return totalGaji;
  }

  // INI KUNCI NO 2: Setiap tanggal = 1 baris, tekan simpan berapa kalipun akan NIMPA
  Future<void> simpanLaporanHarianFull({
    required DateTime tgl,
    required int omset,
    required int cash,
    required int piutangBaru,
    required String namaPelanggan,
    required int pemLain,
    required String ketPemLain,
    required int bebanGaji,
    required int bebanOps,
    required int kasbon,
    required int piutangKemarin,
    required int labaKotor,
    required int labaBersih,
    required int kasHariIni,
    required int totalPiutangAkhir,
  }) async {
    final start = DateTime(tgl.year, tgl.month, tgl.day, 0, 0, 0); // normalisasi ke 00:00
    await into(laporanHarian).insertOnConflictUpdate(
      LaporanHarianCompanion(
        tanggal: Value(start),
        totalPenjualan: Value(omset),
        cash: Value(cash),
        piutangBaru: Value(piutangBaru),
        namaPelangganBon: Value(namaPelanggan),
        tambahanLain: Value(pemLain),
        keteranganTambahan: Value(ketPemLain),
        totalGajiHariIni: Value(bebanGaji),
        bebanOperasional: Value(bebanOps),
        kasbonKaryawan: Value(kasbon),
        saldoPiutangKemarin: Value(piutangKemarin),
        labaKotor: Value(labaKotor),
        labaBersih: Value(labaBersih),
        kasHariIni: Value(kasHariIni),
        totalPiutangAkhir: Value(totalPiutangAkhir),
      ),
    );
  }

  // FIX KASBON: sekarang update per karyawan per tanggal, bukan nambah terus
  Future<void> simpanKasbonHarian(
      int karyawanId, DateTime tanggal, int nominal, String keterangan) async {
    final startOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final endOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day, 23, 59, 59, 999);

    final existing = await (select(kasbonHarian)
     ..where((t) => t.karyawanId.equals(karyawanId))
     ..where((t) => t.tanggal.isBiggerOrEqualValue(startOfDay))
     ..where((t) => t.tanggal.isSmallerOrEqualValue(endOfDay))
    ).getSingleOrNull();

    if (existing!= null) {
      await (update(kasbonHarian)..where((t) => t.id.equals(existing.id))).write(
        KasbonHarianCompanion(
          nominal: Value(nominal),
          keterangan: Value(keterangan),
        ),
      );
    } else {
      await into(kasbonHarian).insert(
        KasbonHarianCompanion.insert(
          karyawanId: karyawanId,
          tanggal: startOfDay,
          nominal: Value(nominal),
          keterangan: Value(keterangan),
        ),
      );
    }
  }

  Stream<List<KasbonHarianData>> watchKasbonHariIni(DateTime tanggal) {
    final startOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final endOfDay =
        DateTime(tanggal.year, tanggal.month, tanggal.day, 23, 59, 59, 999);
    return (select(kasbonHarian)
         ..where((tbl) => tbl.tanggal.isBiggerOrEqualValue(startOfDay))
         ..where((tbl) => tbl.tanggal.isSmallerOrEqualValue(endOfDay)))
       .watch();
  }
}