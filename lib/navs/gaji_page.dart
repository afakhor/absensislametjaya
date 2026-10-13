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

// FIX ANTI MINUS: jangan ubah totalGaji di tabel gaji, kasbon simpan terpisah
extension AppDatabaseKasbonFix on AppDatabase {
  Future<void> inputPotonganKasbon(int karyawanId, DateTime tgl, int nominal) async {
    // Validasi: nominal tidak boleh minus
    if(nominal < 0) nominal = 0;
    await simpanKasbonHarian(karyawanId, tgl, nominal, "Kasbon via GajiPage");
  }
}

class GajiPage extends StatefulWidget {
  const GajiPage({super.key});
  @override State<GajiPage> createState() => _GajiPageState();
}

class _GajiPageState extends State<GajiPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  final List<int> _selectedKaryawanIds = [];
  final List<String> _selectedStatusColors = [];
  bool _filterHanyaKasbon = false, _filterTanpaKasbon = false, _filterHanyaBonus = false, _filterTanpaBonus = false;
  DateTimeRange? _selectedDateRange;
  bool _sortByTerbanyak = false, _isLoadingProses = false;

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

  // RUMUS ADIL CEK & RECEK
  int _hitungBersihAdil({required int pokok, required int bonus, required int kasbon}){
    final kotor = pokok + bonus; // total kotor
    var bersih = kotor - kasbon;
    if(bersih < 0) bersih = 0; // anti minus, adil untuk karyawan & pemilik
    return bersih;
  }

  Future<pw.Document> _pdf({required String nama, required String periode, required int pokok, required int bonus, required int kasbon, required int total}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.roll80, margin: const pw.EdgeInsets.all(12), build: (c)=> pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children:[
      pw.Center(child: pw.Text("TB. SLAMET JAYA", style: pw.TextStyle(fontSize:16, fontWeight: pw.FontWeight.bold))),
      pw.Divider(thickness:0.8),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Nama:", style: const pw.TextStyle(fontSize:9)), pw.Text(nama, style: pw.TextStyle(fontSize:9, fontWeight: pw.FontWeight.bold))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Periode:", style: const pw.TextStyle(fontSize:9)), pw.Text(periode, style: const pw.TextStyle(fontSize:8))]),
      pw.Divider(thickness:0.8),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Gaji Pokok", style: const pw.TextStyle(fontSize:9)), pw.Text("Rp ${fmt.format(pokok)}", style: const pw.TextStyle(fontSize:9))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Bonus", style: const pw.TextStyle(fontSize:9)), pw.Text("Rp ${fmt.format(bonus)}", style: const pw.TextStyle(fontSize:9))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("Kasbon", style: const pw.TextStyle(fontSize:9)), pw.Text("- Rp ${fmt.format(kasbon)}", style: const pw.TextStyle(fontSize:9))]),
      pw.Divider(thickness:0.8),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("KOTOR (Pokok+Bonus):", style: const pw.TextStyle(fontSize:9)), pw.Text("Rp ${fmt.format(pokok+bonus)}", style: const pw.TextStyle(fontSize:9))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[pw.Text("TOTAL TERIMA (Anti Minus):", style: pw.TextStyle(fontSize:10, fontWeight: pw.FontWeight.bold)), pw.Text("Rp ${fmt.format(total)}", style: pw.TextStyle(fontSize:10, fontWeight: pw.FontWeight.bold))]),
      if(total==0 && kasbon > (pokok+bonus)) pw.Text("Sisa kasbon Rp ${fmt.format(kasbon-(pokok+bonus))} ditahan minggu depan", style: const pw.TextStyle(fontSize:7)),
    ])));
    return pdf;
  }

  Future<void> _shareWA({required String nama, required String periode, required int pokok, required int bonus, required int kasbon, required int total}) async {
    final pdf = await _pdf(nama:nama, periode:periode, pokok:pokok, bonus:bonus, kasbon:kasbon, total:total);
    final bytes = await pdf.save(); final dir = await getTemporaryDirectory(); final path = "${dir.path}/Slip_$nama.pdf"; await File(path).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(path)], text:"*SLIP GAJI TB. SLAMET JAYA*\nNama: $nama\nPeriode: $periode\nKotor: Rp ${fmt.format(pokok+bonus)}\nKasbon: Rp ${fmt.format(kasbon)}\nTotal Terima: Rp ${fmt.format(total)} (anti minus)");
  }
  Future<void> _printSlip({required String nama, required String periode, required int pokok, required int bonus, required int kasbon, required int total}) async {
    final pdf = await _pdf(nama:nama, periode:periode, pokok:pokok, bonus:bonus, kasbon:kasbon, total:total);
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }

  void _dialogBonus(BuildContext ctx, GajiMingguanData g){
    final c = TextEditingController(text: g.bonusMingguan==0? "" : g.bonusMingguan.toString());
    showDialog(context: context, builder: (_)=> AlertDialog(title: const Text("Bonus Mingguan"), content: TextField(controller:c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText:"0 (kosong=0)", border: OutlineInputBorder())), actions:[
      TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Batal")),
      ElevatedButton(onPressed: () async { await db.inputBonusMingguan(g.id, int.tryParse(c.text)??0); await _refreshGajiData(); if(ctx.mounted) Navigator.pop(ctx); }, child: const Text("Simpan")),
    ]));
  }
  void _dialogKasbon(BuildContext ctx, GajiMingguanData g, int karyawanId, int kotor){
    final c = TextEditingController();
    showDialog(context: context, builder: (_)=> AlertDialog(title: Text("Potongan Kasbon - Max Rp ${fmt.format(kotor)}"), content: Column(mainAxisSize: MainAxisSize.min, children:[
      Text("Gaji kotor saat ini Rp ${fmt.format(kotor)} (pokok+bonus). Jika kasbon melebihi kotor, terima jadi 0 dan sisa ditahan.", style: const TextStyle(fontSize:11)),
      const SizedBox(height:8),
      TextField(controller:c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText:"0 (kosong=0)", border: OutlineInputBorder())),
    ]), actions:[
      TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Batal")),
      ElevatedButton(onPressed: () async {
        int val = int.tryParse(c.text)??0;
        if(val < 0) val = 0;
        // Info jika melebihi kotor
        if(val > kotor && ctx.mounted){
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kasbon Rp ${fmt.format(val)} melebihi kotor Rp ${fmt.format(kotor)}. Terima jadi 0, sisa Rp ${fmt.format(val-kotor)} ngutang minggu depan"), backgroundColor: roast));
        }
        await db.inputPotonganKasbon(karyawanId, g.mingguMulai, val);
        await _refreshGajiData();
        if(ctx.mounted) Navigator.pop(ctx);
      }, child: const Text("Simpan")),
    ]));
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text("REKAP GAJI KARYAWAN"), backgroundColor: roast, foregroundColor: Colors.white, actions:[
        IconButton(icon: const Icon(Icons.sync), onPressed: _refreshGajiData),
      ]),
      body: StreamBuilder<List<GajiMingguanData>>(
        stream: (db.select(db.gajiMingguan)..orderBy([(t)=>OrderingTerm.desc(t.mingguMulai)])).watch(),
        builder: (c,snap){
          if(!snap.hasData) return const Center(child: CircularProgressIndicator());
          var all = snap.data?? [];
          var filtered = all.where((g){
            if(_selectedDateRange!=null){
              if(g.mingguMulai.isBefore(_selectedDateRange!.start)||g.mingguSelesai.isAfter(_selectedDateRange!.end)) return false;
            }
            if(_selectedKaryawanIds.isNotEmpty&&!_selectedKaryawanIds.contains(g.karyawanId)) return false;
            if(_selectedStatusColors.isNotEmpty&&!_selectedStatusColors.contains(g.statusBayar)) return false;
            return true;
          }).toList();

          final now = DateTime.now();
          final startWeek = DateTime(2026,10,12);
          final endWeek = DateTime(2026,10,18,23,59,59);
          final startMonth = DateTime(now.year, now.month, 1);
          final endMonth = DateTime(now.year, now.month+1, 0, 23,59,59);

          return StreamBuilder<List<KaryawanData>>(stream: db.select(db.karyawan).watch(), builder: (c,karSnap){
            final listKar = karSnap.data?? [];
            return StreamBuilder<int>(stream: Stream.periodic(const Duration(seconds:1), (_)=> DateTime.now()).asyncMap((_)=> db.hitungGajiHariIni(DateTime.now())), builder: (c,liveSnap){
              final bebanLive = liveSnap.data??0;
              return FutureBuilder<Map<int,int>>(future: () async {
                Map<int,int> map = {};
                for(var g in all){
                  final k = await db.getKasbonPeriode(g.karyawanId, g.mingguMulai, g.mingguSelesai);
                  map[g.id] = k;
                }
                return map;
              }(), builder: (c,kasbonMapSnap){
                final kasbonMap = kasbonMapSnap.data?? {};
                // RUMUS ADIL
                int bersihAdil(GajiMingguanData g){
                  final kas = kasbonMap[g.id]??0;
                  return _hitungBersihAdil(pokok: g.totalGajiPokok, bonus: g.bonusMingguan, kasbon: kas);
                }
                final mingguIniList = all.where((g)=>!g.mingguMulai.isBefore(startWeek) &&!g.mingguSelesai.isAfter(endWeek)).toList();
                final bulanIniList = all.where((g)=>!g.mingguMulai.isBefore(startMonth) &&!g.mingguSelesai.isAfter(endMonth)).toList();
                final totalMingguIni = mingguIniList.fold<int>(0,(s,g)=> s + bersihAdil(g));
                final totalBulanIni = bulanIniList.fold<int>(0,(s,g)=> s + bersihAdil(g));
                final totalDariAwal = all.fold<int>(0,(s,g)=> s + bersihAdil(g));
                final lunasOnly = filtered.where((g)=>g.statusBayar=='LUNAS').toList();
                final totalLunas = lunasOnly.fold<int>(0,(s,g)=> s + bersihAdil(g));

                return CustomScrollView(slivers:[
                  SliverToBoxAdapter(child: Column(children:[
                    Container(width: double.infinity, margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal:12, vertical:8), decoration: BoxDecoration(color: caramel.withOpacity(0.25), borderRadius: BorderRadius.circular(12), border: Border.all(color: caramel)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                      Text("Beban Gaji Hari Ini: Rp ${fmt.format(bebanLive)}", style: TextStyle(fontSize:11, fontWeight: FontWeight.bold, color: roast)),
                      const Text("LIVE", style: TextStyle(fontSize:10, fontWeight: FontWeight.bold)),
                    ])),
                    Container(margin: const EdgeInsets.fromLTRB(8,0,8,6), padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: caramel.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: caramel, width:1.2)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children:[const Text("PERIODE SENIN-MINGGU INI", style: TextStyle(fontWeight: FontWeight.bold, fontSize:11, color: Color(0xFF613A1E))), Text("${DateFormat('dd-18 MMM yyyy').format(startWeek).toUpperCase()}", style: TextStyle(fontWeight: FontWeight.bold, fontSize:13, color: roast))]),
                      Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:4), decoration: BoxDecoration(color: coffee, borderRadius: BorderRadius.circular(20)), child: const Text("AKTIF", style: TextStyle(color: Colors.white, fontSize:11, fontWeight: FontWeight.bold))),
                    ])),
                    Container(margin: const EdgeInsets.fromLTRB(8,0,8,6), padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: caramel, width:6))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Minggu Ini • ${mingguIniList.length} karyawan", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12, color: roast)), const Text("12-18 Oct live", style: TextStyle(fontSize:11, color: Colors.grey))]),
                      Text("Rp ${fmt.format(totalMingguIni)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize:14, color: coffee)),
                    ])),
                    Container(margin: const EdgeInsets.fromLTRB(8,0,8,6), padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: coffee, width:6))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Bulan Ini ${DateFormat('MMM yyyy').format(now)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12, color: roast))]),
                      Text("Rp ${fmt.format(totalBulanIni)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize:14, color: espresso)),
                    ])),
                    Container(margin: const EdgeInsets.fromLTRB(8,0,8,6), padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: espresso, width:6))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                      const Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Dari Awal", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)), Text("APK Terinstall", style: TextStyle(fontSize:11, color: Colors.grey))]),
                      Text("Rp ${fmt.format(totalDariAwal)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize:14, color: roast)),
                    ])),
                    Container(margin: const EdgeInsets.fromLTRB(8,0,8,8), padding: const EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: roast, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                      const Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Total Akumulasi Terbayar:", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12, color: Color(0xFFA87336))), Text("Hanya yang Lunas", style: TextStyle(fontSize:10, color: Colors.white70))]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children:[Text("Rp ${fmt.format(totalLunas)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFA87336))), Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text("${lunasOnly.length} Lunas", style: const TextStyle(fontSize:11)))])
                    ])),
                  ])),
                  SliverList.builder(itemCount: filtered.length, itemBuilder: (_,i){
                    final g = filtered[i];
                    KaryawanData? kar; try{ kar=listKar.firstWhere((k)=>k.id==g.karyawanId);} catch(_){}
                    final col=_getWarnaStatus(g.statusBayar); final nama=kar?.nama??"ID ${g.karyawanId}"; final periode="${DateFormat('dd/MM').format(g.mingguMulai)}-${DateFormat('dd/MM/yy').format(g.mingguSelesai)}";
                    final kas = kasbonMap[g.id]??0;
                    final kotor = g.totalGajiPokok + g.bonusMingguan;
                    final bersih = _hitungBersihAdil(pokok: g.totalGajiPokok, bonus: g.bonusMingguan, kasbon: kas);
                    final sisaUtang = kas > kotor? kas - kotor : 0;
                    return Card(elevation:2, margin: const EdgeInsets.symmetric(horizontal:8, vertical:4), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: col, width:6))), child: ExpansionTile(
                      title: Row(children:[CircleAvatar(backgroundColor: col.withOpacity(0.3), child: Text(nama.isNotEmpty? nama[0].toUpperCase() : "?", style: TextStyle(color: roast))), const SizedBox(width:8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        Row(children:[Flexible(child: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize:13))), if(kas>0) Container(margin: const EdgeInsets.only(left:6), padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: espresso, borderRadius: BorderRadius.circular(4)), child: const Text("KASBON", style: TextStyle(fontSize:9, color: Colors.white)))]),
                        Text("Periode $periode • Kotor Rp ${fmt.format(kotor)} • Bersih Rp ${fmt.format(bersih)}", style: const TextStyle(fontSize:11)),
                      ]))]),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children:[
                        Text("Rp ${fmt.format(bersih)}", style: TextStyle(fontWeight: FontWeight.bold, color: bersih==0? Colors.red : roast)),
                        if(sisaUtang>0) Text("Sisa Rp ${fmt.format(sisaUtang)}", style: const TextStyle(fontSize:9, color: Colors.red)),
                      ]),
                      children:[Padding(padding: const EdgeInsets.all(16), child: Column(children:[
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: caramel.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: caramel, width:4))), child: Column(children:[
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text("Gaji Pokok (Live):"), Text("Rp ${fmt.format(g.totalGajiPokok)}")]),
                          const SizedBox(height:4),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text("Bonus:"), Text("Rp ${fmt.format(g.bonusMingguan)}")]),
                          const Divider(),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text("KOTOR:", style: TextStyle(fontWeight: FontWeight.bold)), Text("Rp ${fmt.format(kotor)}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                        ])),
                        const SizedBox(height:8),
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: espresso, width:4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[const Text("Potongan Kasbon:", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)), Text("Rp ${fmt.format(kas)}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                          const SizedBox(height:8),
                          InkWell(onTap: ()=>_dialogKasbon(context,g,g.karyawanId,kotor), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal:12, vertical:10), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Text(kas==0? "0" : fmt.format(kas), style: TextStyle(color: kas==0? Colors.grey : roast)))),
                          if(sisaUtang>0) Padding(padding: const EdgeInsets.only(top:6), child: Text("Kasbon sisa Rp ${fmt.format(sisaUtang)} ditahan minggu depan (adil)", style: const TextStyle(fontSize:10, color: Colors.red))),
                        ])),
                        const SizedBox(height:8),
                        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bersih==0? Colors.red.shade900 : roast, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                          const Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Total Diterima:", style: TextStyle(color: Color(0xFFA87336), fontWeight: FontWeight.bold, fontSize:12)), Text("pokok+bonus-kasbon", style: TextStyle(color: Colors.white60, fontSize:10))]),
                          Text("Rp ${fmt.format(bersih)}", style: const TextStyle(color: Color(0xFFA87336), fontWeight: FontWeight.bold, fontSize:14)),
                        ])),
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
                  }),
                ]);
              });
            });
          });
        },
      ),
    );
  }
}