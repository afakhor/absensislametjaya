import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../dbases/localdatabase.dart';
import '../dbases/gaji_db.dart';
import '../dbases/absen_db.dart'; // FIX: Tambahkan import absen_db.dart

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

  Widget _bintangWidget(int karyawanId, int bintangSaatIni) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final idx = i + 1;
        return InkWell(
          onTap: () async => await db.setBintang(karyawanId, DateTime.now(), idx),
          child: Icon(idx <= bintangSaatIni ? Icons.star : Icons.star_border,
              size: 20, color: Colors.amber.shade700),
        );
      }),
    );
  }

  Widget _liveTab() {
    final today = DateTime.now();
    return StreamBuilder<List<AbsensiData>>(
      stream: db.watchAbsensiHari(today),
      builder: (c, absSnap) {
        final absHariIni = absSnap.data ?? [];
        return StreamBuilder<List<KaryawanData>>(
          stream: db.select(db.karyawan).watch(),
          builder: (c, karSnap) {
            if (!karSnap.hasData) return const Center(child: CircularProgressIndicator());
            final allKar = karSnap.data ?? [];
            if (allKar.isEmpty) {
              return const Center(child: Text("Belum ada Karyawan\nTambah di menu Owner dulu"));
            }

            final idsMasuk = absHariIni.map((e) => e.karyawanId).toSet();
            final bolong = allKar.where((k) => !idsMasuk.contains(k.id)).toList();
            final full = absHariIni.where((a) => a.tipeKerja == 'FULL').toList();
            final setengah = absHariIni.where((a) => a.tipeKerja == 'SETENGAH').toList();

            return StreamBuilder<List<BintangHarianData>>(
              stream: db.watchBintangHari(today),
              builder: (c, bintangSnap) {
                final mapB = {for (var b in bintangSnap.data ?? []) b.karyawanId: b.bintang};
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.brown.shade800,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          "${DateFormat('EEEE, dd MMM yyyy HH:mm:ss', 'id_ID').format(nowLive)} WIB - LIVE",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("HADIR ${absHariIni.length}/${allKar.length} | BOLONG ${bolong.length}"),
                              const Divider(),
                              if (full.isNotEmpty) ...[
                                const Text("✅ FULL:",
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ...full.map((a) {
                                  final kar = allKar.where((k) => k.id == a.karyawanId).firstOrNull;
                                  return ListTile(
                                    dense: true,
                                    title: Text(kar?.nama ?? "ID:${a.karyawanId}"),
                                    subtitle: Text(a.keterangan),
                                    trailing: PopupMenuButton(
                                      onSelected: (v) async {
                                        await db.updateTipeAbsen(a.id, v.toString());
                                        _loadBulan();
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'SETENGAH', child: Text("Jadi ½")),
                                        const PopupMenuItem(value: 'FULL', child: Text("Tetap Full")),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              if (setengah.isNotEmpty) ...[
                                const Text("🟡 ½ HARI:",
                                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                ...setengah.map((a) {
                                  final kar = allKar.where((k) => k.id == a.karyawanId).firstOrNull;
                                  return ListTile(
                                    dense: true,
                                    title: Text(kar?.nama ?? "ID:${a.karyawanId}"),
                                    trailing: PopupMenuButton(
                                      onSelected: (v) async {
                                        await db.updateTipeAbsen(a.id, v.toString());
                                        _loadBulan();
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'FULL', child: Text("Jadi FULL")),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              if (bolong.isNotEmpty) ...[
                                const Text("❌ BOLONG:",
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ...bolong.map((k) => ListTile(
                                    dense: true,
                                    title: Text(k.nama),
                                    subtitle: const Text("Belum absen"))),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Card(
                        color: Colors.amber.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Text("⭐ BINTANG HARI INI",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              ...allKar.map((k) => ListTile(
                                  dense: true,
                                  title: Text(k.nama),
                                  trailing: _bintangWidget(k.id, mapB[k.id] ?? 0))),
                            ],
                          ),
                        ),
                      ),
                      StreamBuilder<LaporanHarianData?>(
                        stream: db.watchLaporanHari(today),
                        builder: (c, lapSnap) {
                          return Card(
                            color: Colors.blue.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  TextField(
                                      controller: penjualanC,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: "Penjualan Rp")),
                                  TextField(
                                      controller: bebanOpsC,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: "Beban Ops Rp")),
                                  TextField(
                                      controller: tambahanC,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: "Tambahan Rp")),
                                  TextField(
                                      controller: ketTambahanC,
                                      decoration: const InputDecoration(labelText: "Keterangan")),
                                  const SizedBox(height: 8),
                                  FutureBuilder<int>(
                                    future: db.hitungGajiHariIni(today),
                                    builder: (c, gajiSnap) {
                                      final gajiHari = gajiSnap.data ?? 0;
                                      final jual = _parse(penjualanC.text);
                                      final beban = _parse(bebanOpsC.text);
                                      final bersih = jual - beban - gajiHari + _parse(tambahanC.text);
                                      return Column(
                                        children: [
                                          Text(
                                            "Gaji Hari Ini Rp ${fmt.format(gajiHari)} | Bersih Rp ${fmt.format(bersih)}",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: bersih >= 0 ? Colors.green : Colors.red),
                                          ),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                await db.simpanLaporanHarian(
                                                    today,
                                                    jual,
                                                    beban,
                                                    _parse(tambahanC.text),
                                                    ketTambahanC.text,
                                                    gajiHari,
                                                    jual - beban,
                                                    bersih);
                                                _loadBulan();
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text("Log Disimpan")));
                                                }
                                              },
                                              child: const Text("SIMPAN LOG LIVE"),
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
                  ),
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
                child: TextButton(
                  onPressed: () async {
                    final p = await showDatePicker(
                        context: context,
                        initialDate: logMulai,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now());
                    if (p != null) setState(() => logMulai = p);
                  },
                  child: Text("Mulai ${DateFormat('dd/MM/yy').format(logMulai)}"),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final p = await showDatePicker(
                        context: context,
                        initialDate: logSelesai,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now());
                    if (p != null) setState(() => logSelesai = p);
                  },
                  child: Text("Sampai ${DateFormat('dd/MM/yy').format(logSelesai)}"),
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
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final start = DateTime(logMulai.year, logMulai.month, logMulai.day);
              final end = DateTime(logSelesai.year, logSelesai.month, logSelesai.day, 23, 59, 59);

              final filtered = snap.data!
                  .where((l) =>
                      l.tanggal.isAfter(start.subtract(const Duration(seconds: 1))) &&
                      l.tanggal.isBefore(end.add(const Duration(seconds: 1))))
                  .toList();
              if (filtered.isEmpty) return const Center(child: Text("Belum ada log di range ini"));

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final l = filtered[i];
                  return Card(
                    child: ListTile(
                      title: Text(DateFormat('dd MMM yyyy').format(l.tanggal)),
                      subtitle: Text(
                          "Jual ${fmt.format(l.totalPenjualan)} | Bersih ${fmt.format(l.labaBersih)} | Gaji ${fmt.format(l.totalGajiHariIni)}"),
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
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("LOG ${DateFormat('dd MMM yyyy').format(tgl)}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Text("Masuk ${absen.length}/${allKaryawan.length} | Bolong ${bolong.length}"),
            if (bolong.isNotEmpty) Text("❌ ${bolong.map((e) => e.nama).join(', ')}"),
            Text(
                "⭐ ${bintang.isEmpty ? "Belum ada" : bintang.map((b) => "${b.karyawanId}:${b.bintang}").join(', ')}"),
            if (laporan != null) ...[
              Text("Jual Rp ${fmt.format(laporan.totalPenjualan)}"),
              Text("Bersih Rp ${fmt.format(laporan.labaBersih)}",
                  style: TextStyle(
                      color: laporan.labaBersih >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold)),
            ] else
              const Text("Belum ada laporan"),
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
              Text(DateFormat('MMMM yyyy', 'id_ID').format(bulan),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.9),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (_, i) {
              if (i < startWeekday) return const SizedBox();
              final day = i - startWeekday + 1;
              final tgl = DateTime(bulan.year, bulan.month, day);
              final list = absenPerTanggal[DateTime(tgl.year, tgl.month, tgl.day)] ?? [];
              final warna = list.isEmpty
                  ? Colors.red.shade200
                  : (allKaryawan.isNotEmpty && list.length >= allKaryawan.length
                      ? Colors.green.shade200
                      : Colors.yellow.shade200);

              return GestureDetector(
                onTap: () => _klikTanggal(tgl),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("$day", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("${list.length}/${allKaryawan.length}", style: const TextStyle(fontSize: 9)),
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
        body: Column(
          children: [
            Container(
              color: Colors.brown.shade800,
              child: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [Tab(text: "Live"), Tab(text: "Log"), Tab(text: "Absensi")],
              ),
            ),
            Expanded(child: TabBarView(children: [_liveTab(), _logTab(), _kalenderTab()])),
          ],
        ),
      ),
    );
  }
}
