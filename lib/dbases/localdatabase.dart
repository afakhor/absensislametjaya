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
  IntColumn get kategoriId => integer().customConstraint('REFERENCES kategori_karyawan(id)')();
  TextColumn get fotoPath => text().nullable()();
}

class Absensi extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get karyawanId => integer().customConstraint('REFERENCES karyawan(id)')();
  DateTimeColumn get jamMasuk => dateTime()();
  DateTimeColumn get jamPulang => dateTime().nullable()();
  RealColumn get totalJamKerja => real().withDefault(const Constant(8.0))();
  TextColumn get metode => text()();
  TextColumn get keterangan => text().withDefault(const Constant(''))();
  TextColumn get tipeKerja => text().withDefault(const Constant('FULL'))();
}

class GajiMingguan extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get karyawanId => integer().customConstraint('REFERENCES karyawan(id)')();
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
  DateTimeColumn get tanggalSimulasi => dateTime().withDefault(currentDateAndTime)();
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
  IntColumn get karyawanId => integer().customConstraint('REFERENCES karyawan(id) ON DELETE CASCADE')();
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
  IntColumn get saldoPiutangKemarin => integer().withDefault(const Constant(0))();
  IntColumn get totalGajiHariIni => integer().withDefault(const Constant(0))();
  IntColumn get labaKotor => integer().withDefault(const Constant(0))();
  IntColumn get labaBersih => integer().withDefault(const Constant(0))();
  IntColumn get kasHariIni => integer().withDefault(const Constant(0))();
  IntColumn get totalPiutangAkhir => integer().withDefault(const Constant(0))();
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
  LaporanHarian
])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();

  factory AppDatabase() => _instance;

  AppDatabase._internal() : super(driftDatabase(name: 'tb_slamet_jaya_v8_clean'));

  @override
  int get schemaVersion => 8;

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
            await m.addColumn(laporanHarian, laporanHarian.saldoPiutangKemarin);
            await m.addColumn(laporanHarian, laporanHarian.kasHariIni);
            await m.addColumn(laporanHarian, laporanHarian.totalPiutangAkhir);
          }
        },
      );
}
