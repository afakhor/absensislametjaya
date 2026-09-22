import 'package:flutter/material.dart';
import '../export_pdf.dart';
import '../dbases/localdatabase.dart';
import '../dbases/laba_db.dart'; // untuk laba_page

class LabaPage extends StatefulWidget { const LabaPage({super.key}); @override State<LabaPage> createState() => _LabaPageState(); }
class _LabaPageState extends State<LabaPage> {
  final db = AppDatabase(); Map<String,int> laba = {};
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Laba Kotor & Bersih")), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("Beban Gaji Auto: Rp ${laba['bebanGaji']?? 0}"), Text("Laba Bersih: Rp ${laba['labaBersih']?? 0}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ElevatedButton(onPressed: () async { var h = await db.hitungLabaBulanan(DateTime.now()); setState(()=> laba = h); }, child: const Text("Hitung Laba")),
      ElevatedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text("CETAK PDF LABA"), onPressed: () async {
        var h = await db.hitungLabaBulanan(DateTime.now());
        var pendapatan = await (db.select(db.transaksi)..where((t) => t.jenis.equals('PENDAPATAN'))).get();
        var bebanOps = await (db.select(db.transaksi)..where((t) => t.jenis.equals('BEBAN_OPERASIONAL'))).get();
        var gajiBulan = await db.select(db.gajiMingguan).get();
        await ExportPdfTBSlametJaya.exportLaporanLaba(laba: h, bulan: DateTime.now(), pendapatanList: pendapatan, bebanOpsList: bebanOps, gajiBulanIni: gajiBulan);
      })
    ])));
  }
}