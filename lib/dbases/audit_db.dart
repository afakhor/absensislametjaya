import 'package:drift/drift.dart';
import 'localdatabase.dart';

extension AuditDao on AppDatabase {
  Future<void> catatAudit({required String aktor, required String aksi, required String target, required String detail}) async {
    await into(auditLog).insert(AuditLogCompanion.insert(
      aktor: aktor, aksi: aksi, target: target, detail: detail,
      status: aksi.contains('MANUAL') ? 'MENCURIGAKAN' : 'AMAN',
      waktu: Value(DateTime.now()),
    ));
  }

  Stream<List<AuditLogData>> watchAudit() {
    return (select(auditLog)..orderBy([(t) => OrderingTerm.desc(t.waktu)])).watch();
  }
}