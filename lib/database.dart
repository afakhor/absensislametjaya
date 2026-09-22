import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
part 'database.g.dart';

class KategoriKaryawan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get namaKategori => text()();
  IntColumn get tarifPerJam => integer()();
}
class Karyawan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nama => text()();
  IntColumn get kategoriId => integer().customConstraint('REFERENCES kategori_karyawan(id)')();
  TextColumn get fotoPath => text().nullable()(); // <--- TAMBAHAN FOTO
}

// di bawah ganti schemaVersion
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (migrator, from, to) async {
    if (from == 1) {
      await migrator.addColumn(karyawan, karyawan.fotoPath);
    }
  },
);
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
  TextColumn get jenis => text()(); // PENDAPATAN / BEBAN_OPERASIONAL
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
  AppDatabase() : super(driftDatabase(name: 'tb_slamet_jaya_v4_final'));
  @override int get schemaVersion => 1;

  Future<void> catatAudit({required String aktor, required String aksi, required String target, required String detail}) async {
    await into(auditLog).insert(AuditLogCompanion.insert(
      aktor: aktor, aksi: aksi, target: target, detail: detail,
      status: aksi.contains('MANUAL') ? 'MENCURIGAKAN' : 'AMAN',
      waktu: Value(DateTime.now()),
    ));
  }

  Future<void> prosesHitungGajiMingguan() async {
    final now = DateTime.now();
    final senin = now.subtract(Duration(days: now.weekday - 1));
    final seninStart = DateTime(senin.year, senin.month, senin.day);
    final mingguEnd = seninStart.add(const Duration(days: 6, hours: 23, minutes: 59));
    for (var kat in await select(kategoriKaryawan).get()) {
      for (var kar in await (select(karyawan)..where((t) => t.kategoriId.equals(kat.id))).get()) {
        final absenMinggu = await (select(absensi)..where((t) => t.karyawanId.equals(kar.id) & t.jamMasuk.isBiggerOrEqualValue(seninStart) & t.jamMasuk.isSmallerOrEqualValue(mingguEnd))).get();
        double totalJam = absenMinggu.fold(0.0, (p, e) => p + e.totalJamKerja);
        int totalGaji = (totalJam * kat.tarifPerJam).toInt();
        await (delete(gajiMingguan)..where((t) => t.karyawanId.equals(kar.id) & t.mingguMulai.equals(seninStart))).go();
        if (totalJam > 0) {
          await into(gajiMingguan).insert(GajiMingguanCompanion.insert(karyawanId: kar.id, mingguMulai: seninStart, mingguSelesai: mingguEnd, totalJam: totalJam, totalGaji: totalGaji));
        }
      }
    }
  }

  Future<Map<String, int>> hitungLabaBulanan(DateTime bulan) async {
    final awal = DateTime(bulan.year, bulan.month, 1);
    final akhir = DateTime(bulan.year, bulan.month + 1, 0, 23, 59);
    final gajiBulan = await (select(gajiMingguan)..where((t) => t.mingguMulai.isBiggerOrEqualValue(awal) & t.mingguMulai.isSmallerOrEqualValue(akhir))).get();
    int bebanGaji = gajiBulan.fold(0, (p, e) => p + e.totalGaji);
    final pendapatanList = await (select(transaksi)..where((t) => t.jenis.equals('PENDAPATAN') & t.tanggal.isBetweenValues(awal, akhir))).get();
    int pendapatan = pendapatanList.fold(0, (p, e) => p + e.nominal);
    final bebanOpsList = await (select(transaksi)..where((t) => t.jenis.equals('BEBAN_OPERASIONAL') & t.tanggal.isBetweenValues(awal, akhir))).get();
    int bebanOps = bebanOpsList.fold(0, (p, e) => p + e.nominal);
    return {'pendapatan': pendapatan, 'bebanGaji': bebanGaji, 'bebanOps': bebanOps, 'labaKotor': pendapatan - bebanGaji, 'labaBersih': pendapatan - bebanGaji - bebanOps};
  }
}