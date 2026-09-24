import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../dbases/localdatabase.dart';
import '../dbases/gaji_db.dart';
import '../export_pdf.dart';

class GajiPage extends StatefulWidget { const GajiPage({super.key}); @override State<GajiPage> createState() => _GajiPageState(); }

class _GajiPageState extends State<GajiPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  DateTime _bulan = DateTime.now();

  Color _warnaStatus(String s) {
    if (s == 'BELUM') return Colors.red.shade100;
    if (s == 'MINGGU1') return Colors.amber.shade100;
    return Colors.green.shade100;
  }
  Color _dotStatus(String s) {
    if (s == 'BELUM') return Colors.red;
    if (s == 'MINGGU1') return Colors.orange;
    return Colors.green;
  }

  @override void initState() { super.initState(); db.prosesHitungGajiMingguan(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gaji ${DateFormat('MMMM yyyy', 'id_ID').format(_bulan)}"),
        backgroundColor: Colors.brown.shade800, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: () async { final p = await showDatePicker(context: context, initialDate: _bulan, firstDate: DateTime(2023), lastDate: DateTime(2030)); if (p!= null) setState(() => _bulan = p); }),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () async { await db.prosesHitungGajiMingguan(); setState(() {}); })
        ],
      ),
      body: Column(children: [
        FutureBuilder<int>(
          future: db.getTotalGajianSemua(),
          builder: (c, s) => Container(
            width: double.infinity, padding: const EdgeInsets.all(16), color: Colors.orange.shade50,
            child: Column(children: [
              const Text("TOTAL GAJIAN SEMUA KARYAWAN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              Text("Rp ${fmt.format(s.data?? 0)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown.shade800)),
              const Text("Bonus Bintang: >=4.5=15% | >=4.0=10% | >=3.5=5%", style: TextStyle(fontSize: 9)),
            ]),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<GajiMingguanData>>(
            stream: (db.select(db.gajiMingguan)..orderBy([(t) => drift.OrderingTerm.desc(t.mingguMulai)])).watch(),
            builder: (c, s) {
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final filtered = s.data!.where((g) => g.mingguMulai.month == _bulan.month && g.mingguMulai.year == _bulan.year).toList();
              if (filtered.isEmpty) return const Center(child: Text("Belum ada gaji\nAbsen harian dulu, kasih bintang di Live"));
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  var g = filtered[i];
                  return FutureBuilder<KaryawanData?>(
                    future: (db.select(db.karyawan)..where((t) => t.id.equals(g.karyawanId))).getSingleOrNull(),
                    builder: (c, kar) {
                      return FutureBuilder<List<AbsensiData>>(
                        future: db.select(db.absensi).get().then((all) => all.where((a) => a.karyawanId == g.karyawanId && a.jamMasuk.isAfter(g.mingguMulai.subtract(const Duration(seconds: 1))) && a.jamMasuk.isBefore(g.mingguSelesai.add(const Duration(seconds: 1)))).toList()),
                        builder: (c, absSnap) {
                          final list = absSnap.data?? [];
                          final full = list.where((a) => a.tipeKerja == 'FULL').length;
                          final half = list.where((a) => a.tipeKerja == 'SETENGAH').length;
                          return FutureBuilder<double>(
                            future: db.getRataBintangMingguan(g.karyawanId, g.mingguMulai, g.mingguSelesai),
                            builder: (c, bintangSnap) {
                              final rataBintang = bintangSnap.data?? 0;
                              int bonusAuto = 0;
                              if (rataBintang >= 4.5) bonusAuto = (g.totalGajiPokok * 0.15).toInt();
                              else if (rataBintang >= 4.0) bonusAuto = (g.totalGajiPokok * 0.10).toInt();
                              else if (rataBintang >= 3.5) bonusAuto = (g.totalGajiPokok * 0.05).toInt();
                              return Card(
                                color: _warnaStatus(g.statusBayar),
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: ListTile(
                                  leading: Icon(Icons.circle, color: _dotStatus(g.statusBayar)),
                                  title: Text(kar.data?.nama?? "ID ${g.karyawanId}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text("${g.mingguMulai.day}/${g.mingguMulai.month}-${g.mingguSelesai.day}/${g.mingguSelesai.month} | ${g.totalHariEfektif} hari (Full:$full, ½:$half)"),
                                    Row(children: [const Icon(Icons.star, size: 14, color: Colors.amber), Text(" Rata Bintang: ${rataBintang.toStringAsFixed(1)} ⭐ | Auto: Rp ${fmt.format(bonusAuto)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]),
                                    Text("Pokok Rp ${fmt.format(g.totalGajiPokok)} + Bonus Rp ${fmt.format(g.bonusMingguan)} = Rp ${fmt.format(g.totalGaji)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ]),
                                  trailing: PopupMenuButton(
                                    onSelected: (v) async {
                                      if (v == 'bonus') {
                                        var ctrl = TextEditingController(text: g.bonusMingguan.toString());
                                        if (!mounted) return;
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: Text("Bonus Bintang ${rataBintang.toStringAsFixed(1)} Auto Rp ${fmt.format(bonusAuto)}"),
                                            content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Bonus Rp", border: OutlineInputBorder())),
                                            actions: [
                                              TextButton(onPressed: () async { await db.inputBonusMingguan(g.id, bonusAuto); if (context.mounted) Navigator.pop(context); }, child: Text("PAKAI AUTO ${fmt.format(bonusAuto)}")),
                                              TextButton(onPressed: () async { await db.inputBonusMingguan(g.id, int.tryParse(ctrl.text)?? 0); if (context.mounted) Navigator.pop(context); }, child: const Text("SIMPAN MANUAL")),
                                            ],
                                          ),
                                        );
                                      } else if (v == 'cetak') {
                                        final karyawan = kar.data; if (karyawan == null) return;
                                        final kategori = await (db.select(db.kategoriKaryawan)..where((t) => t.id.equals(karyawan.kategoriId))).getSingleOrNull(); if (kategori == null) return;
                                        await ExportPdfTBSlametJaya.exportSlipGajiMingguan(karyawan: karyawan, kategori: kategori, gaji: g, absensiMingguIni: list, rataBintang: rataBintang);
                                      } else {
                                        await db.tandaiBayar(g.id, v.toString());
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(value: 'bonus', child: Text("💰 Bonus Bintang ${rataBintang.toStringAsFixed(1)}")),
                                      const PopupMenuItem(value: 'BELUM', child: Text("🔴 Belum Terima")),
                                      const PopupMenuItem(value: 'MINGGU1', child: Text("🟡 Akumulasi 1 Minggu")),
                                      const PopupMenuItem(value: 'MINGGU2', child: Text("🟢 Lunas")),
                                      const PopupMenuItem(value: 'cetak', child: Text("🖨️ Cetak Slip PDF")),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}