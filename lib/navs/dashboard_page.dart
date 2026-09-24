import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../dbases/localdatabase.dart';
import '../dbases/setowner_db.dart';

class DashboardPage extends StatefulWidget { const DashboardPage({super.key}); @override State<DashboardPage> createState() => _DashboardPageState(); }
class _DashboardPageState extends State<DashboardPage> {
  final db = AppDatabase();
  @override Widget build(BuildContext context){
    return Column(children: [
      Container(color: Colors.brown.shade800, width: double.infinity, padding: const EdgeInsets.all(12), child: const Text("DASHBOARD DEBUG - KALO INI MUNCUL BERARTI BUILD SUKSES", style: TextStyle(color: Colors.white))),
      Expanded(child: StreamBuilder<List<KaryawanData>>(stream: db.watchKaryawan(), builder: (c,snap){
        if(snap.hasError) return Center(child: Text("ERROR DB: ${snap.error}\n\nJalankan build_runner!", textAlign: TextAlign.center));
        if(!snap.hasData) return const Center(child: CircularProgressIndicator());
        if(snap.data!.isEmpty) return const Center(child: Text("DB Karyawan Kosong\nTambah dulu di Owner"));
        return ListView(children: snap.data!.map((k)=> ListTile(title: Text(k.nama))).toList());
      })),
    ]);
  }
}