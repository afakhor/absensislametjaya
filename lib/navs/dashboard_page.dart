import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart';
import '../dbases/localdatabase.dart';
import '../dbases/setowner_db.dart';
import '../dbases/absen_db.dart';
import '../dbases/gaji_db.dart';

class DashboardPage extends StatefulWidget { const DashboardPage({super.key}); @override State<DashboardPage> createState() => _DashboardPageState(); }

class _DashboardPageState extends State<DashboardPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###","id_ID");
  DateTime nowLive = DateTime.now();
  Timer? timer;
  final penjualanC = TextEditingController(text:"0");
  final bebanOpsC = TextEditingController(text:"0");
  final tambahanC = TextEditingController(text:"0");
  final ketTambahanC = TextEditingController();
  DateTime bulan = DateTime.now();
  Map<DateTime, List<AbsensiData>> absenPerTanggal = {};
  List<KaryawanData> allKaryawan = [];

  @override void initState(){ super.initState(); timer=Timer.periodic(const Duration(seconds:1), (_){ if(mounted) setState(()=> nowLive=DateTime.now()); }); _loadBulan(); }
  @override void dispose(){ timer?.cancel(); penjualanC.dispose(); bebanOpsC.dispose(); tambahanC.dispose(); ketTambahanC.dispose(); super.dispose(); }

  Future<void> _loadBulan() async {
    allKaryawan = await db.select(db.karyawan).get();
    final first=DateTime(bulan.year, bulan.month,1);
    final last=DateTime(bulan.year, bulan.month+1,0,23,59,59);
    final allAbsen=await db.select(db.absensi).get();
    final filtered=allAbsen.where((a)=> a.jamMasuk.isAfter(first.subtract(const Duration(seconds:1))) && a.jamMasuk.isBefore(last.add(const Duration(seconds:1)))).toList();
    Map<DateTime, List<AbsensiData>> map={};
    for(var a in filtered){ final d=DateTime(a.jamMasuk.year, a.jamMasuk.month, a.jamMasuk.day); map.putIfAbsent(d, ()=>[]).add(a); }
    if(mounted) setState(()=> absenPerTanggal=map);
  }

  int _parse(String s)=> int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''))??0;

  Widget _bintangWidget(int karyawanId, int bintangSaatIni){
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i){
      final idx=i+1;
      return InkWell(onTap: () async => await db.setBintang(karyawanId, DateTime.now(), idx), child: Icon(idx<=bintangSaatIni? Icons.star : Icons.star_border, size:22, color: Colors.amber.shade700));
    }));
  }

  Widget _liveTab(){
    final today=DateTime.now();
    return StreamBuilder<List<AbsensiData>>(stream: db.watchAbsensiHari(today), builder: (c,absSnap){
      final absHariIni=absSnap.data?? [];
      return StreamBuilder<List<KaryawanData>>(stream: db.watchKaryawan(), builder: (c,karSnap){
        final allKar=karSnap.data?? [];
        final idsMasuk=absHariIni.map((e)=>e.karyawanId).toSet();
        final bolong=allKar.where((k)=>!idsMasuk.contains(k.id)).toList();
        final full=absHariIni.where((a)=>a.tipeKerja=='FULL').toList();
        final setengah=absHariIni.where((a)=>a.tipeKerja=='SETENGAH').toList();
        return StreamBuilder<List<BintangHarianData>>(stream: db.watchBintangHari(today), builder: (c,bintangSnap){
          final bintangList=bintangSnap.data?? []; Map<int,int> bintangMap={for(var b in bintangList) b.karyawanId: b.bintang};
          return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.brown.shade800, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(DateFormat('EEEE, dd MMMM yyyy','id_ID').format(nowLive), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize:15)), Text("${DateFormat('HH:mm:ss').format(nowLive)} WIB - LIVE CONTINUE", style: const TextStyle(color: Colors.white70))])),
            const SizedBox(height:12),
            Card(elevation:3, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("KEHADIRAN HARI INI ${DateFormat('dd MMM').format(today)} - ${absHariIni.length}/${allKar.length} MASUK", style: const TextStyle(fontWeight: FontWeight.bold)), const Divider(),
              if(full.isNotEmpty)...[const Text("✅ FULL 1 HARI:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),...full.map((a){ final kar=allKar.where((k)=>k.id==a.karyawanId).firstOrNull; return ListTile(dense:true, title: Text("ID:${a.karyawanId} ${kar?.nama??''}"), subtitle: Text(a.keterangan), trailing: PopupMenuButton<String>(onSelected: (v) async => await db.updateTipeAbsen(a.id, v), itemBuilder: (_)=>[const PopupMenuItem(value:'SETENGAH', child: Text("Ubah jadi ½ Hari")), const PopupMenuItem(value:'FULL', child: Text("Tetap Full"))], child: const Icon(Icons.more_vert))); })],
              if(setengah.isNotEmpty)...[const Text("🟡 ½ HARI:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),...setengah.map((a){ final kar=allKar.where((k)=>k.id==a.karyawanId).firstOrNull; return ListTile(dense:true, title: Text("ID:${a.karyawanId} ${kar?.nama??''} - ${a.keterangan}"), trailing: PopupMenuButton<String>(onSelected: (v) async => await db.updateTipeAbsen(a.id, v), itemBuilder: (_)=>[const PopupMenuItem(value:'FULL', child: Text("Ubah jadi FULL")), const PopupMenuItem(value:'SETENGAH', child: Text("Tetap ½"))], child: const Icon(Icons.more_vert))); })],
              if(bolong.isNotEmpty)...[const Text("❌ BOLONG - GAK GAJIAN:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),...bolong.map((k)=> ListTile(dense:true, title: Text("ID:${k.id} ${k.nama}"), subtitle: const Text("Belum absen hari ini")))],
            ]))),
            const SizedBox(height:12),
            Card(color: Colors.amber.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("⭐ BINTANG PRO-AKTIF HARI INI", style: TextStyle(fontWeight: FontWeight.bold)), const Divider(),...allKar.map((k){ final b=bintangMap[k.id]??0; return ListTile(dense:true, title: Text("ID:${k.id} ${k.nama}"), trailing: _bintangWidget(k.id, b), subtitle: Text(b==0?"Belum dinilai":"$b bintang")); })]))),
            const SizedBox(height:12),
            StreamBuilder<LaporanHarianData?>(stream: db.watchLaporanHari(today), builder: (c,lapSnap){
              final lap=lapSnap.data;
              if(lap!=null && penjualanC.text=="0"){ penjualanC.text=lap.totalPenjualan.toString(); bebanOpsC.text=lap.bebanOperasional.toString(); tambahanC.text=lap.tambahanLain.toString(); ketTambahanC.text=lap.keteranganTambahan; }
              return Card(color: Colors.blue.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("INPUT MANUAL HARI INI", style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: penjualanC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText:"Total Penjualan", prefixText:"Rp "), onChanged: (_)=> setState((){})),
                TextField(controller: bebanOpsC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText:"Beban Operasional", prefixText:"Rp "), onChanged: (_)=> setState((){})),
                TextField(controller: tambahanC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText:"Tambahan Lain", prefixText:"Rp "), onChanged: (_)=> setState((){})),
                TextField(controller: ketTambahanC, decoration: const InputDecoration(labelText:"Keterangan Tambahan")),
                const SizedBox(height:8),
                FutureBuilder<int>(future: db.hitungGajiHariIni(today), builder: (c,gajiSnap){
                  final gajiHari=gajiSnap.data??0; final penjualan=_parse(penjualanC.text); final bebanOps=_parse(bebanOpsC.text); final tambahan=_parse(tambahanC.text);
                  final totalMasuk=penjualan+tambahan; final totalBeban=bebanOps+gajiHari; final kotor=penjualan-bebanOps; final bersih=totalMasuk-totalBeban;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: double.infinity, padding: const EdgeInsets.all(12), color: Colors.white, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("ESTIMASI LABA HARI INI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown.shade800)), Text("Gaji Hari Ini: Rp ${fmt.format(gajiHari)}"), Text("Laba Kotor: Rp ${fmt.format(kotor)}"), Text("Laba Bersih: Rp ${fmt.format(bersih)}", style: TextStyle(fontWeight: FontWeight.bold, color: bersih>=0?Colors.green:Colors.red))])),
                    const SizedBox(height:8),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.save), label: const Text("SIMPAN LOG LIVE HARI INI"), style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade800, foregroundColor: Colors.white), onPressed: () async { await db.simpanLaporanHarian(today, penjualan, bebanOps, tambahan, ketTambahanC.text, gajiHari, kotor, bersih); if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Log Live Disimpan"))); _loadBulan(); })),
                  ]);
                }),
              ])));
            }),
          ]));
        });
      });
    });
  }

  void _klikTanggal(DateTime tgl) async {
    final absen=absenPerTanggal[DateTime(tgl.year, tgl.month, tgl.day)]?? [];
    final laporan=await (db.select(db.laporanHarian)..where((t)=> t.tanggal.equals(DateTime(tgl.year, tgl.month, tgl.day)))).getSingleOrNull();
    final bintang=await (db.select(db.bintangHarian)..where((t)=> t.tanggal.equals(DateTime(tgl.year, tgl.month, tgl.day)))).get();
    final idsMasuk=absen.map((e)=>e.karyawanId).toSet();
    final bolong=allKaryawan.where((k)=>!idsMasuk.contains(k.id)).toList();
    if(!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled:true, builder: (_)=> Container(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text("LOG ${DateFormat('dd MMM yyyy').format(tgl)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize:16)), const Divider(),
      Text("Kehadiran: ${absen.length}/${allKaryawan.length} masuk | ${bolong.length} bolong"),
      if(bolong.isNotEmpty) Text("❌ Bolong: ${bolong.map((k)=>k.nama).join(', ')}"),
      const SizedBox(height:8),
      Text("BINTANG: ${bintang.isEmpty?"Belum ada": bintang.map((b){ final kar=allKaryawan.where((k)=>k.id==b.karyawanId).firstOrNull; return "${kar?.nama?? b.karyawanId}: ${b.bintang}⭐"; }).join(', ')}"),
      const Divider(),
      if(laporan!=null)...[
        Text("Penjualan: Rp ${fmt.format(laporan.totalPenjualan)}"),
        Text("Beban Ops: Rp ${fmt.format(laporan.bebanOperasional)}"),
        Text("Tambahan: Rp ${fmt.format(laporan.tambahanLain)} - ${laporan.keteranganTambahan}"),
        Text("Gaji Hari: Rp ${fmt.format(laporan.totalGajiHariIni)}", style: const TextStyle(fontWeight: FontWeight.bold)),
        Text("Laba Bersih: Rp ${fmt.format(laporan.labaBersih)}", style: TextStyle(fontWeight: FontWeight.bold, color: laporan.labaBersih>=0?Colors.green:Colors.red)),
      ] else const Text("Belum ada laporan penjualan hari itu"),
    ]))));
  }

  Widget _kalenderTab(){
    final firstDay=DateTime(bulan.year, bulan.month,1);
    final daysInMonth=DateTime(bulan.year, bulan.month+1,0).day;
    final startWeekday=firstDay.weekday%7;
    return Column(children: [
      Container(padding: const EdgeInsets.all(8), color: Colors.brown.shade50, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: (){ setState(()=> bulan=DateTime(bulan.year, bulan.month-1,1)); _loadBulan(); }),
        Text(DateFormat('MMMM yyyy','id_ID').format(bulan), style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: (){ setState(()=> bulan=DateTime(bulan.year, bulan.month+1,1)); _loadBulan(); }),
      ])),
      Expanded(child: GridView.builder(padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7, childAspectRatio:0.9), itemCount: startWeekday+daysInMonth, itemBuilder: (_,i){
        if(i<startWeekday) return const SizedBox();
        final day=i-startWeekday+1;
        final tgl=DateTime(bulan.year, bulan.month, day);
        final list=absenPerTanggal[DateTime(tgl.year, tgl.month, tgl.day)]?? [];
        final warna=list.isEmpty? Colors.red.shade200 : list.length>=allKaryawan.length? Colors.green.shade200 : Colors.yellow.shade200;
        return GestureDetector(onTap: ()=> _klikTanggal(tgl), child: Container(margin: const EdgeInsets.all(3), decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(8)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("$day", style: const TextStyle(fontWeight: FontWeight.bold, fontSize:13)), Text("${list.length}/${allKaryawan.length}", style: const TextStyle(fontSize:9))])));
      })),
    ]);
  }

  Widget _logTab(){
    return StreamBuilder<List<LaporanHarianData>>(
      stream: (db.select(db.laporanHarian)..orderBy([(t)=> OrderingTerm.desc(t.tanggal)])).watch(),
      builder: (c,snap){
        if(!snap.hasData) return const Center(child: CircularProgressIndicator());
        if(snap.data!.isEmpty) return const Center(child: Text("Belum ada Log Live"));
        return ListView.builder(itemCount: snap.data!.length, itemBuilder: (_,i){ final l=snap.data![i]; return Card(child: ListTile(title: Text(DateFormat('dd MMM yyyy').format(l.tanggal)), subtitle: Text("Jual Rp ${fmt.format(l.totalPenjualan)} | Bersih Rp ${fmt.format(l.labaBersih)}"), trailing: Text("Gaji ${fmt.format(l.totalGajiHariIni)}"))); });
      },
    );
  }

  @override Widget build(BuildContext context){
    return DefaultTabController(length:3, child: Column(children: [
      Container(color: Colors.brown.shade800, child: const TabBar(indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70, tabs: [Tab(text:"Live"), Tab(text:"Log"), Tab(text:"Absensi")])),
      Expanded(child: TabBarView(children: [_liveTab(), _logTab(), _kalenderTab()])),
    ]));
  }
}