import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../dbases/localdatabase.dart';
import '../dbases/gaji_db.dart';
import '../dbases/absen_db.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  DateTime nowLive = DateTime.now();
  Timer? timer;

  final penjualanC = TextEditingController(text: "0");
  final bebanOpsC = TextEditingController(text: "0");
  final tambahanC = TextEditingController(text: "0");
  final ketTambahanC = TextEditingController();

  DateTime bulan = DateTime.now();
  DateTime logMulai = DateTime.now().subtract(const Duration(days: 7));
  DateTime logSelesai = DateTime.now();
  Map<DateTime, List<AbsensiData>> absenPerTanggal = {};
  List<KaryawanData> allKaryawan = [];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => nowLive = DateTime.now());
    });
    _loadBulan();
  }

  @override
  void dispose() {
    timer?.cancel();
    penjualanC.dispose();
    bebanOpsC.dispose();
    tambahanC.dispose();
    ketTambahanC.dispose();
    super.dispose();
  }

  Future<void> _loadBulan() async {
    final listKar = await db.select(db.karyawan).get();
    final first = DateTime(bulan.year, bulan.month, 1);
    final last = DateTime(bulan.year, bulan.month + 1, 0, 23, 59, 59);
    final allAbsen = await db.select(db.absensi).get();
    final filtered = allAbsen
        .where((a) =>
            a.jamMasuk.isAfter(first.subtract(const Duration(seconds: 1))) &&
            a.jamMasuk.isBefore(last.add(const Duration(seconds: 1))))
        .toList();

    Map<DateTime, List<AbsensiData>> map = {};
    for (var a in filtered) {
      final d = DateTime(a.jamMasuk.year, a.jamMasuk.month, a.jamMasuk.day);
      map.putIfAbsent(d, () => []).add(a);
    }

    if (mounted) {
      setState(() {
        allKaryawan = listKar;
        absenPerTanggal = map;
      });
    }
  }

  int _parse(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  // Rating Bintang 1 Sampai 5
  Widget _bintangWidget(int karyawanId, int bintangSaatIni) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final idx = i + 1;
        return InkWell(
          onTap: () async {
            await db.setBintang(karyawanId, DateTime.now(), idx);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Icon(
              idx <= bintangSaatIni ? Icons.star : Icons.star_border,
              size: 24,
              color: Colors.amber.shade700,
            ),
          ),
        );
      }),
    );
  }

  Widget _liveTab() {
    final today = DateTime.now();
    return StreamBuilder<List<AbsensiData>>(
      stream: db.watchAbsensiHari(today),
      builder: (c, absSnap) {
        if (absSnap.hasError) {
          return Center(child: Text("Error Absensi: ${absSnap.error}"));
        }
        final absHariIni = absSnap.data ?? [];

        return StreamBuilder<List<KaryawanData>>(
          stream: db.select(db.karyawan).watch(),
          builder: (c, karSnap) {
            if (karSnap.hasError) {
              return Center(child: Text("Error Karyawan: ${karSnap.error}"));
            }
            if (!karSnap.hasData) return const Center(child: CircularProgressIndicator());
            final allKar = karSnap.data ?? [];
            if (allKar.isEmpty) {
              return const Center(
                child: Text(
                  "Belum ada Karyawan\nTambah di menu Owner dulu",
                  textAlign: TextAlign.center,
                ),
              );
            }

            final idsMasuk = absHariIni.map((e) => e.karyawanId).toSet();
            final bolong = allKar.where((k) => !idsMasuk.contains(k.id)).toList();
            final full = absHariIni.where((a) => a.tipeKerja == 'FULL').toList();
            final setengah = absHariIni.where((a) => a.tipeKerja == 'HALF' || a.tipeKerja == 'SETENGAH').toList();

            return StreamBuilder<List<BintangHarianData>>(
              stream: db.watchBintangHari(today),
              builder: (c, bintangSnap) {
                final mapB = {for (var b in bintangSnap.data ?? []) b.karyawanId: b.bintang};

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // Header Live Time
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.brown.shade800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${DateFormat('EEEE, dd MMM yyyy HH:mm:ss', 'id_ID').format(nowLive)} WIB - LIVE",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Card Status Absensi Karyawan
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "HADIR ${absHariIni.length}/${allKar.length} | BOLONG ${bolong.length}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Divider(),
                            if (full.isNotEmpty) ...[
                              const Text("✅ FULL (1 Hari):",
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ...full.map((a) {
                                final kar = allKar.where((k) => k.id == a.karyawanId).firstOrNull;
                                return ListTile(
                                  dense: true,
                                  title: Text(kar?.nama ?? "ID:${a.karyawanId}"),
                                  subtitle: Text(a.keterangan.isEmpty ? 'Hadir Full' : a.keterangan),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      await db.updateTipeAbsen(a.id, v);
                                      _loadBulan();
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'HALF', child: Text("Ubah ke ½ Hari")),
                                      const PopupMenuItem(value: 'FULL', child: Text("Tetap Full")),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            if (setengah.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text("🟡 ½ HARI:",
                                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                              ...setengah.map((a) {
                                final kar = allKar.where((k) => k.id == a.karyawanId).firstOrNull;
                                return ListTile(
                                  dense: true,
                                  title: Text(kar?.nama ?? "ID:${a.karyawanId}"),
                                  subtitle: Text(a.keterangan.isEmpty ? 'Hadir Half' : a.keterangan),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      await db.updateTipeAbsen(a.id, v);
                                      _loadBulan();
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'FULL', child: Text("Ubah ke Full")),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            if (bolong.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text("❌ BOLONG / BELUM ABSEN:",
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ...bolong.map((k) => ListTile(
                                    dense: true,
                                    title: Text(k.nama),
                                    subtitle: const Text("Belum ada catatan absen"),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Card Rating Bintang (1 - 5)
                    Card(
                      color: Colors.amber.shade50,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "⭐ RATING / PENILAIAN KARYAWAN HARI INI",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
                            ),
                            const Text(
                              "Bintang 1-5 akan terakumulasi di Halaman Gaji sebagai pertimbangan bonus.",
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const Divider(),
                            ...allKar.map((k) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(k.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text("Rating: ${mapB[k.id] ?? 0} Bintang"),
                                  trailing: _bintangWidget(k.id, mapB[k.id] ?? 0),
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Form Laporan Harian & Kalkulasi
                    StreamBuilder<LaporanHarianData?>(
                      stream: db.watchLaporanHari(today),
                      builder: (c, lapSnap) {
                        final lap = lapSnap.data;
                        if (lap != null && penjualanC.text == "0" && lap.totalPenjualan > 0) {
                          penjualanC.text = lap.totalPenjualan.toString();
                          bebanOpsC.text = lap.bebanOperasional.toString();
                          tambahanC.text = lap.tambahanLain.toString();
                          ketTambahanC.text = lap.keteranganTambahan;
                        }

                        return Card(
                          color: Colors.blue.shade50,
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "📝 LOG OMSET & OPERASIONAL HARIAN",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: penjualanC,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Total Penjualan / Omset (Rp)",
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: bebanOpsC,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Beban Operasional (Rp)",
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: tambahanC,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Pemasukan Tambahan (Rp)",
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: ketTambahanC,
                                  decoration: const InputDecoration(
                                    labelText: "Keterangan Tambahan",
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<int>(
                                  future: db.hitungGajiHariIni(today),
                                  builder: (c, gajiSnap) {
                                    final gajiHari = gajiSnap.data ?? 0;
                                    final jual = _parse(penjualanC.text);
                                    final beban = _parse(bebanOpsC.text);
                                    final tamb = _parse(tambahanC.text);
                                    final kotor = jual - beban;
                                    final bersih = kotor - gajiHari + tamb;

                                    return Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text("Total Gaji Hari Ini:"),
                                                  Text("Rp ${fmt.format(gajiHari)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text("Estimasi Laba Bersih:"),
                                                  Text(
                                                    "Rp ${fmt.format(bersih)}",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: bersih >= 0 ? Colors.green : Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 42,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.brown.shade800,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () async {
                                              await db.simpanLaporanHarian(
                                                today,
                                                jual,
                                                beban,
                                                tamb,
                                                ketTambahanC.text,
                                                gajiHari,
                                                kotor,
                                                bersih,
                                              );
                                              _loadBulan();
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Log Live Berhasil Disimpan")),
                                                );
                                              }
                                            },
                                            child: const Text("SIMPAN LOG LIVE", style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _logTab() {
    return Column(
      children: [
        Container(
          color: Colors.brown.shade50,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  onPressed: () async {
                    final p = await showDatePicker(
                        context: context,
                        initialDate: logMulai,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now());
                    if (p != null) setState(() => logMulai = p);
                  },
                  label: Text("Mulai: ${DateFormat('dd/MM/yy').format(logMulai)}"),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  onPressed: () async {
                    final p = await showDatePicker(
                        context: context,
                        initialDate: logSelesai,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now());
                    if (p != null) setState(() => logSelesai = p);
                  },
                  label: Text("Sampai: ${DateFormat('dd/MM/yy').format(logSelesai)}"),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<LaporanHarianData>>(
            stream: (db.select(db.laporanHarian)
                  ..orderBy([(t) => OrderingTerm.desc(t.tanggal)]))
                .watch(),
            builder: (c, snap) {
              if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final start = DateTime(logMulai.year, logMulai.month, logMulai.day);
              final end = DateTime(logSelesai.year, logSelesai.month, logSelesai.day, 23, 59, 59);

              final filtered = snap.data!
                  .where((l) =>
                      l.tanggal.isAfter(start.subtract(const Duration(seconds: 1))) &&
                      l.tanggal.isBefore(end.add(const Duration(seconds: 1))))
                  .toList();

              if (filtered.isEmpty) {
                return const Center(child: Text("Belum ada log di rentang tanggal ini."));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final l = filtered[i];
                  return Card(
                    child: ListTile(
                      title: Text(
                        DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(l.tanggal),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Penjualan: Rp ${fmt.format(l.totalPenjualan)}\nBeban Ops: Rp ${fmt.format(l.bebanOperasional)} | Gaji: Rp ${fmt.format(l.totalGajiHariIni)}",
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Laba Bersih", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            "Rp ${fmt.format(l.labaBersih)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: l.labaBersih >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _klikTanggal(DateTime tgl) async {
    final dayKey = DateTime(tgl.year, tgl.month, tgl.day);
    final absen = absenPerTanggal[dayKey] ?? [];
    final laporan = await (db.select(db.laporanHarian)
          ..where((t) => t.tanggal.equals(dayKey)))
        .getSingleOrNull();
    final bintang = await (db.select(db.bintangHarian)
          ..where((t) => t.tanggal.equals(dayKey)))
        .get();
    final idsMasuk = absen.map((e) => e.karyawanId).toSet();
    final bolong = allKaryawan.where((k) => !idsMasuk.contains(k.id)).toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("LOG ${DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(tgl)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            Text("Kehadiran: ${absen.length}/${allKaryawan.length} Karyawan (Bolong: ${bolong.length})"),
            if (bolong.isNotEmpty)
              Text("❌ Bolong: ${bolong.map((e) => e.nama).join(', ')}",
                  style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            Text("⭐ Bintang: ${bintang.isEmpty ? "Belum diisi" : bintang.map((b) => "ID ${b.karyawanId}: ${b.bintang}★").join(', ')}"),
            const Divider(),
            if (laporan != null) ...[
              Text("Penjualan: Rp ${fmt.format(laporan.totalPenjualan)}"),
              Text("Beban Ops: Rp ${fmt.format(laporan.bebanOperasional)}"),
              Text("Beban Gaji Hari Ini: Rp ${fmt.format(laporan.totalGajiHariIni)}"),
              const SizedBox(height: 4),
              Text(
                "Laba Bersih: Rp ${fmt.format(laporan.labaBersih)}",
                style: TextStyle(
                  color: laporan.labaBersih >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ] else
              const Text("Belum ada laporan operasional harian yang disimpan."),
          ],
        ),
      ),
    );
  }

  Widget _kalenderTab() {
    final firstDay = DateTime(bulan.year, bulan.month, 1);
    final daysInMonth = DateTime(bulan.year, bulan.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.brown.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() => bulan = DateTime(bulan.year, bulan.month - 1, 1));
                  _loadBulan();
                },
              ),
              Text(
                DateFormat('MMMM yyyy', 'id_ID').format(bulan).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() => bulan = DateTime(bulan.year, bulan.month + 1, 1));
                  _loadBulan();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.9,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (_, i) {
              if (i < startWeekday) return const SizedBox();
              final day = i - startWeekday + 1;
              final tgl = DateTime(bulan.year, bulan.month, day);
              final list = absenPerTanggal[DateTime(tgl.year, tgl.month, tgl.day)] ?? [];

              Color warna = Colors.red.shade200;
              if (list.isNotEmpty) {
                warna = (allKaryawan.isNotEmpty && list.length >= allKaryawan.length)
                    ? Colors.green.shade200
                    : Colors.yellow.shade200;
              }

              return GestureDetector(
                onTap: () => _klikTanggal(tgl),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("$day", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("${list.length}/${allKaryawan.length}", style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.brown.shade800,
          title: const Text("Dashboard Operasional", style: TextStyle(color: Colors.white)),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Live"),
              Tab(text: "Log"),
              Tab(text: "Absensi"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _liveTab(),
            _logTab(),
            _kalenderTab(),
          ],
        ),
      ),
    );
  }
}
