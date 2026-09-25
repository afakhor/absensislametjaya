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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, int>>(
        future: db.hitungLabaBulanan(bulan),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text("REKAP LABA BULAN ${DateFormat('MMMM yyyy', 'id_ID').format(bulan)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(title: const Text("Total Pendapatan"), trailing: Text("Rp ${fmt.format(d['pendapatan'])}")),
                      ListTile(title: const Text("Beban Gaji"), trailing: Text("Rp ${fmt.format(d['bebanGaji'])}")),
                      ListTile(title: const Text("Beban Operasional"), trailing: Text("Rp ${fmt.format(d['bebanOps'])}")),
                      const Divider(),
                      ListTile(
                        title: const Text("LABA BERSIH", style: TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Text("Rp ${fmt.format(d['labaBersih'])}", style: TextStyle(fontWeight: FontWeight.bold, color: (d['labaBersih'] ?? 0) >= 0 ? Colors.green : Colors.red)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
