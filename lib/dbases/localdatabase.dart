import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
part 'localdatabase.g.dart';

class KategoriKaryawan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get namaKategori => text()();
  IntColumn get tarifPerHari => integer()(); // FIX: DARI PER JAM JADI PER HARI
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
  TextColumn get tipeKerja => text().withDefault(const Constant('FULL'))(); // FULL / SETENGAH
  // FIX: BONUS HARIAN DIHAPUS - PINDAH KE GAJI MINGGUAN
}

class GajiMingguan extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get karyawanId => integer().customConstraint('REFERENCES karyawan(id)')();
  DateTimeColumn get mingguMulai => dateTime()();
  DateTimeColumn get mingguSelesai => dateTime()();
  RealColumn get totalHariEfektif => real().withDefault(const Constant(0))(); // 1 hari=1, ½ hari=0.5
  IntColumn get totalHariMasuk => integer().withDefault(const Constant(0))();
  RealColumn get totalJam => real().withDefault(const Constant(0))();
  IntColumn get totalGajiPokok => integer().withDefault(const Constant(0))();
  IntColumn get bonusMingguan => integer().withDefault(const Constant(0))(); // BONUS MINGGUAN DISINI
  IntColumn get totalGaji => integer()();
  IntColumn get totalBonus => integer().withDefault(const Constant(0))(); // legacy biar gak crash
  TextColumn get statusBayar => text().withDefault(const Constant('BELUM'))(); // BELUM / MINGGU1 / MINGGU2
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

@DriftDatabase(tables: [KategoriKaryawan, Karyawan, Absensi, GajiMingguan, Transaksi, AuditLog, SimulasiLaba])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'tb_slamet_jaya_v6_hari'));
  @override int get schemaVersion => 4;
  @override MigrationStrategy get migration => MigrationStrategy(
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
    },
  );
}