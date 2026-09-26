import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'localdatabase.dart';
import 'gaji_db.dart';

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

  // Controllers Input Harian
  final omsetC = TextEditingController(text: "0");
  final cashC = TextEditingController(text: "0");
  final namaPelangganC = TextEditingController();
  final pemLainC = TextEditingController(text: "0");
  final ketPemLainC = TextEditingController();
  final bebanOpsC = TextEditingController(text: "0");
  final kasbonC = TextEditingController(text: "0");
  final piutangKemarinC = TextEditingController(text: "0");

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
    omsetC.dispose();
    cashC.dispose();
    namaPelangganC.dispose();
    pemLainC.dispose();
    ketPemLainC.dispose();
    bebanOpsC.dispose();
    kasbonC.dispose();
    piutangKemarinC.dispose();
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
      stream: (db.select(db.absensi)
            ..where((t) => t.jamMasuk.isBiggerOrEqualValue(DateTime(today.year, today.month, today.day)))
            ..where((t) => t.jamMasuk.isSmallerOrEqualValue(DateTime(today.year, today.month, today.day, 23, 59, 59))))
          .watch(),
      builder: (c, absSnap) {
        final absHariIni = absSnap.data ?? [];

        return StreamBuilder<List<KaryawanData>>(
          stream: db.select(db.karyawan).watch(),
          builder: (c, karSnap) {
            if (!karSnap.hasData) return const Center(child: CircularProgressIndicator());
            final allKar = karSnap.data ?? [];

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
                              const Text("✅ FULL (1 Hari):", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ...full.map((a) {
                                final kar = allKar.where((k) => k.id == a.karyawanId).firstOrNull;
                                return ListTile(
                                  dense: true,
                                  title: Text(kar?.nama ?? "ID:${a.karyawanId}"),
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
                              const Text("🟡 ½ HARI:", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                              ...setengah.map((a) {
                                final kar = allKar.where((k) => k.id == a.karyawanId).firstOrNull;
                                return ListTile(
                                  dense: true,
                                  title: Text(kar?.nama ?? "ID:${a.karyawanId}"),
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Card(
                      color: Colors.amber.shade50,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("⭐ RATING KARYAWAN HARI INI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                            const Divider(),
                            ...allKar.map((k) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(k.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  trailing: _bintangWidget(k.id, mapB[k.id] ?? 0),
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    StreamBuilder<LaporanHarianData?>(
                      stream: db.watchLaporanHari(today),
                      builder: (c, lapSnap) {
                        final lap = lapSnap.data;
                        if (lap != null && omsetC.text == "0" && lap.totalPenjualan > 0) {
                          omsetC.text = lap.totalPenjualan.toString();
                          cashC.text = lap.cash.toString();
                          namaPelangganC.text = lap.namaPelangganBon;
                          pemLainC.text = lap.tambahanLain.toString();
                          ketPemLainC.text = lap.keteranganTambahan;
                          bebanOpsC.text = lap.bebanOperasional.toString();
                          kasbonC.text = lap.kasbonKaryawan.toString();
                          piutangKemarinC.text = lap.saldoPiutangKemarin.toString();
                        }

                        return Card(
                          color: Colors.blue.shade50,
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("FORMAT HARIAN TB. SLAMET JAYA (MARGIN 10%)",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                                const Divider(),

                                const Text("A. Omset Hari Ini", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                _buildField("Omset Hari Ini (Total Jual)", omsetC),
                                _buildField("Cash (Tunai Hari Ini)", cashC),
                                _buildField("Nama Pelanggan Bon", namaPelangganC, isNum: false),

                                const SizedBox(height: 10),
                                const Text("B. Pemasukan Lainnya", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                _buildField("Pemasukan Lainnya (Rp)", pemLainC),
                                _buildField("Keterangan", ketPemLainC, isNum: false),

                                const SizedBox(height: 10),
                                const Text("C. Beban", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                _buildField("Beban Operasional", bebanOpsC),
                                _buildField("Kasbon / Piutang Karyawan", kasbonC),

                                const SizedBox(height: 10),
                                const Text("D. Saldo Piutang Kemarin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                _buildField("Total Saldo Piutang Kemarin", piutangKemarinC),

                                const SizedBox(height: 12),
                                FutureBuilder<int>(
                                  future: db.hitungGajiHariIni(today),
                                  builder: (c, gajiSnap) {
                                    final bebanGaji = gajiSnap.data ?? 0;
                                    final omset = _parse(omsetC.text);
                                    final cash = _parse(cashC.text);
                                    final pemLain = _parse(pemLainC.text);
                                    final bebanOps = _parse(bebanOpsC.text);
                                    final kasbon = _parse(kasbonC.text);
                                    final piutangKemarin = _parse(piutangKemarinC.text);

                                    // Kalkulasi Sesuai Rumus
                                    final labaKotor = (omset * 0.10).round();
                                    final labaBersih = labaKotor + pemLain - bebanGaji - bebanOps;
                                    final kasHariIni = cash + pemLain - bebanGaji - bebanOps - kasbon;
                                    final piutangBaru = omset - cash;
                                    final sisaPiutangLama = piutangKemarin - pemLain;
                                    final totalPiutangAkhir = sisaPiutangLama + piutangBaru;

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.purple.shade200),
                                      ),
                                      child: Column(
                                        children: [
                                          _buildRow("E. Laba Kotor (10%)", "Rp ${fmt.format(labaKotor)}", Colors.purple.shade900),
                                          _buildRow("F. LABA BERSIH", "Rp ${fmt.format(labaBersih)}",
                                              labaBersih >= 0 ? Colors.green.shade700 : Colors.red.shade700, isBold: true),
                                          const Divider(),
                                          _buildRow("G. KAS HARI INI (Di Laci)", "Rp ${fmt.format(kasHariIni)}", Colors.blue.shade900, isBold: true),
                                          const Divider(),
                                          _buildRow("Piutang Baru Hari Ini", "Rp ${fmt.format(piutangBaru)}", Colors.orange.shade800),
                                          _buildRow("Sisa Piutang Lama", "Rp ${fmt.format(sisaPiutangLama)}", Colors.orange.shade800),
                                          _buildRow("H. TOTAL PIUTANG AKHIR", "Rp ${fmt.format(totalPiutangAkhir)}", Colors.red.shade900, isBold: true),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 44,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.brown.shade800,
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () async {
                                                await db.simpanLaporanHarianFull(
                                                  tgl: today,
                                                  omset: omset,
                                                  cash: cash,
                                                  piutangBaru: piutangBaru,
                                                  namaPelanggan: namaPelangganC.text,
                                                  pemLain: pemLain,
                                                  ketPemLain: ketPemLainC.text,
                                                  bebanGaji: bebanGaji,
                                                  bebanOps: bebanOps,
                                                  kasbon: kasbon,
                                                  piutangKemarin: piutangKemarin,
                                                  labaKotor: labaKotor,
                                                  labaBersih: labaBersih,
                                                  kasHariIni: kasHariIni,
                                                  totalPiutangAkhir: totalPiutangAkhir,
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
                                      ),
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

  Widget _buildField(String label, TextEditingController controller, {bool isNum = true}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: controller,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildRow(String label, String val, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
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
                    final p = await showDatePicker(context: context, initialDate: logMulai, firstDate: DateTime(2023), lastDate: DateTime.now());
                    if (p != null) setState(() => logMulai = p);
                  },
                  label: Text("Mulai: ${DateFormat('dd/MM/yy').format(logMulai)}"),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  onPressed: () async {
                    final p = await showDatePicker(context: context, initialDate: logSelesai, firstDate: DateTime(2023), lastDate: DateTime.now());
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
            stream: (db.select(db.laporanHarian)..orderBy([(t) => OrderingTerm.desc(t.tanggal)])).watch(),
            builder: (c, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final start = DateTime(logMulai.year, logMulai.month, logMulai.day);
              final end = DateTime(logSelesai.year, logSelesai.month, logSelesai.day, 23, 59, 59);

              final filtered = snap.data!
                  .where((l) => l.tanggal.isAfter(start.subtract(const Duration(seconds: 1))) && l.tanggal.isBefore(end.add(const Duration(seconds: 1))))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final l = filtered[i];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(l.tanggal),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text("Laba Bersih: Rp ${fmt.format(l.labaBersih)}",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: l.labaBersih >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
                            ],
                          ),
                          const Divider(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Penjualan: Rp ${fmt.format(l.totalPenjualan)}", style: const TextStyle(fontSize: 11)),
                              Text("Beban Ops: Rp ${fmt.format(l.bebanOperasional)} | Gaji: Rp ${fmt.format(l.totalGajiHariIni)}",
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                            ],
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
    final laporan = await (db.select(db.laporanHarian)..where((t) => t.tanggal.equals(dayKey))).getSingleOrNull();
    final bintang = await (db.select(db.bintangHarian)..where((t) => t.tanggal.equals(dayKey))).get();
    final idsMasuk = absen.map((e) => e.karyawanId).toSet();
    final bolong = allKaryawan.where((k) => !idsMasuk.contains(k.id)).toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("LOG ${DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(tgl)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text("Kehadiran: ${absen.length}/${allKaryawan.length} Karyawan (Bolong: ${bolong.length})",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            if (bintang.isNotEmpty) Text("⭐ Bintang: ${bintang.map((b) => "ID ${b.karyawanId}: ${b.bintang}★").join(', ')}", style: const TextStyle(fontSize: 11)),
            const Divider(),
            if (laporan != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _buildRow("Penjualan", "Rp ${fmt.format(laporan.totalPenjualan)}", Colors.black),
                    _buildRow("Beban Ops", "Rp ${fmt.format(laporan.bebanOperasional)}", Colors.black),
                    _buildRow("Beban Gaji Hari Ini", "Rp ${fmt.format(laporan.totalGajiHariIni)}", Colors.black),
                    const Divider(),
                    _buildRow("Laba Bersih", "Rp ${fmt.format(laporan.labaBersih)}", laporan.labaBersih >= 0 ? Colors.green.shade700 : Colors.red.shade700, isBold: true),
                  ],
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
              Text(DateFormat('MMMM yyyy', 'id_ID').format(bulan).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.9),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (_, i) {
              if (i < startWeekday) return const SizedBox();
              final day = i - startWeekday + 1;
              final tgl = DateTime(bulan.year, bulan.month, day);
              final list = absenPerTanggal[DateTime(tgl.year, tgl.month, tgl.day)] ?? [];

              Color warna = Colors.red.shade200;
              if (list.isNotEmpty) {
                warna = (allKaryawan.isNotEmpty && list.length >= allKaryawan.length) ? Colors.green.shade200 : Colors.yellow.shade200;
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
