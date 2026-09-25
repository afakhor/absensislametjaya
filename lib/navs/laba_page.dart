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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            const SizedBox(height: 16),
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
                    'bebanGaji': 0,
                    'bebanOps': 0,
                    'labaKotor': 0,
                    'labaBersih': 0,
                  };

                  final labaKotor = data['labaKotor'] ?? 0;
                  final labaBersih = data['labaBersih'] ?? 0;

                  return Card(
                    elevation: 2,
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      children: [
                        ListTile(
                          title: const Text("Pendapatan"),
                          trailing: Text("Rp ${fmt.format(data['pendapatan'])}"),
                        ),
                        ListTile(
                          title: const Text("Beban Gaji"),
                          trailing: Text("Rp ${fmt.format(data['bebanGaji'])}"),
                        ),
                        const Divider(),
                        ListTile(
                          title: const Text("Laba Kotor", style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Text("Rp ${fmt.format(labaKotor)}", style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        ListTile(
                          title: const Text("Beban Operasional"),
                          trailing: Text("Rp ${fmt.format(data['bebanOps'])}"),
                        ),
                        const Divider(thickness: 1.5),
                        ListTile(
                          title: const Text("LABA BERSIH", style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text(
                            "Rp ${fmt.format(labaBersih)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: labaBersih >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
