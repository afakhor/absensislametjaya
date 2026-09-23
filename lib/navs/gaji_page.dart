import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../dbases/localdatabase.dart';
import '../dbases/gaji_db.dart';

class GajiPage extends StatefulWidget { const GajiPage({super.key}); @override State<GajiPage> createState() => _GajiPageState(); }

class _GajiPageState extends State<GajiPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  DateTime _bulan = DateTime.now();
  Color _warnaStatus(String s){ if(s=='BELUM') return Colors.red.shade100; if(s=='MINGGU1') return Colors.amber.shade100; return Colors.green.shade100; }
  Color _dotStatus(String s){ if(s=='BELUM') return Colors.red; if(s=='MINGGU1') return Colors.orange; return Colors.green; }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Gaji ${DateFormat('MMMM yyyy').format(_bulan)}"), backgroundColor: Colors.brown.shade800, foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.calendar_month), onPressed: () async { final p=await showDatePicker(context: context, initialDate: _bulan, firstDate: DateTime(2023), lastDate: DateTime(2030)); if(p!=null) setState(()=>_bulan=p); }), IconButton(icon: const Icon(Icons.refresh), onPressed: ()=>db.prosesHitungGajiMingguan())]),
      body: Column(children: [
        FutureBuilder<int>(future: db.getTotalGajianSemua(), builder: (c,s)=>Container(width: double.infinity, padding: const EdgeInsets.all(16), color: Colors.orange.shade50, child: Column(children: [
          const Text("TOTAL GAJIAN SEMUA KARYAWAN", style: TextStyle(fontSize: 12)),
          Text("Rp ${fmt.format(s.data??0)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown.shade800)),
          const Text("Merah=Belum | Kuning=1 Minggu | Hijau=2 Minggu", style: TextStyle(fontSize: 10)),
        ]))),
        Expanded(child: StreamBuilder<List<GajiMingguanData>>(stream: (db.select(db.gajiMingguan)..orderBy([(t)=>drift.OrderingTerm.desc(t.mingguMulai)])).watch(), builder: (c,s){
          if(!s.hasData) return const Center(child: CircularProgressIndicator());
          final filtered = s.data!.where((g)=> g.mingguMulai.month==_bulan.month && g.mingguMulai.year==_bulan.year).toList();
          if(filtered.isEmpty) return const Center(child: Text("Belum ada gaji\nAbsen harian dulu"));
          return ListView.builder(itemCount: filtered.length, itemBuilder: (_,i){
            var g=filtered[i];
            return FutureBuilder<KaryawanData?>(future: (db.select(db.karyawan)..where((t)=>t.id.equals(g.karyawanId))).getSingleOrNull(), builder: (c,kar){
              return FutureBuilder<List<AbsensiData>>(future: db.select(db.absensi).get().then((all)=> all.where((a)=> a.karyawanId==g.karyawanId && a.jamMasuk.isAfter(g.mingguMulai.subtract(const Duration(seconds:1))) && a.jamMasuk.isBefore(g.mingguSelesai.add(const Duration(seconds:1)))).toList()), builder: (c,absSnap){
                final list=absSnap.data??[]; final full=list.where((a)=>a.tipeKerja=='FULL').length; final half=list.where((a)=>a.tipeKerja=='SETENGAH').length;
                return Card(color: _warnaStatus(g.statusBayar), margin: const EdgeInsets.symmetric(horizontal:12, vertical:6), child: ListTile(
                  leading: Icon(Icons.circle, color: _dotStatus(g.statusBayar)),
                  title: Text(kar.data?.nama??"ID ${g.karyawanId}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("${g.mingguMulai.day}/${g.mingguMulai.month}-${g.mingguSelesai.day}/${g.mingguSelesai.month} | ${g.totalHariEfektif} hari (Full:$full, ½:$half)"),
                    Text("Pokok Rp ${fmt.format(g.totalGajiPokok)} + Bonus Rp ${fmt.format(g.bonusMingguan)} = Rp ${fmt.format(g.totalGaji)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("Status: ${g.statusBayar}", style: TextStyle(fontSize:11, color: _dotStatus(g.statusBayar), fontWeight: FontWeight.bold)),
                  ]),
                  trailing: PopupMenuButton(onSelected: (v) async {
                    if(v=='bonus'){
                      var ctrl=TextEditingController(text: g.bonusMingguan.toString());
                      showDialog(context: context, builder: (_)=>AlertDialog(title: const Text("Input Bonus Mingguan"), content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Bonus Rp", border: OutlineInputBorder())), actions: [TextButton(onPressed: () async { await db.inputBonusMingguan(g.id, int.tryParse(ctrl.text)??0); if(context.mounted) Navigator.pop(context); }, child: const Text("SIMPAN"))]));
                    } else { await db.tandaiBayar(g.id, v.toString()); }
                  }, itemBuilder: (_)=>[
                    const PopupMenuItem(value: 'bonus', child: Text("💰 Input Bonus Minggu Ini")),
                    const PopupMenuItem(value: 'BELUM', child: Text("🔴 Belum Terima")),
                    const PopupMenuItem(value: 'MINGGU1', child: Text("🟡 Akumulasi 1 Minggu")),
                    const PopupMenuItem(value: 'MINGGU2', child: Text("🟢 Akumulasi 2 Minggu / Lunas")),
                  ]),
                ));
              });
            });
          });
        })),
      ]),
    );
  }
}