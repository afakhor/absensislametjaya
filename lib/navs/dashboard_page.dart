import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../dbases/localdatabase.dart';
import '../dbases/gaji_db.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###","id_ID");

  // FILTER LOG
  int? filterKaryawanId; int? filterKategoriId;
  String filterWaktu = 'CONTINUE';
  DateTime? filterMulai; DateTime? filterSelesai;
  int totalAkumulasi = 0; int totalBelum = 0; int totalKuning = 0; int totalHijau = 0;
  List<GajiMingguanData> logList = [];

  // KALENDER
  DateTime bulan = DateTime.now();
  Map<DateTime, List<AbsensiData>> absenPerTanggal = {};
  List<KaryawanData> allKaryawan = [];

  @override void initState(){ super.initState(); _hitungLog(); _loadBulan(); }

  Future<void> _hitungLog() async {
    DateTime? m; DateTime? s; final now = DateTime.now();
    if(filterWaktu=='MINGGU'){ m = now.subtract(Duration(days: now.weekday-1)); s = now; }
    else if(filterWaktu=='2MINGGU'){ m = now.subtract(const Duration(days:14)); s = now; }
    else if(filterWaktu=='BULAN'){ m = DateTime(now.year, now.month, 1); s = now; }
    else if(filterWaktu=='RANGE'){ m = filterMulai; s = filterSelesai; }
    else if(filterWaktu=='TANGGAL_TERTENTU'){ m = filterMulai; s = filterMulai!=null? DateTime(filterMulai!.year, filterMulai!.month, filterMulai!.day,23,59,59) : null; }
    else { m = null; s = now; }

    totalAkumulasi = await db.getAkumulasiBebanGaji(karyawanId: filterKaryawanId, kategoriId: filterKategoriId, mulai: m, selesai: s);

    var q = db.select(db.gajiMingguan);
    if(filterKaryawanId!=null) q.where((t)=>t.karyawanId.equals(filterKaryawanId!));
    if(m!=null) q.where((t)=>t.mingguMulai.isBiggerOrEqualValue(m!));
    if(s!=null) q.where((t)=>t.mingguSelesai.isSmallerOrEqualValue(s!));
    var list = await q.get();
    if(filterKategoriId!=null){
      final ids = (await (db.select(db.karyawan)..where((k)=>k.kategoriId.equals(filterKategoriId!))).get()).map((e)=>e.id).toSet();
      list = list.where((g)=>ids.contains(g.karyawanId)).toList();
    }
    logList = list..sort((a,b)=>b.mingguMulai.compareTo(a.mingguMulai));

    final allGaji = await db.select(db.gajiMingguan).get();
    totalBelum = allGaji.where((e)=>e.statusBayar=='BELUM').length;
    totalKuning = allGaji.where((e)=>e.statusBayar=='MINGGU1').length;
    totalHijau = allGaji.where((e)=>e.statusBayar=='MINGGU2').length;
    setState((){});
  }

  Future<void> _loadBulan() async {
    allKaryawan = await db.select(db.karyawan).get();
    final first = DateTime(bulan.year, bulan.month, 1);
    final last = DateTime(bulan.year, bulan.month+1, 0, 23,59,59);
    final allAbsen = await (db.select(db.absensi)..where((t)=> t.jamMasuk.isBetweenValues(first, last))).get();
    Map<DateTime, List<AbsensiData>> map = {};
    for(var a in allAbsen){
      final d = DateTime(a.jamMasuk.year, a.jamMasuk.month, a.jamMasuk.day);
      map.putIfAbsent(d, ()=>[]).add(a);
    }
    setState(()=>absenPerTanggal=map);
  }

  Color _warnaTanggal(DateTime tgl){
    if(allKaryawan.isEmpty) return Colors.grey.shade200;
    final list = absenPerTanggal[DateTime(tgl.year,tgl.month,tgl.day)]?? [];
    if(list.isEmpty) return Colors.red.shade200;
    if(list.length >= allKaryawan.length && list.every((e)=>e.tipeKerja=='FULL')) return Colors.green.shade200;
    return Colors.yellow.shade200;
  }

  void _klikTanggal(DateTime tgl){
    final tglKey = DateTime(tgl.year, tgl.month, tgl.day);
    final list = absenPerTanggal[tglKey]?? [];
    final idsMasuk = list.map((e)=>e.karyawanId).toSet();
    final bolong = allKaryawan.where((k)=>!idsMasuk.contains(k.id)).toList();
    final setengah = list.where((a)=>a.tipeKerja=='SETENGAH').toList();
    if(_warnaTanggal(tgl)==Colors.green.shade200) return;
    showModalBottomSheet(context: context, builder: (_)=>Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Tgl ${DateFormat('dd MMM yyyy').format(tgl)} - ${list.isEmpty?'Merah: Semua gak masuk':'Kuning: Ada bolong / ½ hari'}", style: const TextStyle(fontWeight: FontWeight.bold)),
      const Divider(),
      if(bolong.isNotEmpty)...[const Text("❌ GAK MASUK:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),...bolong.map((k)=>Text(" - ID:${k.id} ${k.nama}")), const SizedBox(height: 8)],
      if(setengah.isNotEmpty)...[const Text("🟡 ½ HARI:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),...setengah.map((a){ final kar = allKaryawan.where((k)=>k.id==a.karyawanId).firstOrNull; return Text(" - ID:${a.karyawanId} ${kar?.nama??''} - ${a.keterangan}"); })],
    ])));
  }

  // WIDGET FILTER - dipakai Live & Log
  Widget _filterWidget(){
    return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
      StreamBuilder<List<KaryawanData>>(stream: db.watchKaryawan(), builder: (c,s){
        return DropdownButton<int?>(isExpanded: true, value: filterKaryawanId, hint: const Text("Per ID Karyawan"), items: [const DropdownMenuItem(value: null, child: Text("Semua Karyawan")),...(s.data??[]).map((e)=>DropdownMenuItem(value: e.id, child: Text("ID:${e.id}-${e.nama}")))], onChanged: (v){ setState(()=>filterKaryawanId=v); _hitungLog(); });
      }),
      StreamBuilder<List<KategoriKaryawanData>>(stream: db.watchKategori(), builder: (c,s){
        return DropdownButton<int?>(isExpanded: true, value: filterKategoriId, hint: const Text("Per Kategori"), items: [const DropdownMenuItem(value: null, child: Text("Semua Kategori")),...(s.data??[]).map((e)=>DropdownMenuItem(value: e.id, child: Text(e.namaKategori)))], onChanged: (v){ setState(()=>filterKategoriId=v); _hitungLog(); });
      }),
      DropdownButton<String>(isExpanded: true, value: filterWaktu, items: const [
        DropdownMenuItem(value: 'CONTINUE', child: Text("Awal - Continue (Hari Ini)")),
        DropdownMenuItem(value: 'TANGGAL_TERTENTU', child: Text("Tanggal Tertentu")),
        DropdownMenuItem(value: 'RANGE', child: Text("Range Tanggal")),
        DropdownMenuItem(value: 'MINGGU', child: Text("Per Minggu")),
        DropdownMenuItem(value: '2MINGGU', child: Text("Per 2 Minggu")),
        DropdownMenuItem(value: 'BULAN', child: Text("Per Bulan")),
      ], onChanged: (v) async {
        setState(()=>filterWaktu=v!);
        if(v=='RANGE'){ final p=await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now(), initialDateRange: filterMulai!=null&&filterSelesai!=null?DateTimeRange(start: filterMulai!, end: filterSelesai!):null); if(p!=null){ filterMulai=p.start; filterSelesai=p.end; } }
        if(v=='TANGGAL_TERTENTU'){ final p=await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now()); if(p!=null) filterMulai=p; }
        _hitungLog();
      }),
    ])));
  }

  Widget _liveTab(){
    final today = DateTime.now();
    return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
      _filterWidget(),
      const SizedBox(height: 12),
      StreamBuilder<List<KaryawanData>>(stream: db.watchKaryawan(), builder: (c,sKaryawan){
        final totalKar = sKaryawan.data?.length?? 0;
        return StreamBuilder<List<AbsensiData>>(stream: db.watchAbsensiHari(today), builder: (c,sAbsen){
          final masuk = sAbsen.data?.length?? 0; final bolong = totalKar - masuk;
          return Card(color: bolong==0?Colors.green.shade50:bolong==totalKar?Colors.red.shade50:Colors.yellow.shade50, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Icon(bolong==0?Icons.check_circle:bolong==totalKar?Icons.cancel:Icons.warning, color: bolong==0?Colors.green:bolong==totalKar?Colors.red:Colors.orange, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("LIVE HARI INI ${DateFormat('dd MMM yyyy').format(today)} - CONTINUE", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("$masuk / $totalKar masuk | $bolong bolong", style: const TextStyle(fontSize: 13)),
              Text(bolong==0?"✅ Hijau":bolong==totalKar?"❌ Merah":"⚠️ Kuning - Ada bolong/½ hari", style: const TextStyle(fontSize: 11)),
            ])),
          ])));
        });
      }),
      const SizedBox(height: 12),
      Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.brown.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.brown.shade200)), child: Column(children: [
        const Text("TOTAL AKUMULASI BEBAN GAJI DARI AWAL - CONTINUE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text("Rp ${fmt.format(totalAkumulasi)}", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.brown.shade800)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Column(children: [Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)), Text("Belum\n$totalBelum", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))]),
          Column(children: [Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)), Text("1 Minggu\n$totalKuning", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))]),
          Column(children: [Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)), Text("2 Minggu\n$totalHijau", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))]),
        ]),
      ])),
    ]));
  }

  Widget _logTab(){
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: _filterWidget()),
      Container(width: double.infinity, color: Colors.brown.shade50, padding: const EdgeInsets.all(12), child: Column(children: [
        const Text("TOTAL AKUMULASI SESUAI FILTER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        Text("Rp ${fmt.format(totalAkumulasi)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown.shade800)),
        Text("${logList.length} transaksi | ${logList.fold(0.0, (p,e)=>p+e.totalHariEfektif)} hari efektif", style: const TextStyle(fontSize: 10)),
      ])),
      Expanded(child: logList.isEmpty? const Center(child: Text("Tidak ada data sesuai filter")) : ListView.builder(itemCount: logList.length, itemBuilder: (_,i){
        var g=logList[i];
        return FutureBuilder<KaryawanData?>(future: (db.select(db.karyawan)..where((t)=>t.id.equals(g.karyawanId))).getSingleOrNull(), builder: (c,kar){
          return Card(color: g.statusBayar=='BELUM'?Colors.red.shade50:g.statusBayar=='MINGGU1'?Colors.yellow.shade50:Colors.green.shade50, child: ListTile(
            leading: Icon(Icons.circle, color: g.statusBayar=='BELUM'?Colors.red:g.statusBayar=='MINGGU1'?Colors.orange:Colors.green, size: 14),
            title: Text("${kar.data?.nama??'ID ${g.karyawanId}'} - ${DateFormat('dd MMM').format(g.mingguMulai)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text("${g.totalHariEfektif} hari | Pokok Rp ${fmt.format(g.totalGajiPokok)} + Bonus Rp ${fmt.format(g.bonusMingguan)} = Rp ${fmt.format(g.totalGaji)} | ${g.statusBayar}", style: const TextStyle(fontSize: 11)),
          ));
        });
      })),
    ]);
  }

  Widget _kalenderTab(){
    final firstDay = DateTime(bulan.year, bulan.month, 1);
    final daysInMonth = DateTime(bulan.year, bulan.month+1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    return Column(children: [
      Container(padding: const EdgeInsets.all(8), color: Colors.brown.shade50, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: (){ setState(()=>bulan=DateTime(bulan.year, bulan.month-1,1)); _loadBulan(); }),
        Text(DateFormat('MMMM yyyy').format(bulan), style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: (){ setState(()=>bulan=DateTime(bulan.year, bulan.month+1,1)); _loadBulan(); }),
      ])),
      Container(padding: const EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Row(children: [Container(width:12,height:12,color: Colors.green.shade200), const SizedBox(width:4), const Text("Masuk", style: TextStyle(fontSize:11))]),
        Row(children: [Container(width:12,height:12,color: Colors.yellow.shade200), const SizedBox(width:4), const Text("Bolong/½", style: TextStyle(fontSize:11))]),
        Row(children: [Container(width:12,height:12,color: Colors.red.shade200), const SizedBox(width:4), const Text("Gak Masuk", style: TextStyle(fontSize:11))]),
      ])),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Text("Min",style: TextStyle(fontSize:11)),Text("Sen",style: TextStyle(fontSize:11)),Text("Sel",style: TextStyle(fontSize:11)),Text("Rab",style: TextStyle(fontSize:11)),Text("Kam",style: TextStyle(fontSize:11)),Text("Jum",style: TextStyle(fontSize:11)),Text("Sab",style: TextStyle(fontSize:11))]),),
      Expanded(child: GridView.builder(padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.9), itemCount: startWeekday + daysInMonth, itemBuilder: (_,i){
        if(i < startWeekday) return const SizedBox();
        final day = i - startWeekday + 1;
        final tgl = DateTime(bulan.year, bulan.month, day);
        final warna = _warnaTanggal(tgl);
        final list = absenPerTanggal[DateTime(tgl.year,tgl.month,tgl.day)]?? [];
        return GestureDetector(onTap: ()=>_klikTanggal(tgl), child: Container(margin: const EdgeInsets.all(3), decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.brown.shade100)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("$day", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text("${list.length}/${allKaryawan.length}", style: const TextStyle(fontSize: 9)),
          if(list.any((e)=>e.tipeKerja=='SETENGAH')) const Text("½", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
        ])));
      })),
    ]);
  }

  @override Widget build(BuildContext context){
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("DASHBOARD - TB SLAMET JAYA"),
          backgroundColor: Colors.brown.shade800,
          foregroundColor: Colors.white,
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.live_tv), text: "Live"),
            Tab(icon: Icon(Icons.receipt_long), text: "Log"),
            Tab(icon: Icon(Icons.calendar_month), text: "Absensi"),
          ]),
        ),
        body: TabBarView(children: [_liveTab(), _logTab(), _kalenderTab()]),
      ),
    );
  }
}