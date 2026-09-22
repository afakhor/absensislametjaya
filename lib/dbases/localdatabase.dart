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

@DriftDatabase(tables: [KategoriKaryawan, Karyawan, Absensi, GajiMingguan, Transaksi, AuditLog])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'tb_slamet_jaya_v5_owner_foto'));
  @override int get schemaVersion => 1;
}