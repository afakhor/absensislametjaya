import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../dbases/localdatabase.dart';
import '../dbases/audit_db.dart'; // untuk audit_page

class AuditPage extends StatelessWidget { const AuditPage({super.key}); @override Widget build(BuildContext context) { final db = AppDatabase(); return Scaffold(body: StreamBuilder<List<AuditLogData>>(stream: (db.select(db.auditLog)..orderBy([(t) => drift.OrderingTerm.desc(t.waktu)])).watch(), builder: (c, s) { if (!s.hasData) return const Center(child: CircularProgressIndicator()); return ListView.builder(itemCount: s.data!.length, itemBuilder: (_, i) { var l = s.data![i]; return ListTile(title: Text("${l.aksi} - ${l.aktor}"), subtitle: Text("${l.target} - ${l.status}")); }); })); } }