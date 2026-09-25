import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../dbases/localdatabase.dart';
import '../dbases/gaji_db.dart';

class GajiPage extends StatefulWidget { const GajiPage({super.key}); @override State<GajiPage> createState()=> _GajiPageState(); }
class _GajiPageState extends State<GajiPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###","id_ID");
  DateTime _bulan = DateTime.now();
  @override void initState(){ super.initState(); db.prosesHitungGajiMingguan(); }
  @override Widget build(BuildContext context){
    return Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(12), color: Colors.orange.shade50, child: FutureBuilder<int>(future: db.getTotalGajianSemua(), builder: (c,s)=> Text("Total Gajian Rp ${fmt.format(s.data??0)} - ${DateFormat('MMMM yyyy','id_ID').format(_bulan)}", style: const TextStyle(fontWeight: FontWeight.bold)))),
      Expanded(child: StreamBuilder<List<GajiMingguanData>>(stream: (db.select(db.gajiMingguan)..orderBy([(t)=> OrderingTerm.desc(t.mingguMulai)])).watch(), builder: (c,s){
        if(s.hasError) return Center(child: Text("Error ${s.error}"));
        if(!s.hasData) return const Center(child: CircularProgressIndicator());
        final filtered=s.data!.where((g)=> g.mingguMulai.month==_bulan.month).toList();
        if(filtered.isEmpty) return const Center(child: Text("Belum ada gaji\nAbsen dulu"));
        return ListView.builder(itemCount: filtered.length, itemBuilder: (_,i){
          var g=filtered[i];
          return FutureBuilder<KaryawanData?>(future: (db.select(db.karyawan)..where((t)=>t.id.equals(g.karyawanId))).getSingleOrNull(), builder: (c,kar){
            return Card(margin: const EdgeInsets.all(8), child: ListTile(
              title: Text(kar.data?.nama??"ID ${g.karyawanId}", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${g.mingguMulai.day}-${g.mingguSelesai.day} | ${g.totalHariEfektif} hari | Rp ${fmt.format(g.totalGaji)} | ${g.statusBayar}"),
              trailing: PopupMenuButton(onSelected: (v)=> db.tandaiBayar(g.id, v.toString()), itemBuilder: (_)=>[const PopupMenuItem(value:'BELUM', child: Text("🔴 Belum")), const PopupMenuItem(value:'MINGGU1', child: Text("🟡 1 Minggu")), const PopupMenuItem(value:'MINGGU2', child: Text("🟢 Lunas"))]),
            ));
          });
        });
      })),
    ]);
  }
}