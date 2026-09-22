import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../export_pdf.dart';
import '../dbases/localdatabase.dart';
import '../dbases/laba_db.dart';

class LabaPage extends StatefulWidget { const LabaPage({super.key}); @override State<LabaPage> createState() => _LabaPageState(); }

class _LabaPageState extends State<LabaPage> {
  final db = AppDatabase();
  final omsetC = TextEditingController();
  final pemasukanLainC = TextEditingController(text: "0");
  final bebanOpsC = TextEditingController();
  final bebanLainC = TextEditingController(text: "0");
  final bebanGajiC = TextEditingController(text: "0");
  final catatanC = TextEditingController();

  DateTimeRange? periode;
  int? editingId;
  Map<String,int> labaCepat = {};
  final fmt = NumberFormat("#,###", "id_ID");
  int _parse(String s) => int.tryParse(s.replaceAll('.', '').replaceAll(',', '').replaceAll(' ', '')) ?? 0;

  Future<void> _pickPeriode() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(now.year-1,1,1), lastDate: DateTime(now.year+1,12,31), initialDateRange: periode ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now));
    if (picked != null) {
      setState(()=> periode = picked);
      int gaji = await db.hitungBebanGajiPeriode(picked.start, picked.end);
      setState(()=> bebanGajiC.text = gaji.toString());
    }
  }

  Future<void> _simpan() async {
    if (periode==null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih periode dulu"))); return; }
    int omset = _parse(omsetC.text); int pl = _parse(pemasukanLainC.text); int bo = _parse(bebanOpsC.text); int bl = _parse(bebanLainC.text); int bg = _parse(bebanGajiC.text);
    int totalPemasukan = omset + pl;
    int totalBeban = bo + bl + bg;
    int labaKotor = omset - bo; // Laba Kotor = Omset - Beban Operasional
    int labaBersih = totalPemasukan - totalBeban;

    final data = SimulasiLabaCompanion(
      periodeMulai: drift.Value(periode!.start),
      periodeSelesai: drift.Value(periode!.end),
      omset: drift.Value(omset),
      pemasukanLain: drift.Value(pl),
      bebanOperasional: drift.Value(bo),
      bebanLain: drift.Value(bl),
      bebanGaji: drift.Value(bg),
      totalPemasukan: drift.Value(totalPemasukan),
      totalBeban: drift.Value(totalBeban),
      labaKotor: drift.Value(labaKotor),
      labaBersih: drift.Value(labaBersih),
      catatan: drift.Value(catatanC.text),
      tanggalSimulasi: drift.Value(DateTime.now()),
    );
    if (editingId==null) await db.simpanSimulasi(data); else { await db.updateSimulasi(editingId!, data); editingId=null; }
    _clear();
  }

  void _clear() { setState(() { omsetC.clear(); pemasukanLainC.text="0"; bebanOpsC.clear(); bebanLainC.text="0"; bebanGajiC.text="0"; catatanC.clear(); periode=null; editingId=null; }); }
  void _edit(SimulasiLabaData d) { setState(() { editingId=d.id; periode=DateTimeRange(start: d.periodeMulai, end: d.periodeSelesai); omsetC.text=d.omset.toString(); pemasukanLainC.text=d.pemasukanLain.toString(); bebanOpsC.text=d.bebanOperasional.toString(); bebanLainC.text=d.bebanLain.toString(); bebanGajiC.text=d.bebanGaji.toString(); catatanC.text=d.catatan??""; }); }

  @override Widget build(BuildContext context) {
    int omset = _parse(omsetC.text); int pl = _parse(pemasukanLainC.text); int bo = _parse(bebanOpsC.text); int bl = _parse(bebanLainC.text); int bg = _parse(bebanGajiC.text);
    int totalP = omset + pl; int totalB = bo + bl + bg; int lk = omset - bo; int lb = totalP - totalB;
    return Scaffold(
      appBar: AppBar(title: const Text("Laba Kotor & Bersih - Kalkulator"), backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        // KODE LAMAMU TETAP ADA
        Card(color: Colors.blue.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          const Text("Hitung Cepat Bulan Ini (kode lama)", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("Beban Gaji Auto: Rp ${labaCepat['bebanGaji']??0}"), Text("Laba Bersih: Rp ${labaCepat['labaBersih']??0}", style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: () async { var h = await db.hitungLabaBulanan(DateTime.now()); setState(()=> labaCepat=h); }, child: const Text("Hitung Laba"))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text("PDF LABA"), onPressed: () async {
              var h = await db.hitungLabaBulanan(DateTime.now());
              var pendapatan = await (db.select(db.transaksi)..where((t)=> t.jenis.equals('PENDAPATAN'))).get();
              var bebanOps = await (db.select(db.transaksi)..where((t)=> t.jenis.equals('BEBAN_OPERASIONAL'))).get();
              var gajiBulan = await db.select(db.gajiMingguan).get();
              await ExportPdfTBSlametJaya.exportLaporanLaba(laba: h, bulan: DateTime.now(), pendapatanList: pendapatan, bebanOpsList: bebanOps, gajiBulanIni: gajiBulan);
            })),
          ])
        ]))),
        const Divider(),
        // KODE BARU KALKULATOR SIMULASI
        Text(editingId==null?"Simulasi Per Bulan / Periode":"Edit Simulasi #${editingId}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(onTap: _pickPeriode, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.date_range), const SizedBox(width: 8), Text(periode==null?"Pilih Periode Range": "${DateFormat('dd MMM yy').format(periode!.start)} - ${DateFormat('dd MMM yy').format(periode!.end)}")]))),
        const SizedBox(height: 8),
        _input(omsetC, "Omset (manual)"), _input(pemasukanLainC, "Pemasukan Lain-Lain (manual)"), _input(bebanOpsC, "Beban Operasional (manual)"), _input(bebanLainC, "Beban Lain (manual)"),
        TextField(controller: bebanGajiC, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Beban Gaji Karyawan (auto sesuai tanggal)", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.refresh), onPressed: () async { if(periode!=null){ int g=await db.hitungBebanGajiPeriode(periode!.start, periode!.end); setState(()=> bebanGajiC.text=g.toString()); } }))),
        const SizedBox(height: 8),
        TextField(controller: catatanC, decoration: const InputDecoration(labelText: "Catatan", border: OutlineInputBorder())),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Tanggal Simulasi: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}"), const Divider(),
          Text("Periode: ${periode==null?"-":"${DateFormat('dd/MM/yy').format(periode!.start)} - ${DateFormat('dd/MM/yy').format(periode!.end)}"}"),
          Text("Omset: Rp ${fmt.format(omset)}"), Text("Pemasukan Lain: Rp ${fmt.format(pl)}"),
          Text("Beban Operasional: Rp ${fmt.format(bo)}"), Text("Beban Lain: Rp ${fmt.format(bl)}"), Text("Beban Gaji: Rp ${fmt.format(bg)}", style: const TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          Text("Total Pemasukan: Rp ${fmt.format(totalP)}", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("Total Beban: Rp ${fmt.format(totalB)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          Text("Laba Kotor: Rp ${fmt.format(lk)}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
          Text("Laba Bersih: Rp ${fmt.format(lb)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: lb>=0?Colors.green:Colors.red)),
        ])),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.save), label: Text(editingId==null?"SIMPAN SIMULASI":"UPDATE SIMULASI"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white), onPressed: _simpan)),
        const Divider(),
        const Align(alignment: Alignment.centerLeft, child: Text("Log Hasil Simulasi:", style: TextStyle(fontWeight: FontWeight.bold))),
        StreamBuilder<List<SimulasiLabaData>>(stream: db.watchSimulasi(), builder: (c,s){
          if(!s.hasData) return const CircularProgressIndicator();
          if(s.data!.isEmpty) return const Text("Belum ada simulasi");
          return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: s.data!.length, itemBuilder: (_,i){
            var d=s.data![i];
            return Card(child: ListTile(
              title: Text("Periode ${DateFormat('dd MMM').format(d.periodeMulai)}-${DateFormat('dd MMM yy').format(d.periodeSelesai)} | Bersih Rp ${fmt.format(d.labaBersih)}", style: TextStyle(fontWeight: FontWeight.bold, color: d.labaBersih>=0?Colors.green:Colors.red)),
              subtitle: Text("Tgl Simulasi: ${DateFormat('dd/MM/yy HH:mm').format(d.tanggalSimulasi)}\nOmset:${fmt.format(d.omset)} + Lain:${fmt.format(d.pemasukanLain)} = Total ${fmt.format(d.totalPemasukan)}\nBeban Ops:${fmt.format(d.bebanOperasional)} + Lain:${fmt.format(d.bebanLain)} + Gaji:${fmt.format(d.bebanGaji)} = Total ${fmt.format(d.totalBeban)}\nLaba Kotor:${fmt.format(d.labaKotor)} | Laba Bersih:${fmt.format(d.labaBersih)}", style: const TextStyle(fontSize: 11)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: ()=>_edit(d)),
                IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.orange), onPressed: () async {
                  var h = {'pendapatan': d.totalPemasukan, 'bebanGaji': d.bebanGaji, 'bebanOps': d.bebanOperasional+d.bebanLain, 'labaKotor': d.labaKotor, 'labaBersih': d.labaBersih};
                  var pendapatan = await (db.select(db.transaksi)..where((t)=> t.jenis.equals('PENDAPATAN'))).get();
                  var bebanOps = await (db.select(db.transaksi)..where((t)=> t.jenis.equals('BEBAN_OPERASIONAL'))).get();
                  var gajiBulan = await (db.select(db.gajiMingguan)..where((t)=> t.mingguMulai.isBiggerOrEqualValue(d.periodeMulai) & t.mingguMulai.isSmallerOrEqualValue(d.periodeSelesai))).get();
                  await ExportPdfTBSlametJaya.exportLaporanLaba(laba: h, bulan: d.periodeMulai, pendapatanList: pendapatan, bebanOpsList: bebanOps, gajiBulanIni: gajiBulan);
                }),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: ()=>db.hapusSimulasi(d.id)),
              ]),
            ));
          });
        })
      ])),
    );
  }
  Widget _input(TextEditingController c, String label) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), onChanged: (_)=>setState((){})));
}