import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
part 'localdatabase.g.dart';

class KategoriKaryawan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get namaKategori => text()();
  IntColumn get tarifPerJam => integer()();
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
}
class GajiMingguan extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get karyawanId => integer().customConstraint('REFERENCES karyawan(id)')();
  DateTimeColumn get mingguMulai => dateTime()();
  DateTimeColumn get mingguSelesai => dateTime()();
  RealColumn get totalJam => real()();
  IntColumn get totalGaji => integer()();
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
// TAMBAHAN BARU - LOG SIMULASI LABA
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
  AppDatabase() : super(driftDatabase(name: 'tb_slamet_jaya_v5_owner_foto'));
  @override int get schemaVersion => 2;
  @override MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => await m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(simulasiLaba);
      }
    }
  );
}