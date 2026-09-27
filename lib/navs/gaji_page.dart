import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column, Row;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'localdatabase.dart';
import 'gaji_db.dart';

class GajiPage extends StatefulWidget {
  const GajiPage({super.key});

  @override
  State<GajiPage> createState() => _GajiPageState();
}

class _GajiPageState extends State<GajiPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");

  DateTime _bulan = DateTime.now();
  final List<int> _selectedKaryawanIds = [];
  final List<String> _selectedStatusColors = [];
  bool _filterHanyaKasbon = false;

  DateTimeRange? _selectedDateRange;
  bool _sortByStarsDesc = false;
  bool _isLoadingProses = false;

  @override
  void initState() {
    super.initState();
    _refreshGajiData();
  }

  Future<void> _refreshGajiData() async {
    if (_isLoadingProses) return;
    setState(() => _isLoadingProses = true);
    try {
      await db.prosesHitungGajiMingguan();
    } catch (e) {
      debugPrint("Error kalkulasi gaji: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingProses = false);
      }
    }
  }

  Color _getWarnaStatus(String status) {
    switch (status) {
      case 'MINGGU2':
      case 'LUNAS':
        return Colors.green;
      case 'MINGGU1':
        return Colors.orange;
      case 'BELUM':
      default:
        return Colors.red;
    }
  }

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

  // --- GENERATE PDF SLIP GAJI ---
  Future<pw.Document> _generatePdfSlipGaji({
    required String namaKaryawan,
    required String periode,
    required int gajiPokok,
    required int bonus,
    required int kasbon,
    required int totalTerima,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            cross: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  "TB. SLAMET JAYA",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange800,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  "DUSUN JRANJANG RT 12/RW 6 KELURAHAN KERTOSUKO KECAMATAN KRUCIL KABUPATEN PROBOLINGGO (082229109246)",
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Nama:", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(namaKaryawan, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Periode:", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(periode, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Gaji Pokok", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text("Rp ${fmt.format(gajiPokok)}", style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Bonus Mingguan", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text("Rp ${fmt.format(bonus)}", style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Potongan Kasbon", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text("- Rp ${fmt.format(kasbon)}", style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL TERIMA:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Rp ${fmt.format(totalTerima)}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Tgl Terima:", style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 16),

              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  cross: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text("Bpk. Slamet", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 1),
                    pw.Text("CEO SLAMET JAYA", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> _shareSlipGajiWhatsApp({
    required String namaKaryawan,
    required String periode,
    required int gajiPokok,
    required int bonus,
    required int kasbon,
    required int totalTerima,
  }) async {
    final pdf = await _generatePdfSlipGaji(
      namaKaryawan: namaKaryawan,
      periode: periode,
      gajiPokok: gajiPokok,
      bonus: bonus,
      kasbon: kasbon,
      totalTerima: totalTerima,
    );

    final bytes = await pdf.save();
    final output = await getTemporaryDirectory();
    final filePath = "${output.path}/Slip_Gaji_${namaKaryawan.replaceAll(' ', '_')}.pdf";
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: "*SLIP GAJI TB. SLAMET JAYA*\nNama: $namaKaryawan\nPeriode: $periode\nTotal Diterima: Rp ${fmt.format(totalTerima)}",
    );
  }

  Future<void> _printSlipGajiStruk({
    required String namaKaryawan,
    required String periode,
    required int gajiPokok,
    required int bonus,
    required int kasbon,
    required int totalTerima,
  }) async {
    final pdf = await _generatePdfSlipGaji(
      namaKaryawan: namaKaryawan,
      periode: periode,
      gajiPokok: gajiPokok,
      bonus: bonus,
      kasbon: kasbon,
      totalTerima: totalTerima,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

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
          title: const Text("Input Bonus Mingguan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Akumulasi Rating Bintang: ${rataBintang.toStringAsFixed(1)} ★"),
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
                await _refreshGajiData();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  void _showFilterModal(List<KaryawanData> listKar) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Filter & Indexing Kombinasi",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            setModalState(() {
                              _selectedKaryawanIds.clear();
                              _selectedStatusColors.clear();
                              _filterHanyaKasbon = false;
                              _selectedDateRange = null;
                              _sortByStarsDesc = false;
                            });
                            setState(() {});
                          },
                        )
                      ],
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Filter Periode Seminggu", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(_selectedDateRange == null
                          ? "Semua Rentang Tanggal"
                          : "${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}"),
                      trailing: const Icon(Icons.date_range),
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() => _selectedDateRange = picked);
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text("Filter Warna Status & Warning:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text("🔴 Merah (Belum)"),
                          selected: _selectedStatusColors.contains('BELUM'),
                          onSelected: (val) {
                            setModalState(() {
                              val ? _selectedStatusColors.add('BELUM') : _selectedStatusColors.remove('BELUM');
                            });
                            setState(() {});
                          },
                        ),
                        FilterChip(
                          label: const Text("🟡 Kuning (1 Minggu)"),
                          selected: _selectedStatusColors.contains('MINGGU1'),
                          onSelected: (val) {
                            setModalState(() {
                              val ? _selectedStatusColors.add('MINGGU1') : _selectedStatusColors.remove('MINGGU1');
                            });
                            setState(() {});
                          },
                        ),
                        FilterChip(
                          label: const Text("🟢 Hijau (Lunas)"),
                          selected: _selectedStatusColors.contains('MINGGU2') || _selectedStatusColors.contains('LUNAS'),
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                _selectedStatusColors.add('MINGGU2');
                                _selectedStatusColors.add('LUNAS');
                              } else {
                                _selectedStatusColors.remove('MINGGU2');
                                _selectedStatusColors.remove('LUNAS');
                              }
                            });
                            setState(() {});
                          },
                        ),
                        FilterChip(
                          label: const Text("⚠️ Ada Kasbon", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                          selected: _filterHanyaKasbon,
                          selectedColor: Colors.amber.shade100,
                          onSelected: (val) {
                            setModalState(() {
                              _filterHanyaKasbon = val;
                            });
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("Filter Karyawan (Pilih 1 atau Lebih):", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: listKar.map((kar) {
                        final isSelected = _selectedKaryawanIds.contains(kar.id);
                        return FilterChip(
                          label: Text(kar.nama),
                          selected: isSelected,
                          onSelected: (val) {
                            setModalState(() {
                              val ? _selectedKaryawanIds.add(kar.id) : _selectedKaryawanIds.remove(kar.id);
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Urutkan Total Gaji Terbanyak", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: _sortByStarsDesc,
                      onChanged: (val) {
                        setModalState(() => _sortByStarsDesc = val);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade800),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Terapkan Filter", style: TextStyle(color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
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
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _refreshGajiData,
            tooltip: "Hitung Ulang Gaji",
          ),
          StreamBuilder<List<KaryawanData>>(
            stream: db.select(db.karyawan).watch(),
            builder: (context, snapshot) {
              return IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFilterModal(snapshot.data ?? []),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          if (_isLoadingProses)
            const LinearProgressIndicator(backgroundColor: Colors.purple, color: Colors.amber),
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
                        "Total Kontinu (Akumulasi):",
                        style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Rp ${fmt.format(s.data ?? 0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.purple,
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
          Expanded(
            child: StreamBuilder<List<GajiMingguanData>>(
              stream: (db.select(db.gajiMingguan)
                    ..orderBy([(t) => OrderingTerm.desc(t.mingguMulai)]))
                  .watch(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final allData = snap.data ?? [];

                var filtered = allData.where((g) {
                  if (_selectedDateRange != null) {
                    if (g.mingguMulai.isBefore(_selectedDateRange!.start) ||
                        g.mingguSelesai.isAfter(_selectedDateRange!.end)) {
                      return false;
                    }
                  } else {
                    bool matchMonth = (g.mingguMulai.month == _bulan.month && g.mingguMulai.year == _bulan.year) ||
                        (g.mingguSelesai.month == _bulan.month && g.mingguSelesai.year == _bulan.year);
                    if (!matchMonth) return false;
                  }

                  if (_selectedKaryawanIds.isNotEmpty && !_selectedKaryawanIds.contains(g.karyawanId)) {
                    return false;
                  }

                  if (_selectedStatusColors.isNotEmpty && !_selectedStatusColors.contains(g.statusBayar)) {
                    return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          "Belum ada data gaji pada kriteria filter (${DateFormat('MMM yyyy', 'id_ID').format(_bulan)}).",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _refreshGajiData,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Proses & Sinkronkan Gaji"),
                        )
                      ],
                    ),
                  );
                }

                return StreamBuilder<List<KaryawanData>>(
                  stream: db.select(db.karyawan).watch(),
                  builder: (context, karSnap) {
                    final listKar = karSnap.data ?? [];

                    if (_sortByStarsDesc) {
                      filtered.sort((a, b) => b.totalGaji.compareTo(a.totalGaji));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final g = filtered[i];
                        
                        KaryawanData? kar;
                        try {
                          kar = listKar.firstWhere((k) => k.id == g.karyawanId);
                        } catch (_) {
                          kar = null;
                        }

                        final colorStatus = _getWarnaStatus(g.statusBayar);
                        final namaKaryawan = kar?.nama ?? "Karyawan ID: ${g.karyawanId}";
                        final strPeriode = "${DateFormat('dd/MM').format(g.mingguMulai)} - ${DateFormat('dd/MM/yy').format(g.mingguSelesai)}";

                        return FutureBuilder<int>(
                          future: db.getKasbonPeriode(g.karyawanId, g.mingguMulai, g.mingguSelesai),
                          builder: (context, kasbonSnap) {
                            final kasbonPeriode = kasbonSnap.data ?? 0;
                            final totalTerimaBersih = g.totalGaji - kasbonPeriode;

                            if (_filterHanyaKasbon && kasbonPeriode <= 0) {
                              return const SizedBox.shrink();
                            }

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
                                title: Row(
                                  children: [
                                    Text(
                                      namaKaryawan,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (kasbonPeriode > 0) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.money_off, size: 16, color: Colors.red),
                                    ]
                                  ],
                                ),
                                subtitle: Text(
                                  "Periode: $strPeriode | ${g.totalHariEfektif} Hari",
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "Rp ${fmt.format(totalTerimaBersih)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: totalTerimaBersih >= 0 ? Colors.green : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorStatus.withAlpha(38),
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
                                            const Text("Bonus Mingguan:",
                                                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                                            InkWell(
                                              onTap: () => _dialogBonus(context, g),
                                              child: Text(
                                                "Rp ${fmt.format(g.bonusMingguan)}",
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Potongan Kasbon:",
                                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                                            Text(
                                              "- Rp ${fmt.format(kasbonPeriode)}",
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Total Diterima Bersih:", style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text(
                                              "Rp ${fmt.format(totalTerimaBersih)}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: totalTerimaBersih >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.print, color: Colors.blue),
                                                  tooltip: "Cetak Struk Thermal",
                                                  onPressed: () => _printSlipGajiStruk(
                                                    namaKaryawan: namaKaryawan,
                                                    periode: strPeriode,
                                                    gajiPokok: g.totalGajiPokok,
                                                    bonus: g.bonusMingguan,
                                                    kasbon: kasbonPeriode,
                                                    totalTerima: totalTerimaBersih,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.share, color: Colors.green),
                                                  tooltip: "Share WA (Slip Gaji)",
                                                  onPressed: () => _shareSlipGajiWhatsApp(
                                                    namaKaryawan: namaKaryawan,
                                                    periode: strPeriode,
                                                    gajiPokok: g.totalGajiPokok,
                                                    bonus: g.bonusMingguan,
                                                    kasbon: kasbonPeriode,
                                                    totalTerima: totalTerimaBersih,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            PopupMenuButton<String>(
                                              onSelected: (v) async {
                                                await db.tandaiBayar(g.id, v);
                                                setState(() {});
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
