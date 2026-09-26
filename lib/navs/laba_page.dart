import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'localdatabase.dart';
import 'laba_db.dart';

class LabaPage extends StatefulWidget {
  const LabaPage({super.key});

  @override
  State<LabaPage> createState() => _LabaPageState();
}

class _LabaPageState extends State<LabaPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  DateTime bulan = DateTime.now();
  late Future<Map<String, int>> _labaFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _labaFuture = db.hitungLabaBulanan(bulan);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rekap Laba Rugi"),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Navigasi Bulan
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
                      _refreshData();
                    });
                  },
                ),
                Text(
                  "BULAN ${DateFormat('MMMM yyyy', 'id_ID').format(bulan).toUpperCase()}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      bulan = DateTime(bulan.year, bulan.month + 1, 1);
                      _refreshData();
                    });
                  },
                ),
              ],
            ),
          ),

          // Tampilan Laporan
          Expanded(
            child: FutureBuilder<Map<String, int>>(
              future: _labaFuture,
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

                final labaKotor = data['labaKotor'] ?? 0;
                final labaBersih = data['labaBersih'] ?? 0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 4,
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

                          _buildLabaRow("Pendapatan / Omset", "Rp ${fmt.format(data['pendapatan'])}"),
                          _buildLabaRow("Beban Gaji", "Rp ${fmt.format(data['bebanGaji'])}", color: Colors.red.shade700),
                          const Divider(),
                          _buildLabaRow("Laba Kotor (10%)", "Rp ${fmt.format(labaKotor)}", color: Colors.purple.shade700, isBold: true),
                          _buildLabaRow("Beban Operasional", "Rp ${fmt.format(data['bebanOps'])}", color: Colors.red.shade700),
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "LABA BERSIH",
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
                          ),
                        ],
                      ),
                    ),
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
}
