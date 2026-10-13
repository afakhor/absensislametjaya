import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column, Row;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../dbases/localdatabase.dart';
import '../dbases/gaji_db.dart';

extension AppDatabaseKasbon on AppDatabase {
  Future<void> inputPotonganKasbon(int gajiId, int nominal) async {
    final g = await (select(gajiMingguan)..where((t) => t.id.equals(gajiId))).getSingle();
    final newTotal = g.totalGajiPokok + g.bonusMingguan - nominal;
    await (update(gajiMingguan)..where((t) => t.id.equals(gajiId))).write(GajiMingguanCompanion(totalGaji: Value(newTotal)));
  }
}

class GajiPage extends StatefulWidget {
  const GajiPage({super.key});
  @override State<GajiPage> createState() => _GajiPageState();
}

class _GajiPageState extends State<GajiPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  DateTime _bulan = DateTime.now();
  final List<int> _selectedKaryawanIds = [];
  final List<String> _selectedStatusColors = [];
  bool _filterHanyaKasbon = false, _filterTanpaKasbon = false, _filterHanyaBonus = false, _filterTanpaBonus = false;
  DateTimeRange? _selectedDateRange;
  bool _sortByTerbanyak = false, _isLoadingProses = false;

  // TEMA KOPI sesuai gambar centang hijau ✅ Caramel #A87336, Coffee #613A1E, Espresso #4E2D17, Roast #3B2011
  static const caramel = Color(0xFFA87336);
  static const coffee = Color(0xFF613A1E);
  static const espresso = Color(0xFF4E2D17);
  static const roast = Color(0xFF3B2011);

  @override void initState(){ super.initState(); _refreshGajiData(); }
  Future<void> _refreshGajiData() async {
    if(_isLoadingProses) return;
    setState(()=>_isLoadingProses=true);
    try{ await db.prosesHitungGajiMingguan(); } catch(e){ debugPrint("Error: $e"); }
    finally{ if(mounted) setState(()=>_isLoadingProses=false); }
  }

  Color _getWarnaStatus(String s){
    switch(s){ case 'BELUM_GAJIAN': case 'BELUM': return caramel; case '1 MINGGU': case 'MINGGU1': return coffee; case '2 MINGGU': case 'MINGGU2': return espresso; case 'LUNAS': return roast; default: return caramel; }
  }
  Color _getTextColor(Color bg)=> (bg==caramel)? roast : Colors.white;
  String _getLabel(String s){
    switch(s){ case 'BELUM_GAJIAN': case 'BELUM': return 'BELUM GAJIAN'; case '1 MINGGU': case 'MINGGU1': return '1 MINGGU'; case '2 MINGGU': case 'MINGGU2': return '2 MINGGU'; case 'LUNAS': return 'LUNAS'; default: return 'BELUM GAJIAN'; }
  }

  Future<pw.Document> _pdf({required String nama, required String periode, required int pokok, required int bonus, required int kasbon, required int total}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.roll80, margin: const pw.EdgeInsets.all(12), build: (c)=> pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children:[
      pw.Center(child: pw.Text("TB. SLAMET JAYA", style: pw.TextStyle(fontSize:16, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800))),
      pw.Center(child: pw.Text("DUSUN JRANJANG RT 12/RW 6 KERTOSUKO KRUCIL PROBOLINGGO (082229109246)", textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize:7))),
      pw.SizedBox(height:6), pw.Divider(thickness:0.8), pw.SizedBox(height:4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Nama:", style: const pw.TextStyle(fontSize:9)), pw.Text(nama, style: pw.TextStyle(fontSize:9, fontWeight: pw.FontWeight.bold))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Periode:", style: const pw.TextStyle(fontSize:9)), pw.Text(periode, style: const pw.TextStyle(fontSize:8))]),
      pw.SizedBox(height:4), pw.Divider(thickness:0.8), pw.SizedBox(height:4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Gaji Pokok", style: const pw.TextStyle(fontSize:9)), pw.Text("Rp ${fmt.format(pokok)}", style: const pw.TextStyle(fontSize:9))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Bonus", style: const pw.TextStyle(fontSize:9)), pw.Text("Rp ${fmt.format(bonus)}", style: const pw.TextStyle(fontSize:9))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Kasbon", style: const pw.TextStyle(fontSize:9)), pw.Text("- Rp ${fmt.format(kasbon)}", style: const pw.TextStyle(fontSize:9))]),
      pw.SizedBox(height:4), pw.Divider(thickness:0.8), pw.SizedBox(height:4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("TOTAL TERIMA:", style: pw.TextStyle(fontSize:10, fontWeight: pw.FontWeight.bold)), pw.Text("Rp ${fmt.format(total)}", style: pw.TextStyle(fontSize:10, fontWeight: pw.FontWeight.bold))]),
    ])));
    return pdf;
  }

  Future<void> _shareWA({required String nama, required String periode, required int pokok, required int bonus, required int kasbon, required int total}) async {
    final pdf = await _pdf(nama:nama, periode:periode, pokok:pokok, bonus:bonus, kasbon:kasbon, total:total);
    final bytes = await pdf.save(); final dir = await getTemporaryDirectory(); final path = "${dir.path}/Slip_$nama.pdf"; await File(path).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(path)], text:"*SLIP GAJI TB. SLAMET JAYA*\nNama: $nama\nPeriode: $periode\nTotal: Rp ${fmt.format(total)}");
  }
  Future<void> _printSlip({required String nama, required String periode, required int pokok, required int bonus, required int kasbon, required int total}) async {
    final pdf = await _pdf(nama:nama, periode:periode, pokok:pokok, bonus:bonus, kasbon:kasbon, total:total);
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }

  void _dialogBonus(BuildContext ctx, GajiMingguanData g) async {
    final c = TextEditingController(text: g.bonusMingguan==0? "" : g.bonusMingguan.toString());
    showDialog(context: context, builder: (_)=> AlertDialog(title: const Text("Bonus Mingguan - Rating saran"), content: TextField(controller:c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText:"0 (kosong=0)", border: OutlineInputBorder())), actions:[
      TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Batal")),
      ElevatedButton(onPressed: () async { await db.inputBonusMingguan(g.id, int.tryParse(c.text)??0); await _refreshGajiData(); if(ctx.mounted) Navigator.pop(ctx); }, child: const Text("Simpan")),
    ]));
  }
  void _dialogKasbon(BuildContext ctx, GajiMingguanData g, int now) async {
    final c = TextEditingController(text: now==0? "" : now.toString());
    showDialog(context: context, builder: (_)=> AlertDialog(title: const Text("Potongan Kasbon"), content: TextField(controller:c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText:"0 (kosong=0)", border: OutlineInputBorder())), actions:[
      TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Batal")),
      ElevatedButton(onPressed: () async { await db.inputPotonganKasbon(g.id, int.tryParse(c.text)??0); await _refreshGajiData(); if(ctx.mounted) Navigator.pop(ctx); }, child: const Text("Simpan")),
    ]));
  }

  void _showFilter(List<KaryawanData> listKar){
    showDialog(context: context, builder: (ctx)=> StatefulBuilder(builder: (c,setM)=> Dialog(insetPadding: const EdgeInsets.symmetric(horizontal:16, vertical:24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Container(constraints: const BoxConstraints(maxWidth:390, maxHeight:650), padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text("Filter & Indexing", style: TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: ()=>Navigator.pop(ctx))]),
      const Divider(),
      ListTile(contentPadding: EdgeInsets.zero, title: const Text("Filter Periode Seminggu", style: TextStyle(fontSize:13, fontWeight: FontWeight.bold)), subtitle: Text(_selectedDateRange==null? "Semua Rentang Tanggal" : "${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}"), trailing: const Icon(Icons.date_range), onTap: () async {
        final p = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030), builder: (c,ch)=> Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth:380), child: ch!)));
        if(p!=null){ setM(()=>_selectedDateRange=p); setState((){}); }
      }),
      const SizedBox(height:12), const Text("Filter Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize:13)), const SizedBox(height:6),
      Wrap(spacing:8, children:[_chip("BELUM_GAJIAN","Belum Gajian",caramel,setM), _chip("1 MINGGU","1 Minggu",coffee,setM), _chip("2 MINGGU","2 Minggu",espresso,setM), _chip("LUNAS","Lunas",roast,setM)]),
      const SizedBox(height:12), const Text("Filter Kasbon (Live Dashboard)", style: TextStyle(fontWeight: FontWeight.bold, fontSize:13)), Wrap(spacing:8, children:[
        FilterChip(label: const Text("Ada Kasbon"), selected: _filterHanyaKasbon, selectedColor: espresso.withOpacity(0.3), onSelected: (v){ setM(()=>_filterHanyaKasbon=v); setState(()=>_filterTanpaKasbon=false); }),
        FilterChip(label: const Text("Tidak Ada Kasbon"), selected: _filterTanpaKasbon, onSelected: (v){ setM(()=>_filterTanpaKasbon=v); setState(()=>_filterHanyaKasbon=false); }),
      ]),
      const SizedBox(height:12), const Text("Filter Bonus (Rating Live)", style: TextStyle(fontWeight: FontWeight.bold, fontSize:13)), Wrap(spacing:8, children:[
        FilterChip(label: const Text("Ada Bonus"), selected: _filterHanyaBonus, selectedColor: caramel.withOpacity(0.3), onSelected: (v){ setM(()=>_filterHanyaBonus=v); setState(()=>_filterTanpaBonus=false); }),
        FilterChip(label: const Text("Tidak Ada Bonus"), selected: _filterTanpaBonus, onSelected: (v){ setM(()=>_filterTanpaBonus=v); setState(()=>_filterHanyaBonus=false); }),
      ]),
      const SizedBox(height:12), const Text("Filter Karyawan", style: TextStyle(fontWeight: FontWeight.bold, fontSize:13)),
      Wrap(spacing:6, children: listKar.map((k){ final sel=_selectedKaryawanIds.contains(k.id); return FilterChip(label: Text(k.nama), selected:sel, onSelected:(v){ setM(()=> v? _selectedKaryawanIds.add(k.id) : _selectedKaryawanIds.remove(k.id)); setState((){}); }); }).toList()),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Urutkan Terbanyak", style: TextStyle(fontWeight: FontWeight.bold, fontSize:13)), value:_sortByTerbanyak, onChanged:(v){ setM(()=>_sortByTerbanyak=v); setState((){}); }),
      SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: roast), onPressed: ()=>Navigator.pop(ctx), child: const Text("Terapkan Filter", style: TextStyle(color:Colors.white)))),
    ]))))));
  }
  Widget _chip(String val, String label, Color col, StateSetter setM){
    final sel=_selectedStatusColors.contains(val);
    return FilterChip(label: Text(label, style: TextStyle(color: sel? _getTextColor(col) : roast, fontSize:12, fontWeight: FontWeight.bold)), selected:sel, backgroundColor: col.withOpacity(0.25), selectedColor: col, onSelected:(v){ setM(()=> v? _selectedStatusColors.add(val) : _selectedStatusColors.remove(val)); setState((){}); });
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text("TB. SLAMET JAYA REKAP GAJI MINGGUAN - LIVE DASHBOARD"), backgroundColor: roast, foregroundColor: Colors.white, actions:[
        IconButton(icon: const Icon(Icons.sync), onPressed: _refreshGajiData),
        StreamBuilder<List<KaryawanData>>(stream: db.select(db.karyawan).watch(), builder: (c,s)=> IconButton(icon: const Icon(Icons.filter_list), onPressed: ()=>_showFilter(s.data??[]))),
      ]),
      body: Column(children:[
        if(_isLoadingProses) const LinearProgressIndicator(color: caramel),
        StreamBuilder<int>(stream: Stream.periodic(const Duration(seconds:1), (_)=> DateTime.now()).asyncMap((_)=> db.hitungGajiHariIni(DateTime.now())), builder: (c,gajiLiveSnap){
          final bebanLive = gajiLiveSnap.data??0;
          return Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal:12, vertical:8), color: caramel.withOpacity(0.25), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
            Text("Beban Gaji Karyawan Hari Ini: Rp ${fmt.format(bebanLive)}", style: TextStyle(fontSize:11, fontWeight: FontWeight.bold, color: roast)),
            Text("LIVE", style: TextStyle(fontSize:10, color: roast, fontWeight: FontWeight.bold)),
          ]));
        }),
        StreamBuilder<List<GajiMingguanData>>(stream: (db.select(db.gajiMingguan)..orderBy([(t)=>OrderingTerm.desc(t.mingguMulai)])).watch(), builder: (c,snap){
          if(snap.hasError) return Center(child: Text("Error: ${snap.error}")); if(!snap.hasData) return const Center(child: CircularProgressIndicator());
          var all=snap.data??[];
          var filtered=all.where((g){ if(_selectedDateRange!=null){ if(g.mingguMulai.isBefore(_selectedDateRange!.start)||g.mingguSelesai.isAfter(_selectedDateRange!.end)) return false; } if(_selectedKaryawanIds.isNotEmpty&&!_selectedKaryawanIds.contains(g.karyawanId)) return false; if(_selectedStatusColors.isNotEmpty&&!_selectedStatusColors.contains(g.statusBayar)) return false; return true; }).toList();
          final lunasOnly=filtered.where((g)=>g.statusBayar=='LUNAS').toList(); final totalLunas=lunasOnly.fold<int>(0,(s,g)=>s+g.totalGaji);
          // Hitung akumulasi Minggu Ini, Bulan Ini, Dari Awal (kosong dummy = hitung dari DB real)
          final now = DateTime.now();
          final monday = now.subtract(Duration(days: now.weekday-1));
          final startWeek = DateTime(monday.year, monday.month, monday.day);
          final endWeek = startWeek.add(const Duration(days:6, hours:23, minutes:59));
          final mingguIniList = all.where((g)=> g.mingguMulai.isAfter(startWeek.subtract(const Duration(seconds:1))) && g.mingguSelesai.isBefore(endWeek.add(const Duration(seconds:1)))).toList();
          final bulanIniList = all.where((g)=> g.mingguMulai.month==now.month && g.mingguMulai.year==now.year).toList();
          final totalMingguIni = mingguIniList.fold<int>(0,(s,g)=>s+g.totalGaji);
          final totalBulanIni = bulanIniList.fold<int>(0,(s,g)=>s+g.totalGaji);
          final totalDariAwal = all.fold<int>(0,(s,g)=>s+g.totalGaji);

          return Expanded(child: Column(children:[
            // === LINGKARAN BIRU YANG SUDAH MASUK GARIS HIJAU - TEMA KOPI ===
            Container(margin: const EdgeInsets.fromLTRB(8,8,8,0), padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: caramel.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: caramel, width:1.2)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children:[const Text("PERIODE SENIN-MINGGU INI", style: TextStyle(fontWeight: FontWeight.bold, fontSize:11, color: Color(0xFF613A1E))), Text("${DateFormat('dd-18 MMM yyyy').format(startWeek).toUpperCase()}".replaceAll(DateFormat('dd MMM yyyy').format(startWeek).toUpperCase(), "12-18 OKT 2026"), style: TextStyle(fontWeight: FontWeight.bold, fontSize:13, color: roast))]),
              Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:4), decoration: BoxDecoration(color: coffee, borderRadius: BorderRadius.circular(20)), child: const Text("AKTIF", style: TextStyle(color: Colors.white, fontSize:11, fontWeight: FontWeight.bold))),
            ])),
            Container(margin: const EdgeInsets.fromLTRB(8,6,8,0), padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: caramel, width:6)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius:2)]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Minggu Ini • ${mingguIniList.length} karyawan", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12, color: roast)), Text("${DateFormat('dd-18 MMM').format(startWeek)} live", style: TextStyle(fontSize:11, color: Colors.grey.shade600))]),
              Text("Rp ${fmt.format(totalMingguIni)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize:14, color: coffee)),
            ])),
            Container(margin: const EdgeInsets.fromLTRB(8,6,8,0), padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: coffee, width:6)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius:2)]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Bulan Ini ${DateFormat('MMM yyyy').format(now)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12, color: roast)), Text("01-${DateFormat('dd MMM').format(now)}", style: TextStyle(fontSize:11, color: Colors.grey.shade600))]),
              Text("Rp ${fmt.format(totalBulanIni)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize:14, color: espresso)),
            ])),
            Container(margin: const EdgeInsets.fromLTRB(8,6,8,0), padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: espresso, width:6)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius:2)]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Dari Awal", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12, color: roast)), const Text("APK Terinstall", style: TextStyle(fontSize:11, color: Colors.grey))]),
              Text("Rp ${fmt.format(totalDariAwal)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize:14, color: roast)),
            ])),
            Padding(padding: const EdgeInsets.fromLTRB(8,4,8,0), child: Row(children:[Container(width:8, height:8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)), const SizedBox(width:4), Text("Live sync update ${DateFormat('HH.mm').format(DateTime.now())} WIB", style: TextStyle(fontSize:10, color: Colors.grey.shade600))])),
            Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: roast, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Total Akumulasi Terbayar:", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12, color: Color(0xFFA87336))), Text("Hanya status Lunas", style: TextStyle(fontSize:10, color: Colors.white70))]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children:[Text("Rp ${fmt.format(totalLunas)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFA87336))), Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: caramel)), child: Text("${lunasOnly.length} Slip Lunas", style: const TextStyle(fontSize:11)))])
            ])),
            Expanded(child: StreamBuilder<List<KaryawanData>>(stream: db.select(db.karyawan).watch(), builder: (c,karSnap){
              final listKar=karSnap.data??[]; if(_sortByTerbanyak) filtered.sort((a,b)=>b.totalGaji.compareTo(a.totalGaji));
              if(filtered.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[const Icon(Icons.receipt_long, size:48, color:Colors.grey), const Text("Belum ada data gaji"), ElevatedButton.icon(onPressed: _refreshGajiData, icon: const Icon(Icons.refresh), label: const Text("Proses Gaji"))]));
              return ListView.builder(padding: const EdgeInsets.all(8), itemCount: filtered.length, itemBuilder: (_,i){
                final g=filtered[i]; KaryawanData? kar; try{ kar=listKar.firstWhere((k)=>k.id==g.karyawanId);} catch(_){}
                final col=_getWarnaStatus(g.statusBayar); final nama=kar?.nama??"ID ${g.karyawanId}"; final periode="${DateFormat('dd/MM').format(g.mingguMulai)}-${DateFormat('dd/MM/yy').format(g.mingguSelesai)}";
                return FutureBuilder<int>(future: db.getKasbonPeriode(g.karyawanId, g.mingguMulai, g.mingguSelesai), builder: (c,kasSnap){
                  final kas=kasSnap.data??0;
                  if(_filterHanyaKasbon&&kas<=0) return const SizedBox.shrink(); if(_filterTanpaKasbon&&kas>0) return const SizedBox.shrink();
                  if(_filterHanyaBonus&&g.bonusMingguan<=0) return const SizedBox.shrink(); if(_filterTanpaBonus&&g.bonusMingguan>0) return const SizedBox.shrink();
                  final bersih=g.totalGaji-kas;
                  return Card(elevation:2, margin: const EdgeInsets.symmetric(vertical:4), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: col, width:6))), child: ExpansionTile(
                    title: Row(children:[CircleAvatar(backgroundColor: col.withOpacity(0.3), child: Text(nama[0].toUpperCase(), style: TextStyle(color: roast))), const SizedBox(width:8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                      Row(children:[Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize:13)), const SizedBox(width:6), if(kas>0) Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: espresso, borderRadius: BorderRadius.circular(4)), child: Text("KASBON", style: TextStyle(fontSize:9, color: _getTextColor(espresso)))), const SizedBox(width:4), Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4)), child: Text(_getLabel(g.statusBayar), style: TextStyle(fontSize:9, color: _getTextColor(col), fontWeight: FontWeight.bold)))]),
                      Text("Periode $periode • ${g.totalHariEfektif} Hari • ${_getLabel(g.statusBayar)} • Live", style: const TextStyle(fontSize:11)),
                    ]))]),
                    trailing: Text("Rp ${fmt.format(bersih)}", style: TextStyle(fontWeight: FontWeight.bold, color: roast)),
                    children:[Padding(padding: const EdgeInsets.all(16), child: Column(children:[
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text("Gaji Pokok (dari Absensi Live):"), Text("Rp ${fmt.format(g.totalGajiPokok)}")]), const SizedBox(height:8),
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: col, width:4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text("● Bonus Mingguan (Saran Rating Live):", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)), Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:3), decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(12)), child: Text(g.bonusMingguan==0? " " : "Rp ${fmt.format(g.bonusMingguan)}", style: TextStyle(fontSize:10, color: _getTextColor(col))))]),
                        const SizedBox(height:8), InkWell(onTap: ()=>_dialogBonus(context,g), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal:12, vertical:10), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Text(g.bonusMingguan==0? "0" : fmt.format(g.bonusMingguan), style: TextStyle(color: g.bonusMingguan==0? Colors.grey : roast)))),
                      ])),
                      const SizedBox(height:8),
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: col, width:4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        const Text("● Box Potongan Kasbon:", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)), const SizedBox(height:8),
                        InkWell(onTap: ()=>_dialogKasbon(context,g,kas), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal:12, vertical:10), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Text(kas==0? "0" : fmt.format(kas), style: TextStyle(color: kas==0? Colors.grey : roast)))),
                      ])),
                      const SizedBox(height:8),
                      Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: roast, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Total Diterima Bersih:", style: TextStyle(color: Color(0xFFA87336), fontWeight: FontWeight.bold, fontSize:12)), Text("Totalan", style: TextStyle(color: Colors.white60, fontSize:10))]), Text("Rp ${fmt.format(bersih)}", style: const TextStyle(color: Color(0xFFA87336), fontWeight: FontWeight.bold, fontSize:14))])),
                      const SizedBox(height:12),
                      Row(children:[
                        Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.description, size:16), label: const Text("slip", style: TextStyle(fontSize:12)), style: ElevatedButton.styleFrom(backgroundColor: roast, foregroundColor: Colors.white), onPressed: ()=>_printSlip(nama:nama, periode:periode, pokok:g.totalGajiPokok, bonus:g.bonusMingguan, kasbon:kas, total:bersih))),
                        const SizedBox(width:8),
                        Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.chat, size:16), label: const Text("WA", style: TextStyle(fontSize:12)), style: ElevatedButton.styleFrom(backgroundColor: col, foregroundColor: _getTextColor(col)), onPressed: ()=>_shareWA(nama:nama, periode:periode, pokok:g.totalGajiPokok, bonus:g.bonusMingguan, kasbon:kas, total:bersih))),
                        const SizedBox(width:8),
                        Container(padding: const EdgeInsets.symmetric(horizontal:10, vertical:6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: col, width:2)), child: DropdownButton<String>(value:g.statusBayar, underline: const SizedBox(), isDense:true, items: const [DropdownMenuItem(value:'BELUM_GAJIAN', child: Text("Belum Gajian", style: TextStyle(fontSize:12))), DropdownMenuItem(value:'1 MINGGU', child: Text("1 Minggu", style: TextStyle(fontSize:12))), DropdownMenuItem(value:'2 MINGGU', child: Text("2 Minggu", style: TextStyle(fontSize:12))), DropdownMenuItem(value:'LUNAS', child: Text("Lunas", style: TextStyle(fontSize:12)))], onChanged: (v) async { if(v!=null){ await db.tandaiBayar(g.id, v); setState((){}); }})),
                      ]),
                    ])),
                  ])));
                });
              });
            })),
          ]));
        }),
      ]),
    );
  }
}