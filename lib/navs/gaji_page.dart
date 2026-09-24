import 'package:flutter/material.dart';
import '../dbases/localdatabase.dart';
import '../dbases/setowner_db.dart';

class GajiPage extends StatefulWidget { const GajiPage({super.key}); @override State<GajiPage> createState()=> _GajiPageState(); }
class _GajiPageState extends State<GajiPage> {
  final db = AppDatabase();
  @override Widget build(BuildContext context){
    return Column(children: [
      Container(color: Colors.orange.shade50, width: double.infinity, padding: const EdgeInsets.all(12), child: const Text("GAJI DEBUG - KALO INI MUNCUL BERARTI BUILD SUKSES")),
      Expanded(child: StreamBuilder<List<KaryawanData>>(stream: db.watchKaryawan(), builder: (c,snap){
        if(snap.hasError) return Center(child: Text("ERROR DB: ${snap.error}"));
        if(!snap.hasData) return const Center(child: CircularProgressIndicator());
        return Center(child: Text("Total Karyawan: ${snap.data!.length}\n\nKalau ini muncul, berarti Dashboard blank karena query absensi, bukan karena Scaffold"));
      })),
    ]);
  }
}