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

// === EXTENSION FIX untuk inputPotonganKasbon yang belum ada di AppDatabase ===
extension AppDatabaseKasbon on AppDatabase {
  Future<void> inputPotonganKasbon(int gajiId, int nominal) async {
    // Ambil data gaji existing
    final g = await (select(gajiMingguan)..where((t) => t.id.equals(gajiId))).getSingle();
    // Update totalGaji = pokok + bonus - kasbon (logic sesuai chat: cek dan recek kalkulasi)
    final newTotal = g.totalGajiPokok + g.bonusMingguan - nominal;
    await (update(gajiMingguan)..where((t) => t.id.equals(gajiId))).write(
      GajiMingguanCompanion(totalGaji: Value(newTotal)),
    );
    // TODO: jika kamu punya tabel kasbon terpisah, insert juga kesana:
    // await into(kasbon).insert(KasbonCompanion(karyawanId: Value(g.karyawanId), jumlah: Value(nominal), tanggal: Value(DateTime.now())));
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

  static const latte = Color(0xFFE9D5B7);
  static const cappuccino = Color(0xFFC89F73);
  static const americano = Color(0xFF8B5E3C);
  static const darkRoast = Color(0xFF2B1B12);

  @override void initState(){ super.initState(); _refreshGajiData(); }
  Future<void> _refreshGajiData() async {
    if(_isLoadingProses) return;
    setState(()=>_isLoadingProses=true);
    try{ await db.prosesHitungGajiMingguan(); } catch(e){ debugPrint("Error: $e"); }
    finally{ if(mounted) setState(()=>_isLoadingProses=false); }
  }

  Color _getWarnaStatus(String s){
    switch(s){ case 'BELUM_GAJIAN': case 'BELUM': return latte; case '1 MINGGU': case 'MINGGU1': return cappuccino; case '2 MINGGU': case 'MINGGU2': return americano; case 'LUNAS': return darkRoast; default: return latte; }
  }
  Color _getTextColor(Color bg)=> (bg==latte||bg==cappuccino)? darkRoast : Colors.white;
  String _getLabel(String s){
    switch(s){ case 'BELUM_GAJIAN': case 'BELUM': return 'BELUM GAJIAN'; case '1 MINGGU': case 'MINGGU1': return '1 MINGGU'; case '2 MINGGU': case 'MINGGU2': return '2 MINGGU'; case 'LUNAS': return 'LUNAS'; default: return 'BELUM GAJIAN'; }
  }

  Future<pw.Document> _pdf({required String nama, required String periode, required int pokok, required int bonus, required int kasbon, required int total}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.roll80, margin: const pw.EdgeInsets.all(12), build: (c)=> pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children:[
      pw.Center(child: pw.Text("TB. SLAMET JAYA", style: pw.TextStyle(fontSize:16, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800))),
      pw.SizedBox(height:2), pw.Center(child: pw.Text("DUSUN JRANJANG RT 12/RW 6 KERTOSUKO KRUCIL PROBOLINGGO (082229109246)", textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize:7))),
      pw.SizedBox(height:6), pw.Divider(thickness:0.8), pw.SizedBox(height:4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Nama:", style: const pw.TextStyle(fontSize:9)), pw.Text(nama, style: pw.TextStyle(fontSize:9, fontWeight: pw.FontWeight.bold))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Periode:", style: const pw.TextStyle(fontSize:9)), pw.Text(periode, style: const pw.TextStyle(fontSize:8))]),
      pw.SizedBox(height:4), pw.Divider(thickness:0.8), pw.SizedBox(height:4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Gaji Pokok", style: const pw.TextStyle(fontSize:9)), pw.Text("Rp ${fmt.format(pokok)}", style: const pw.TextStyle(fontSize:9))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Bonus", style: const pw.TextStyle(fontSize:9)), pw.Text("Rp ${fmt.format(bonus)}", style: const pw.TextStyle(fontSize:9))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Kasbon", style: const pw.TextStyle(fontSize:9)), pw.Text("- Rp ${fmt.format(kasbon)}", style: const pw.TextStyle(fontSize:9))]),
      pw.SizedBox(height:4), pw.Divider(thickness:0.8), pw.SizedBox(height:4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("TOTAL TERIMA:", style: pw.TextStyle(fontSize:10, fontWeight: pw.FontWeight.bold)), pw.Text("Rp ${fmt.format(total)}", style: pw.TextStyle(fontSize:10, fontWeight: pw.FontWeight.bold))]),
      pw.SizedBox(height:2), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Tgl:", style: const pw.TextStyle(fontSize:8)), pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize:8))]),
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
    showDialog(context: context, builder: (_)=> AlertDialog(title: const Text("Box Bonus Mingguan"), content: TextField(controller:c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText:"0 (kosong=0)", border: OutlineInputBorder())), actions:[
      TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Batal")),
      ElevatedButton(onPressed: () async { await db.inputBonusMingguan(g.id, int.tryParse(c.text)??0); await _refreshGajiData(); if(ctx.mounted) Navigator.pop(ctx); }, child: const Text("Simpan")),
    ]));
  }
  void _dialogKasbon(BuildContext ctx, GajiMingguanData g, int now) async {
    final c = TextEditingController(text: now==0? "" : now.toString());
    showDialog(context: context, builder: (_)=> AlertDialog(title: const Text("Box Potongan Kasbon"), content: TextField(controller:c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText:"0 (kosong=0)", border: OutlineInputBorder())), actions:[
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
      Wrap(spacing:8, children:[_chip("BELUM_GAJIAN","Belum Gajian",latte,setM), _chip("1 MINGGU","1 Minggu",cappuccino,setM), _chip("2 MINGGU","2 Minggu",americano,setM), _chip("LUNAS","Lunas",darkRoast,setM)]),
      const SizedBox(height:12), const Text("Filter Kasbon", style: TextStyle(fontWeight: FontWeight.bold, fontSize:13)), Wrap(spacing:8, children:[
        FilterChip(label: const Text("Ada Kasbon"), selected: _filterHanyaKasbon, selectedColor: americano.withOpacity(0.3), onSelected: (v){ setM(()=>_filterHanyaKasbon=v); setState(()=>_filterTanpaKasbon=false); }),
        FilterChip(label: const Text("Tidak Ada Kasbon"), selected: _filterTanpaKasbon, onSelected: (v){ setM(()=>_filterTanpaKasbon=v); setState(()=>_filterHanyaKasbon=false); }),
      ]),
      const SizedBox(height:12), const Text("Filter Bonus", style: TextStyle(fontWeight: FontWeight.bold, fontSize:13)), Wrap(spacing:8, children:[
        FilterChip(label: const Text("Ada Bonus"), selected: _filterHanyaBonus, selectedColor: cappuccino.withOpacity(0.3), onSelected: (v){ setM(()=>_filterHanyaBonus=v); setState(()=>_filterTanpaBonus=false); }),
        FilterChip(label: const Text("Tidak Ada Bonus"), selected: _filterTanpaBonus, onSelected: (v){ setM(()=>_filterTanpaBonus=v); setState(()=>_filterHanyaBonus=false); }),
      ]),
      const SizedBox(height:12), const Text("Filter Karyawan", style: TextStyle(fontWeight: FontWeight.bold, fontSize:13)),
      Wrap(spacing:6, children: listKar.map((k){ final sel=_selectedKaryawanIds.contains(k.id); return FilterChip(label: Text(k.nama), selected:sel, onSelected:(v){ setM(()=> v? _selectedKaryawanIds.add(k.id) : _selectedKaryawanIds.remove(k.id)); setState((){}); }); }).toList()),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Urutkan Terbanyak", style: TextStyle(fontWeight: FontWeight.bold, fontSize:13)), value:_sortByTerbanyak, onChanged:(v){ setM(()=>_sortByTerbanyak=v); setState((){}); }),
      SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: darkRoast), onPressed: ()=>Navigator.pop(ctx), child: const Text("Terapkan Filter", style: TextStyle(color:Colors.white)))),
    ]))))));
  }
  Widget _chip(String val, String label, Color col, StateSetter setM){
    final sel=_selectedStatusColors.contains(val);
    return FilterChip(label: Text(label, style: TextStyle(color: sel? _getTextColor(col) : darkRoast, fontSize:12, fontWeight: FontWeight.bold)), selected:sel, backgroundColor: col.withOpacity(0.25), selectedColor: col, onSelected:(v){ setM(()=> v? _selectedStatusColors.add(val) : _selectedStatusColors.remove(val)); setState((){}); });
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text("TB. SLAMET JAYA REKAP GAJI MINGGUAN"), backgroundColor: darkRoast, foregroundColor: Colors.white, actions:[
        IconButton(icon: const Icon(Icons.sync), onPressed: _refreshGajiData),
        StreamBuilder<List<KaryawanData>>(stream: db.select(db.karyawan).watch(), builder: (c,s)=> IconButton(icon: const Icon(Icons.filter_list), onPressed: ()=>_showFilter(s.data??[]))),
      ]),
      body: Column(children:[
        if(_isLoadingProses) const LinearProgressIndicator(color: cappuccino),
        StreamBuilder<List<GajiMingguanData>>(stream: (db.select(db.gajiMingguan)..orderBy([(t)=>OrderingTerm.desc(t.mingguMulai)])).watch(), builder: (c,snap){
          if(snap.hasError) return Center(child: Text("Error: ${snap.error}")); if(!snap.hasData) return const Center(child: CircularProgressIndicator());
          var all=snap.data??[];
          var filtered=all.where((g){ if(_selectedDateRange!=null){ if(g.mingguMulai.isBefore(_selectedDateRange!.start)||g.mingguSelesai.isAfter(_selectedDateRange!.end)) return false; } if(_selectedKaryawanIds.isNotEmpty&&!_selectedKaryawanIds.contains(g.karyawanId)) return false; if(_selectedStatusColors.isNotEmpty&&!_selectedStatusColors.contains(g.statusBayar)) return false; return true; }).toList();
          final lunasOnly=filtered.where((g)=>g.statusBayar=='LUNAS').toList(); final totalLunas=lunasOnly.fold<int>(0,(s,g)=>s+g.totalGaji);
          return Expanded(child: Column(children:[
            Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: latte.withOpacity(0.4), borderRadius: BorderRadius.circular(12), border: Border.all(color: darkRoast, width:1.2)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Total Akumulasi Terbayar (Lunas):", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)), Text("Hanya status hijau Lunas", style: TextStyle(fontSize:10))]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children:[Text("Rp ${fmt.format(totalLunas)}", style: const TextStyle(fontWeight: FontWeight.bold)), Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: darkRoast)), child: Text("${lunasOnly.length} data Lunas", style: const TextStyle(fontSize:11)))])
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
                    title: Row(children:[CircleAvatar(backgroundColor: col.withOpacity(0.3), child: Text(nama[0].toUpperCase(), style: TextStyle(color: darkRoast))), const SizedBox(width:8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                      Row(children:[Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize:13)), const SizedBox(width:6), if(kas>0) Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: americano, borderRadius: BorderRadius.circular(4)), child: Text("KASBON", style: TextStyle(fontSize:9, color: _getTextColor(americano)))), const SizedBox(width:4), Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4)), child: Text(_getLabel(g.statusBayar), style: TextStyle(fontSize:9, color: _getTextColor(col), fontWeight: FontWeight.bold)))]),
                      Text("Periode $periode • ${g.totalHariEfektif} Hari • ${_getLabel(g.statusBayar)}", style: const TextStyle(fontSize:11)),
                    ]))]),
                    trailing: Text("Rp ${fmt.format(bersih)}", style: TextStyle(fontWeight: FontWeight.bold, color: darkRoast)),
                    children:[Padding(padding: const EdgeInsets.all(16), child: Column(children:[
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text("Gaji Pokok:"), Text("Rp ${fmt.format(g.totalGajiPokok)}")]), const SizedBox(height:8),
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: col, width:4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text("● Box Bonus Mingguan:", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)), Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:3), decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(12)), child: Text(g.bonusMingguan==0? "hijau kosong → 0" : "Rp ${fmt.format(g.bonusMingguan)}", style: TextStyle(fontSize:10, color: _getTextColor(col))))]),
                        const SizedBox(height:8), InkWell(onTap: ()=>_dialogBonus(context,g), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal:12, vertical:10), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Text(g.bonusMingguan==0? "0" : fmt.format(g.bonusMingguan), style: TextStyle(color: g.bonusMingguan==0? Colors.grey : darkRoast)))),
                      ])),
                      const SizedBox(height:8),
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: col, width:4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        const Text("● Box Potongan Kasbon:", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)), const SizedBox(height:8),
                        InkWell(onTap: ()=>_dialogKasbon(context,g,kas), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal:12, vertical:10), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Text(kas==0? "0" : fmt.format(kas), style: TextStyle(color: kas==0? Colors.grey : darkRoast)))),
                      ])),
                      const SizedBox(height:8),
                      Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: darkRoast, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Total Diterima Bersih:", style: TextStyle(color: Color(0xFFE9D5B7), fontWeight: FontWeight.bold, fontSize:12)), Text("50rb + bonus - potongan (kosong=0)", style: TextStyle(color: Colors.white60, fontSize:10))]), Text("Rp ${fmt.format(bersih)}", style: const TextStyle(color: Color(0xFFE9D5B7), fontWeight: FontWeight.bold, fontSize:14))])),
                      const SizedBox(height:12),
                      Row(children:[
                        Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.description, size:16), label: const Text("slip", style: TextStyle(fontSize:12)), style: ElevatedButton.styleFrom(backgroundColor: darkRoast, foregroundColor: Colors.white), onPressed: ()=>_printSlip(nama:nama, periode:periode, pokok:g.totalGajiPokok, bonus:g.bonusMingguan, kasbon:kas, total:bersih))),
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