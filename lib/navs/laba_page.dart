import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../dbases/localdatabase.dart';
import '../dbases/laba_db.dart';

class LabaPage extends StatefulWidget {
  const LabaPage({super.key});

  @override
  State<LabaPage> createState() => _LabaPageState();
}

class _LabaPageState extends State<LabaPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  DateTime bulan = DateTime.now();

  void _pilihBulan() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: bulan,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: "PILIH BULAN & TAHUN",
    );
    if (picked != null) {
      setState(() {
        bulan = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rekap Laba Rugi & Analisis"),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Navigasi Bulan (Diselaraskan dengan Kalender Absensi)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.brown.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      bulan = DateTime(bulan.year, bulan.month - 1, 1);
                    });
                  },
                ),
                InkWell(
                  onTap: _pilihBulan,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 18, color: Colors.brown),
                        const SizedBox(width: 6),
                        Text(
                          "BULAN ${DateFormat('MMMM yyyy', 'id_ID').format(bulan).toUpperCase()}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      bulan = DateTime(bulan.year, bulan.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
          ),

          // Real-time FutureBuilder dengan Key berbasis Bulan
          Expanded(
            child: FutureBuilder<Map<String, int>>(
              key: ValueKey(bulan),
              future: db.hitungLabaBulanan(bulan),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Gagal memuat data: ${snapshot.error}"));
                }

                final data = snapshot.data ?? {
                  'pendapatan': 0,
                  'pemasukanLain': 0,
                  'bebanGaji': 0,
                  'bebanOps': 0,
                  'labaKotor': 0,
                  'labaBersih': 0,
                };

                final omset = data['pendapatan'] ?? 0;
                final pemasukanLain = data['pemasukanLain'] ?? 0;
                final totalPendapatan = omset + pemasukanLain;
                final bebanGaji = data['bebanGaji'] ?? 0;
                final bebanOps = data['bebanOps'] ?? 0;
                final totalBeban = bebanGaji + bebanOps;
                final labaKotor = data['labaKotor'] ?? 0;
                final labaBersih = data['labaBersih'] ?? 0;

                // Indikator & Metrik Analisis
                final npm = totalPendapatan > 0 ? ((labaBersih / totalPendapatan) * 100) : 0.0;
                final rasioGaji = totalPendapatan > 0 ? ((bebanGaji / totalPendapatan) * 100) : 0.0;
                final opexRatio = totalPendapatan > 0 ? ((bebanOps / totalPendapatan) * 100) : 0.0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // CARD 1: RINGKASAN LABA RUGI
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.analytics_outlined, color: Colors.purple.shade800),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Rincian Keuangan Bulanan",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _buildLabaRow("Pendapatan / Omset Penjualan", "Rp ${fmt.format(omset)}"),
                              _buildLabaRow("Pemasukan Lain-Lain", "Rp ${fmt.format(pemasukanLain)}"),
                              _buildLabaRow("Beban Gaji Karyawan", "Rp ${fmt.format(bebanGaji)}", color: Colors.red.shade700),
                              const Divider(),
                              _buildLabaRow("Laba Kotor Murni", "Rp ${fmt.format(labaKotor)}", color: Colors.purple.shade700, isBold: true),
                              _buildLabaRow("Beban Operasional Bulanan", "Rp ${fmt.format(bebanOps)}", color: Colors.red.shade700),
                              const Divider(thickness: 1.5),

                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: labaBersih >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: labaBersih >= 0 ? Colors.green.shade300 : Colors.red.shade300,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "TOTAL LABA BERSIH",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          "Rp ${fmt.format(labaBersih)}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: labaBersih >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Net Profit Margin (NPM):", style: TextStyle(fontSize: 12, color: Colors.black87)),
                                        Text("${npm.toStringAsFixed(1)} %",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // CARD 2: ANALISIS KESEHATAN FINANSIAL LEBIH LENGKAP
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.insights, color: Colors.brown.shade800),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Analisis Rasio Finansial",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),

                              // Metrik 1: Rasio Beban Gaji
                              _buildMetrikProgress(
                                title: "Porsi Beban Gaji / Omset",
                                value: "${rasioGaji.toStringAsFixed(1)}%",
                                progress: (rasioGaji / 100).clamp(0.0, 1.0),
                                color: rasioGaji > 30 ? Colors.orange : Colors.green,
                                subtitle: rasioGaji > 30 ? "Peringatan: Beban gaji > 30% omset" : "Sehat (Di bawah 30%)",
                              ),
                              const SizedBox(height: 14),

                              // Metrik 2: Operating Expense Ratio (OPEX)
                              _buildMetrikProgress(
                                title: "Rasio Beban Operasional (OPEX)",
                                value: "${opexRatio.toStringAsFixed(1)}%",
                                progress: (opexRatio / 100).clamp(0.0, 1.0),
                                color: opexRatio > 20 ? Colors.red : Colors.blue,
                                subtitle: opexRatio > 20 ? "Operasional cukup tinggi" : "Efisiensi operasional terjaga",
                              ),
                              const SizedBox(height: 14),

                              // Metrik 3: Total Cost Ratio vs Revenue
                              _buildMetrikProgress(
                                title: "Efisiensi Total Biaya",
                                value: totalPendapatan > 0
                                    ? "${((totalBeban / totalPendapatan) * 100).toStringAsFixed(1)}%"
                                    : "0%",
                                progress: totalPendapatan > 0 ? ((totalBeban / totalPendapatan) / 100).clamp(0.0, 1.0) : 0,
                                color: totalBeban > totalPendapatan ? Colors.red : Colors.teal,
                                subtitle: totalBeban > totalPendapatan ? "Pengeluaran melebihi pendapatan!" : "Pengeluaran terkendali",
                              ),

                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade400),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.lightbulb, size: 18, color: Colors.amber),
                                        SizedBox(width: 6),
                                        Text(
                                          "Rekomendasi Evaluasi Bisnis",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _generateRekomendasi(labaBersih, rasioGaji, opexRatio, totalPendapatan),
                                      style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabaRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? Colors.black)),
        ],
      ),
    );
  }

  Widget _buildMetrikProgress({
    required String title,
    required String value,
    required double progress,
    required Color color,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          color: color,
          minHeight: 6,
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
      ],
    );
  }

  String _generateRekomendasi(int labaBersih, double rasioGaji, double opexRatio, int totalPendapatan) {
    if (totalPendapatan == 0) {
      return "Belum ada transaksi pendapatan bulan ini. Lakukan pencatatan log transaksi atau laporan harian.";
    }
    if (labaBersih < 0) {
      return "Usaha mengalami kerugian bulan ini. Kurangi beban operasional dan tinjau penetapan margin keuntungan.";
    }
    if (rasioGaji > 35) {
      return "Beban gaji relatif tinggi dibanding pendapatan. Pertimbangkan peningkatkan target omset harian.";
    }
    if (labaBersih > 0 && rasioGaji <= 30) {
      return "Kondisi keuangan sehat! Tingkat rasio gaji dan margin laba bersih berada pada batas ideal.";
    }
    return "Keuangan stabil. Teruskan pemantauan beban operasional secara berkala.";
  }
}
