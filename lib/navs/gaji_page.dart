import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../export_pdf.dart';
import '../dbases/localdatabase.dart';
import '../dbases/gaji_db.dart';

class GajiPage extends StatefulWidget { 
  const GajiPage({super.key}); 
  @override State<GajiPage> createState() => _GajiPageState(); 
}

class _GajiPageState extends State<GajiPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  DateTime _bulan = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gaji ${DateFormat('MMMM yyyy').format(_bulan)}"),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: _bulan,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (p != null) setState(() => _bulan = p);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => db.prosesHitungGajiMingguan(),
          ),
        ],
      ),
      body: Column(
        children: [
          // TOTAL GAJIAN DI NAVIGASI GAJI - REQUIRED
          FutureBuilder<int>(
            future: db.getTotalGajianSemua(),
            builder: (c, s) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.orange.shade50,
              child: Column(
                children: [
                  const Text("TOTAL GAJIAN SEMUA KARYAWAN", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text("Rp ${fmt.format(s.data ?? 0)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                  const Text("Required: Gak absen = Gak gajian. 1 hari / ½ hari + bonus owner", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<GajiMingguanData>>(
              stream: (db.select(db.gajiMingguan)..orderBy([(t) => drift.OrderingTerm.desc(t.mingguMulai)])).watch(),
              builder: (c, s) {
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final filtered = s.data!.where((g) => g.mingguMulai.month == _bulan.month && g.mingguMulai.year == _bulan.year).toList();
                if (filtered.isEmpty) {
                  return Center(child: Text("Belum ada gaji di ${DateFormat('MMMM yyyy').format(_bulan)}\nAbsen wajib tiap hari dulu", textAlign: TextAlign.center));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    var g = filtered[i];
                    return FutureBuilder<KaryawanData?>(
                      future: (db.select(db.karyawan)..where((t) => t.id.equals(g.karyawanId))).getSingleOrNull(),
                      builder: (c, kar) {
                        return FutureBuilder<List<AbsensiData>>(
                          future: (db.select(db.absensi)..where((t) => t.karyawanId.equals(g.karyawanId) & t.jamMasuk.isBetweenValues(g.mingguMulai, g.mingguSelesai))).get(),
                          builder: (c, absSnap) {
                            final list = absSnap.data ?? [];
                            final full = list.where((a) => a.tipeKerja == 'FULL').length;
                            final half = list.where((a) => a.tipeKerja == 'SETENGAH').length;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                title: Text(kar.data?.nama ?? "ID ${g.karyawanId}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${g.mingguMulai.day}/${g.mingguMulai.month} - ${g.mingguSelesai.day}/${g.mingguSelesai.month} | Masuk ${g.totalHariMasuk} hari (Full:$full, ½:$half) - ${g.totalJam} jam"),
                                    Text("Bonus Rp ${fmt.format(g.totalBonus)} | Total Rp ${fmt.format(g.totalGaji)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(g.totalHariMasuk == 0 ? "❌ GAK ABSEN = GAK GAJIAN" : "✅ Required harian terpenuhi", style: TextStyle(fontSize: 11, color: g.totalHariMasuk == 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text("Rp ${fmt.format(g.totalGaji)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text("${g.totalJam} Jam", style: const TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                                      onPressed: () async {
                                        if (kar.data == null) return;
                                        var kat = await (db.select(db.kategoriKaryawan)..where((t) => t.id.equals(kar.data!.kategoriId))).getSingle();
                                        await ExportPdfTBSlametJaya.exportSlipGajiMingguan(karyawan: kar.data!, kategori: kat, gaji: g, absensiMingguIni: list);
                                      },
                                    ),
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
            ),
          ),
        ],
      ),
    );
  }
}