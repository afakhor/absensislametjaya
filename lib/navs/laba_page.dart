import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../export_pdf.dart';
import '../dbases/localdatabase.dart';
import '../dbases/laba_db.dart';
import '../dbases/gaji_db.dart';

class LabaPage extends StatefulWidget { const LabaPage({super.key}); @override State<LabaPage> createState() => _LabaPageState(); }

class _LabaPageState extends State<LabaPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  final omsetC = TextEditingController(); final pemasukanLainC = TextEditingController(text:"0");
  final bebanOpsC = TextEditingController(); final bebanLainC = TextEditingController(text:"0");
  final bebanGajiC = TextEditingController(text:"0"); final catatanC = TextEditingController();
  DateTimeRange? periode; int? editingId;

  // FILTER BARU AKUMULASI BEBAN GAJI
  int? filterKaryawanId; int? filterKategoriId;
  String filterWaktu = 'CONTINUE';
  DateTime? filterMulai; DateTime? filterSelesai;
  int totalAkumulasiGaji = 0;

  int _parse(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''))?? 0;

  Future<void> _hitungAkumulasi() async {
    DateTime? m = filterMulai; DateTime? s;
    final now = DateTime.now();
    if(filterWaktu=='MINGGU'){ m = now.subtract(Duration(days: now.weekday-1)); s = now; }
    else if(filterWaktu=='2MINGGU'){ m = now.subtract(const Duration(days:14)); s = now; }
    else if(filterWaktu=='BULAN'){ m = DateTime(now.year, now.month, 1); s = now; }
    else if(filterWaktu=='RANGE'){ m = filterMulai; s = filterSelesai; }
    else if(filterWaktu=='CONTINUE'){ m = null; s = now; }
    else if(filterWaktu=='TANGGAL_TERTENTU'){ m = filterMulai; s = now; }

    totalAkumulasiGaji = await db.getAkumulasiBebanGaji(karyawanId: filterKaryawanId, kategoriId: filterKategoriId, mulai: m, selesai: s);
    setState((){});
  }

  @override void initState(){ super.initState(); _hitungAkumulasi(); }

  Future<void> _pickPeriode() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(now.year-1,1,1), lastDate: DateTime(now.year+1,12,31), initialDateRange: periode?? DateTimeRange(start: DateTime(now.year,now.month,1), end: now));
    if(picked!=null){ setState(()=>periode=picked); int gaji=await db.hitungBebanGajiPeriode(picked.start, picked.end); setState(()=>bebanGajiC.text=gaji.toString()); }
  }

  Future<void> _simpan() async {
    if(periode==null){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih periode dulu"))); return; }
    int omset=_parse(omsetC.text); int pl=_parse(pemasukanLainC.text); int bo=_parse(bebanOpsC.text); int bl=_parse(bebanLainC.text); int bg=_parse(bebanGajiC.text);
    int totalP=omset+pl; int totalB=bo+bl+bg; int lk=omset-bo; int lb=totalP-totalB;
    final data=SimulasiLabaCompanion(periodeMulai: drift.Value(periode!.start), periodeSelesai: drift.Value(periode!.end), omset: drift.Value(omset), pemasukanLain: drift.Value(pl), bebanOperasional: drift.Value(bo), bebanLain: drift.Value(bl), bebanGaji: drift.Value(bg), totalPemasukan: drift.Value(totalP), totalBeban: drift.Value(totalB), labaKotor: drift.Value(lk), labaBersih: drift.Value(lb), catatan: drift.Value(catatanC.text), tanggalSimulasi: drift.Value(DateTime.now()));
    if(editingId==null) await db.simpanSimulasi(data); else { await db.updateSimulasi(editingId!, data); editingId=null; }
    setState((){ omsetC.clear(); pemasukanLainC.text="0"; bebanOpsC.clear(); bebanLainC.text="0"; bebanGajiC.text="0"; catatanC.clear(); periode=null; editingId=null; });
  }

  @override Widget build(BuildContext context) {
    int omset=_parse(omsetC.text); int pl=_parse(pemasukanLainC.text); int bo=_parse(bebanOpsC.text); int bl=_parse(bebanLainC.text); int bg=_parse(bebanGajiC.text);
    int totalP=omset+pl; int totalB=bo+bl+bg; int lk=omset-bo; int lb=totalP-totalB;
    return Scaffold(
      appBar: AppBar(title: const Text("Laba & Beban Gaji Continue"), backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        // FILTER AKUMULASI BEBAN GAJI - REQUIRED BARU
        Card(color: Colors.brown.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("LOG AKUMULASI BEBAN GAJI - DARI AWAL SAMPAI CONTINUE", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<KaryawanData>>(stream: db.watchKaryawan(), builder: (c,s){
            final list=s.data??[];
            return DropdownButton<int?>(isExpanded: true, value: filterKaryawanId, hint: const Text("Filter: Per ID Karyawan"), items: [const DropdownMenuItem(value: null, child: Text("Semua Karyawan")),...list.map((e)=>DropdownMenuItem(value: e.id, child: Text("ID:${e.id} - ${e.nama}")))], onChanged: (v){ setState(()=>filterKaryawanId=v); _hitungAkumulasi(); });
          }),
          StreamBuilder<List<KategoriKaryawanData>>(stream: db.watchKategori(), builder: (c,s){
            final list=s.data??[];
            return DropdownButton<int?>(isExpanded: true, value: filterKategoriId, hint: const Text("Filter: Per Kategori"), items: [const DropdownMenuItem(value: null, child: Text("Semua Kategori")),...list.map((e)=>DropdownMenuItem(value: e.id, child: Text(e.namaKategori)))], onChanged: (v){ setState(()=>filterKategoriId=v); _hitungAkumulasi(); });
          }),
          DropdownButton<String>(isExpanded: true, value: filterWaktu, items: const [
            DropdownMenuItem(value: 'CONTINUE', child: Text("Akumulasi Awal - Continue (Hari Ini)")),
            DropdownMenuItem(value: 'MINGGU', child: Text("Akumulasi Per Minggu")),
            DropdownMenuItem(value: '2MINGGU', child: Text("Akumulasi Per 2 Minggu")),
            DropdownMenuItem(value: 'BULAN', child: Text("Akumulasi Per Bulan")),
            DropdownMenuItem(value: 'RANGE', child: Text("Akumulasi Per Range Tanggal")),
            DropdownMenuItem(value: 'TANGGAL_TERTENTU', child: Text("Akumulasi Tgl Tertentu Sampai Continue")),
          ], onChanged: (v) async {
            setState(()=>filterWaktu=v!);
            if(v=='RANGE' || v=='TANGGAL_TERTENTU'){
              final p=await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now(), initialDateRange: filterMulai!=null&&filterSelesai!=null?DateTimeRange(start: filterMulai!, end: filterSelesai!):null);
              if(p!=null){ filterMulai=p.start; filterSelesai=p.end; }
            }
            _hitungAkumulasi();
          }),
          const Divider(),
          Text("TOTAL AKUMULASI BEBAN GAJI", style: TextStyle(color: Colors.brown.shade700)),
          Text("Rp ${fmt.format(totalAkumulasiGaji)}", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.brown.shade800)),
          Text("Filter: ${filterKaryawanId==null?'Semua Karyawan':'ID $filterKaryawanId'} | ${filterKategoriId==null?'Semua Kat':'Kat $filterKategoriId'} | $filterWaktu", style: const TextStyle(fontSize: 10)),
        ]))),
        const Divider(),
        const Text("Simulasi Laba Manual", style: TextStyle(fontWeight: FontWeight.bold)),
        InkWell(onTap: _pickPeriode, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.date_range), const SizedBox(width:8), Text(periode==null?"Pilih Periode": "${DateFormat('dd MMM').format(periode!.start)} - ${DateFormat('dd MMM yy').format(periode!.end)}")]))),
        const SizedBox(height:8),
        TextField(controller: omsetC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Omset", border: OutlineInputBorder()), onChanged: (_)=>setState((){})),
        const SizedBox(height:8),
        TextField(controller: bebanOpsC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Beban Operasional", border: OutlineInputBorder()), onChanged: (_)=>setState((){})),
        const SizedBox(height:8),
        TextField(controller: bebanGajiC, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Beban Gaji (auto)", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.refresh), onPressed: () async { if(periode!=null){ int g=await db.hitungBebanGajiPeriode(periode!.start, periode!.end); setState(()=>bebanGajiC.text=g.toString()); } }))),
        const SizedBox(height:8),
        Container(padding: const EdgeInsets.all(12), color: Colors.orange.shade50, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Total Pemasukan: Rp ${fmt.format(totalP)}"), Text("Total Beban: Rp ${fmt.format(totalB)}"), Text("Laba Kotor: Rp ${fmt.format(lk)}", style: const TextStyle(fontWeight: FontWeight.bold)), Text("Laba Bersih: Rp ${fmt.format(lb)}", style: TextStyle(fontWeight: FontWeight.bold, color: lb>=0?Colors.green:Colors.red)),
        ])),
        const SizedBox(height:8),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _simpan, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white), child: Text(editingId==null?"SIMPAN SIMULASI":"UPDATE"))),
      ])),
    );
  }
}