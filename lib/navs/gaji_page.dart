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

  // State Filter Bulan (Header Ungu)
  DateTime _bulan = DateTime.now();

  // State Filter & Indexing Kombinasi
  List<int> _selectedKaryawanIds = []; // Multi-select karyawan
  List<String> _selectedStatusColors = []; // Multi-select warna: 'LUNAS', 'MINGGU1', 'BELUM'
  DateTimeRange? _selectedDateRange; // Filter rentang periode seminggu
  bool _sortByStarsDesc = false; // Indexing Bintang Banyak ke Sedikit

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
        return Colors.green; // 🟢 Hijau (Lunas)
      case 'MINGGU1':
        return Colors.orange; // 🟡 Kuning (1 Minggu / Partial)
      case 'BELUM':
      default:
        return Colors.red; // 🔴 Merah (Belum)
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

  // Dialog Edit/Input Bonus Mingguan (Warna Biru)
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
            mainAxisSize: MainAxisSize.min, // FIX 1: Diganti dari FullAxisSize.min
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

  // Bottom Sheet untuk Filter Multi-Indexing & Periode Seminggu dalam 1 Kali Pencarian
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
                              _selectedDateRange = null;
                              _sortByStarsDesc = false;
                            });
                            setState(() {});
                          },
                        )
                      ],
                    ),
                    const Divider(),

                    // 1. Filter Periode Seminggu
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

                    // 2. Indexing Warna Status (Merah, Kuning, Hijau)
                    const Text("Filter Warna Status:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
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
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. Indexing Karyawan (1 atau Lebih)
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

                    // 4. Indexing Bintang Paling Banyak ke Sedikit
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Urutkan Bintang Terbanyak -> Tersedikit", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
          // Header Informasi Ungu: Total Gajian Bulan Ini vs Kontinu Keseluruhan
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.brown.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Total Gajian Keseluruhan (Kontinu dari Awal s/d Saat Ini)
                    FutureBuilder<int>(
                      future: db.getTotalGajianSemua(),
                      builder: (c, s) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Total Kontinu (Awal - Saat ini):",
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
                    // Pemilih Bulan
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

                // BARIS FITUR FILTER & INDEXING KOMBINASI
                // Menentukan penyaringan data gaji berdasarkan input pengguna
                var filtered = allData.where((g) {
                  /* BARIS DITENTUKAN: PENYARINGAN FILTER PERIODE BULANAN/MINGGUAN */
                  // Jika filter date range diaktifkan, gunakan filter seminggu tersebut
                  if (_selectedDateRange != null) {
                    if (g.mingguMulai.isBefore(_selectedDateRange!.start) ||
                        g.mingguSelesai.isAfter(_selectedDateRange!.end)) {
                      return false;
                    }
                  } else {
                    // Default filter berdasarkan bulan header
                    if (g.mingguMulai.month != _bulan.month || g.mingguMulai.year != _bulan.year) {
                      return false;
                    }
                  }

                  // Filter Indexing Karyawan (1 atau Lebih)
                  if (_selectedKaryawanIds.isNotEmpty && !_selectedKaryawanIds.contains(g.karyawanId)) {
                    return false;
                  }

                  // Filter Indexing Status Warna (Merah / Kuning / Hijau)
                  if (_selectedStatusColors.isNotEmpty && !_selectedStatusColors.contains(g.statusBayar)) {
                    return false;
                  }

                  return true;
                }).toList();

                // Hitung Total Gajian Bulan Ini (Sesuai Filter Bulan)
                final totalGajiBulanIni = filtered.fold<int>(0, (sum, item) => sum + item.totalGaji);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      "Belum ada data gaji pada kriteria filter ini.\nLakukan absensi di Tab Live dahulu.",
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return StreamBuilder<List<KaryawanData>>(
                  stream: db.select(db.karyawan).watch(),
                  builder: (context, karSnap) {
                    final listKar = karSnap.data ?? [];

                    // Sorting Bintang jika diaktifkan
                    if (_sortByStarsDesc) {
                      filtered.sort((a, b) {
                        return b.totalGaji.compareTo(a.totalGaji);
                      });
                    }

                    return Column(
                      children: [
                        // Sub-header Info Total Gajian Bulan Ini (Ungu)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          color: Colors.purple.shade50,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total Gajian Bulan ${DateFormat('MMMM yyyy', 'id_ID').format(_bulan)}:",
                                style: TextStyle(fontSize: 12, color: Colors.purple.shade900, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                "Rp ${fmt.format(totalGajiBulanIni)}",
                                style: TextStyle(fontSize: 14, color: Colors.purple.shade900, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
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

                                          // WARNA BIRU: BONUS MINGGUAN (Dapat di-input tiap minggu)
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text("Bonus Mingguan (Input):",
                                                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                                              InkWell(
                                                onTap: () => _dialogBonus(context, g),
                                                child: Text(
                                                  "Rp ${fmt.format(g.bonusMingguan)}",
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration.none, // FIX 2: Diganti dari TextUnderline.none
                                                  ),
                                                ),
                                              ),
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
                                              // WARNA KUNING/PURPLE: REKOMENDASI/AKUMULASI STAR TIAN HARI
                                              FutureBuilder<double>(
                                                future: db.getRataBintangMingguan(g.karyawanId, g.mingguMulai, g.mingguSelesai),
                                                builder: (context, starSnap) {
                                                  final starVal = starSnap.data ?? 0.0;
                                                  return OutlinedButton.icon(
                                                    icon: const Icon(Icons.star, size: 16, color: Colors.orange),
                                                    label: Text(
                                                      "Akumulasi Star: ${starVal.toStringAsFixed(1)} ★",
                                                      style: const TextStyle(fontSize: 11, color: Colors.orange),
                                                    ),
                                                    onPressed: () => _dialogBonus(context, g),
                                                  );
                                                },
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
                          ),
                        ),
                      ],
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
