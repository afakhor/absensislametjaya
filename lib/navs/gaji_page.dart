import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../dbases/localdatabase.dart';
import '../dbases/gaji_db.dart';

class GajiPage extends StatefulWidget {
  const GajiPage({super.key});

  @override
  State<GajiPage> createState() => _GajiPageState();
}

class _GajiPageState extends State<GajiPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  DateTime _bulan = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      db.prosesHitungGajiMingguan().then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  // Menentukan Warna Badge Status Pembayaran (Hijau - Kuning - Merah)
  Color _getWarnaStatus(String status) {
    switch (status) {
      case 'MINGGU2':
      case 'LUNAS':
        return Colors.green; // 🟢 Lunas
      case 'MINGGU1':
        return Colors.orange; // 🟡 1 Minggu / Partial
      case 'BELUM':
      default:
        return Colors.red; // 🔴 Belum
    }
  }

  // Label Deskripsi Status
  String _getLabelStatus(String status) {
    switch (status) {
      case 'MINGGU2':
      case 'LUNAS':
        return '🟢 Lunas';
      case 'MINGGU1':
        return '🟡 1 Minggu';
      case 'BELUM':
      default:
        return '🔴 Belum';
    }
  }

  // Dialog Edit/Input Bonus dengan Rekomendasi Bintang
  void _dialogBonus(BuildContext context, GajiMingguanData g) async {
    final rataBintang = await db.getRataBintangMingguan(
      g.karyawanId,
      g.mingguMulai,
      g.mingguSelesai,
    );
    final bonusController = TextEditingController(text: g.bonusMingguan.toString());

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Input / Ubah Bonus"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Rata-rata Rating Bintang: ${rataBintang.toStringAsFixed(1)} ★"),
              const SizedBox(height: 4),
              Text(
                rataBintang >= 4.5
                    ? "Saran: Bonus 15% (Kinerja Sangat Baik)"
                    : rataBintang >= 4.0
                        ? "Saran: Bonus 10% (Kinerja Baik)"
                        : rataBintang >= 3.5
                            ? "Saran: Bonus 5% (Cukup Baik)"
                            : "Saran: Tanpa Bonus Khusus",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bonusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Nominal Bonus (Rp)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                final bonus = int.tryParse(bonusController.text) ?? 0;
                await db.inputBonusMingguan(g.id, bonus);
                if (mounted) setState(() {});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rekap Gaji Mingguan"),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Informasi Total Pengeluaran Gaji Bulan Ini & Filter Bulan
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.brown.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FutureBuilder<int>(
                  future: db.getTotalGajianSemua(),
                  builder: (c, s) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Gajian Keseluruhan:",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        "Rp ${fmt.format(s.data ?? 0)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.brown.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: () {
                        setState(() {
                          _bulan = DateTime(_bulan.year, _bulan.month - 1, 1);
                        });
                      },
                    ),
                    Text(
                      DateFormat('MMM yyyy', 'id_ID').format(_bulan),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: () {
                        setState(() {
                          _bulan = DateTime(_bulan.year, _bulan.month + 1, 1);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stream List Data Gaji Mingguan Karyawan
          Expanded(
            child: StreamBuilder<List<GajiMingguanData>>(
              stream: (db.select(db.gajiMingguan)
                    ..orderBy([(t) => OrderingTerm.desc(t.mingguMulai)]))
                  .watch(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final allData = snap.data ?? [];
                final filtered = allData
                    .where((g) =>
                        g.mingguMulai.month == _bulan.month &&
                        g.mingguMulai.year == _bulan.year)
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      "Belum ada data gaji pada bulan ini.\nLakukan absensi di Tab Live dahulu.",
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return StreamBuilder<List<KaryawanData>>(
                  stream: db.select(db.karyawan).watch(),
                  builder: (context, karSnap) {
                    final listKar = karSnap.data ?? [];

                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final g = filtered[i];
                        final kar = listKar.where((k) => k.id == g.karyawanId).firstOrNull;
                        final colorStatus = _getWarnaStatus(g.statusBayar);

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: ExpansionTile(
                            leading: Container(
                              width: 12,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colorStatus,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            title: Text(
                              kar?.nama ?? "Karyawan ID: ${g.karyawanId}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Periode: ${DateFormat('dd/MM').format(g.mingguMulai)} - ${DateFormat('dd/MM/yy').format(g.mingguSelesai)} | ${g.totalHariEfektif} Hari Efektif",
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "Rp ${fmt.format(g.totalGaji)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorStatus.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: colorStatus, width: 0.8),
                                  ),
                                  child: Text(
                                    _getLabelStatus(g.statusBayar),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: colorStatus,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Gaji Pokok:"),
                                        Text("Rp ${fmt.format(g.totalGajiPokok)}"),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Bonus Mingguan:"),
                                        Text("Rp ${fmt.format(g.bonusMingguan)}"),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Total Diterima:"),
                                        Text(
                                          "Rp ${fmt.format(g.totalGaji)}",
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.star, size: 16),
                                          label: const Text("Edit Bonus (Saran ★)", style: TextStyle(fontSize: 11)),
                                          onPressed: () => _dialogBonus(context, g),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (v) async {
                                            await db.tandaiBayar(g.id, v);
                                            if (mounted) setState(() {});
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'BELUM',
                                              child: Text("🔴 Belum (Merah)"),
                                            ),
                                            const PopupMenuItem(
                                              value: 'MINGGU1',
                                              child: Text("🟡 1 Minggu (Kuning)"),
                                            ),
                                            const PopupMenuItem(
                                              value: 'MINGGU2',
                                              child: Text("🟢 Lunas (Hijau)"),
                                            ),
                                          ],
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.brown.shade800,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "Ubah Status",
                                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                                ),
                                                Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
