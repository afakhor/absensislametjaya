import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column, Row;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../dbases/localdatabase.dart';
import '../dbases/gaji_db.dart';

extension AppDatabaseKasbonFix on AppDatabase {
  Future<void> inputPotonganKasbon(int karyawanId, DateTime tgl, int nominal) async {
    if (nominal < 0) nominal = 0;
    await simpanKasbonHarian(karyawanId, tgl, nominal, "Kasbon via GajiPage");
  }
}

class GajiPage extends StatefulWidget {
  const GajiPage({super.key});
  @override State<GajiPage> createState() => _GajiPageState();
}

class _GajiPageState extends State<GajiPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  final List<int> _selectedKaryawanIds = [];
  final List<String> _selectedStatusColors = [];
  bool _filterHanyaKasbon = false, _filterTanpaKasbon = false, _filterHanyaBonus = false, _filterTanpaBonus = false;
  DateTimeRange? _selectedDateRange;
  bool _sortByTerbanyak = false, _isLoading = false;

  static const caramel = Color(0xFFA87336);
  static const coffee = Color(0xFF613A1E);
  static const espresso = Color(0xFF4E2D17);
  static const roast = Color(0xFF3B2011);

  @override void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try { await db.prosesHitungGajiMingguan(); } catch (e) { debugPrint("$e"); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  Color _warna(String s) {
    switch (s) {
      case 'BELUM_GAJIAN': case 'BELUM': return caramel;
      case '1 MINGGU': case 'MINGGU1': return coffee;
      case '2 MINGGU': case 'MINGGU2': return espresso;
      case 'LUNAS': return roast;
      default: return caramel;
    }
  }
  Color _text(Color bg) => bg == caramel ? roast : Colors.white;
  String _label(String s) {
    switch (s) {
      case 'BELUM_GAJIAN': case 'BELUM': return 'BELUM GAJIAN';
      case '1 MINGGU': case 'MINGGU1': return '1 MINGGU';
      case '2 MINGGU': case 'MINGGU2': return '2 MINGGU';
      case 'LUNAS': return 'LUNAS';
      default: return 'BELUM GAJIAN';
    }
  }
  int _bersihAdil({required int pokok, required int bonus, required int kasbon}) {
    final kotor = pokok + bonus;
    final bersih = kotor - kasbon;
    return bersih < 0 ? 0 : bersih;
  }

  // FIX UTAMA: AMBIL BINTANG DARI TABEL YANG SAMA DENGAN DASHBOARD
  Future<double> _getRatingLive(int karyawanId, DateTime start, DateTime end) async {
    try {
      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
      final list = await (db.select(db.bintangHarian)
            ..where((t) => t.karyawanId.equals(karyawanId))
            ..where((t) => t.tanggal.isBetweenValues(startDay, endDay)))
          .get();
      if (list.isEmpty) return 0.0;
      double total = 0;
      for (var b in list) total += b.bintang.toDouble();
      return total / list.length;
    } catch (_) {
      return 0.0;
    }
  }

  int _saranBonusDariRating(double rating) {
    if (rating >= 4.8) return 50000;
    if (rating >= 4.5) return 30000;
    if (rating >= 4.0) return 20000;
    if (rating >= 3.5) return 10000;
    return 0;
  }
  String _bintangText(double rating) {
    if (rating == 0) return "Belum ada rating";
    return "${rating.toStringAsFixed(1)} ★";
  }

  Future<pw.Document> _pdf({required String nama, required String periode, required int pokok, required int bonus, required int kasbon, required int total, required double rating}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.roll80, margin: const pw.EdgeInsets.all(12), build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Center(child: pw.Text("TB. SLAMET JAYA", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
      pw.Divider(),
      pw.Text("Nama: $nama | Periode: $periode | Rating Live: ${rating.toStringAsFixed(1)}", style: const pw.TextStyle(fontSize: 9)),
      pw.Divider(),
      pw.Text("Pokok Rp ${fmt.format(pokok)} + Bonus Manual Rp ${fmt.format(bonus)} - Kasbon Rp ${fmt.format(kasbon)} = Rp ${fmt.format(total)}", style: const pw.TextStyle(fontSize: 9)),
    ])));
    return pdf;
  }
  Future<void> _shareWA({required String nama, required String periode, required int pokok, required int bonus, required int kasbon, required int total, required double rating}) async {
    final pdf = await _pdf(nama: nama, periode: periode, pokok: pokok, bonus: bonus, kasbon: kasbon, total: total, rating: rating);
    final bytes = await pdf.save(); final dir = await getTemporaryDirectory(); final path = "${dir.path}/Slip_$nama.pdf"; await File(path).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(path)], text: "*SLIP GAJI* $nama $periode Rating ${rating.toStringAsFixed(1)} Terima Rp ${fmt.format(total)}");
  }
  Future<void> _printSlip({required String nama, required String periode, required int pokok, required int bonus, required int kasbon, required int total, required double rating}) async {
    final pdf = await _pdf(nama: nama, periode: periode, pokok: pokok, bonus: bonus, kasbon: kasbon, total: total, rating: rating);
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }

  void _dialogBonusManual(BuildContext ctx, GajiMingguanData g, int karyawanId, double ratingLive) {
    final saran = _saranBonusDariRating(ratingLive);
    final c = TextEditingController(text: g.bonusMingguan == 0 ? "" : g.bonusMingguan.toString());
    showDialog(context: context, builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border(left: BorderSide(color: caramel, width: 6))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: caramel.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.star, color: caramel)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Bonus Manual + Saran Bintang", style: TextStyle(fontWeight: FontWeight.bold, color: roast)),
              Text("${_bintangText(ratingLive)} • Saran Rp ${fmt.format(saran)}", style: TextStyle(fontSize: 11, color: coffee, fontWeight: FontWeight.bold)),
            ])),
          ]),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: caramel.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Text("Rating ${ratingLive.toStringAsFixed(1)} dari Dashboard Live (akumulasi bintangHarian minggu ini). Saran Rp ${fmt.format(saran)}, tapi user tetap isi manual.", style: TextStyle(fontSize: 11, color: roast))),
          const SizedBox(height: 12),
          TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Input Bonus Manual", hintText: "0 (kosong=0)", prefixIcon: Icon(Icons.card_giftcard, color: caramel), suffixText: "Saran ${fmt.format(saran)}", focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: coffee, width: 2)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: caramel.withOpacity(0.5))), filled: true, fillColor: caramel.withOpacity(0.08))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text("Batal", style: TextStyle(color: roast)))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: coffee, foregroundColor: Colors.white), onPressed: () async { await db.inputBonusMingguan(g.id, int.tryParse(c.text)??0); await _refresh(); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text("Simpan Manual"))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: caramel, foregroundColor: Colors.white), onPressed: () async { await db.inputBonusMingguan(g.id, saran); await _refresh(); if (ctx.mounted) Navigator.pop(ctx); }, child: Text("Pakai\n${fmt.format(saran)}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)))),
          ]),
        ]),
      ),
    ));
  }

  void _dialogKasbon(BuildContext ctx, GajiMingguanData g, int karyawanId, int kotor) {
    final c = TextEditingController();
    showDialog(context: context, builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border(left: BorderSide(color: espresso, width: 6))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: caramel.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.money_off, color: espresso)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Potongan Kasbon", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: roast)), Text("Kotor Rp ${fmt.format(kotor)}", style: TextStyle(fontSize: 12, color: coffee, fontWeight: FontWeight.bold))]))]),
          const SizedBox(height: 14),
          TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Nominal Kasbon", hintText: "0 (kosong=0)", prefixIcon: Icon(Icons.payments_outlined, color: caramel), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: coffee, width: 2)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: caramel.withOpacity(0.5))), filled: true, fillColor: caramel.withOpacity(0.08))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(side: BorderSide(color: caramel), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.pop(ctx), child: Text("Batal", style: TextStyle(color: roast)))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: espresso, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { int v = int.tryParse(c.text)??0; if (v < 0) v = 0; await db.inputPotonganKasbon(karyawanId, g.mingguMulai, v); await _refresh(); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text("Simpan Kasbon", style: TextStyle(fontWeight: FontWeight.bold)))),
          ]),
        ]),
      ),
    ));
  }

  void _showFilterLengkap(List<KaryawanData> listKar) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(builder: (c, setM) {
          return DraggableScrollableSheet(expand: false, initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5, builder: (_, ctrl) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: ListView(controller: ctrl, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Filter & Indexing Lengkap", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
                const Divider(),
                ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.date_range, color: roast), title: const Text("Filter Periode Seminggu", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)), subtitle: Text(_selectedDateRange == null ? "Semua Rentang Tanggal" : "${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}"), trailing: const Icon(Icons.calendar_month), onTap: () async { final p = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030)); if (p != null) { setM(() => _selectedDateRange = p); setState(() {}); } }),
                const SizedBox(height: 12),
                const Text("Filter Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [_chipFilter("BELUM_GAJIAN", "Belum Gajian", caramel, setM), _chipFilter("1 MINGGU", "1 Minggu", coffee, setM), _chipFilter("2 MINGGU", "2 Minggu", espresso, setM), _chipFilter("LUNAS", "Lunas", roast, setM)]),
                const SizedBox(height: 12),
                const Text("Filter Kasbon (Live)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [FilterChip(label: const Text("Ada Kasbon"), selected: _filterHanyaKasbon, onSelected: (v) { setM(() { _filterHanyaKasbon = v; if (v) _filterTanpaKasbon = false; }); setState(() {}); }), FilterChip(label: const Text("Tidak Ada Kasbon"), selected: _filterTanpaKasbon, onSelected: (v) { setM(() { _filterTanpaKasbon = v; if (v) _filterHanyaKasbon = false; }); setState(() {}); })]),
                const SizedBox(height: 12),
                const Text("Filter Bonus", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [FilterChip(label: const Text("Ada Bonus"), selected: _filterHanyaBonus, onSelected: (v) { setM(() { _filterHanyaBonus = v; if (v) _filterTanpaBonus = false; }); setState(() {}); }), FilterChip(label: const Text("Tidak Ada Bonus"), selected: _filterTanpaBonus, onSelected: (v) { setM(() { _filterTanpaBonus = v; if (v) _filterHanyaBonus = false; }); setState(() {}); })]),
                const SizedBox(height: 12),
                const Text("Filter Karyawan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: listKar.map((k) { final sel = _selectedKaryawanIds.contains(k.id); return FilterChip(label: Text(k.nama), selected: sel, onSelected: (v) { setM(() => v? _selectedKaryawanIds.add(k.id) : _selectedKaryawanIds.remove(k.id)); setState(() {}); }); }).toList()),
                const SizedBox(height: 12),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Urutkan Terbanyak", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), value: _sortByTerbanyak, activeColor: roast, onChanged: (v) { setM(() => _sortByTerbanyak = v); setState(() {}); }),
                const SizedBox(height: 16),
                Row(children: [Expanded(child: OutlinedButton(onPressed: () { setM(() { _selectedKaryawanIds.clear(); _selectedStatusColors.clear(); _filterHanyaKasbon = false; _filterTanpaKasbon = false; _filterHanyaBonus = false; _filterTanpaBonus = false; _selectedDateRange = null; _sortByTerbanyak = false; }); setState(() {}); }, child: const Text("Reset"))), const SizedBox(width: 12), Expanded(flex: 2, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: roast), onPressed: () => Navigator.pop(ctx), child: const Text("Terapkan Filter", style: TextStyle(color: Colors.white))))]),
                const SizedBox(height: 20),
              ]),
            );
          });
        });
      },
    );
  }

  Widget _chipFilter(String val, String label, Color col, StateSetter setM) {
    final sel = _selectedStatusColors.contains(val);
    return FilterChip(label: Text(label, style: TextStyle(color: sel? _text(col) : roast, fontSize: 12, fontWeight: FontWeight.bold)), selected: sel, backgroundColor: col.withOpacity(0.2), selectedColor: col, onSelected: (v) { setM(() => v? _selectedStatusColors.add(val) : _selectedStatusColors.remove(val)); setState(() {}); });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("REKAP GAJI KARYAWAN"), backgroundColor: roast, foregroundColor: Colors.white, actions: [
        IconButton(icon: const Icon(Icons.sync), onPressed: _refresh),
        StreamBuilder<List<KaryawanData>>(stream: db.select(db.karyawan).watch(), builder: (c, s) => IconButton(icon: const Icon(Icons.filter_list, size: 28), onPressed: () => _showFilterLengkap(s.data?? []))),
      ]),
      body: StreamBuilder<List<GajiMingguanData>>(
        stream: (db.select(db.gajiMingguan)..orderBy([(t) => OrderingTerm.desc(t.mingguMulai)])).watch(),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          var all = snap.data?? [];
          var filtered = all.where((g) {
            if (_selectedDateRange!= null) {
              if (g.mingguMulai.isBefore(_selectedDateRange!.start) || g.mingguSelesai.isAfter(_selectedDateRange!.end)) return false;
            }
            if (_selectedKaryawanIds.isNotEmpty &&!_selectedKaryawanIds.contains(g.karyawanId)) return false;
            if (_selectedStatusColors.isNotEmpty &&!_selectedStatusColors.contains(g.statusBayar)) return false;
            return true;
          }).toList();
          if (_sortByTerbanyak) filtered.sort((a, b) => b.totalGaji.compareTo(a.totalGaji));

          final now = DateTime.now();
          final startWeek = DateTime(2026, 10, 12);
          final endWeek = DateTime(2026, 10, 18, 23, 59, 59);
          final startMonth = DateTime(now.year, now.month, 1);
          final endMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

          return StreamBuilder<List<KaryawanData>>(stream: db.select(db.karyawan).watch(), builder: (c, karSnap) {
            final listKar = karSnap.data?? [];
            return StreamBuilder<int>(stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()).asyncMap((_) => db.hitungGajiHariIni(DateTime.now())), builder: (c, liveSnap) {
              final bebanLive = liveSnap.data?? 0;
              return FutureBuilder<Map<int, int>>(future: () async {
                Map<int, int> m = {};
                for (var g in all) { m[g.id] = await db.getKasbonPeriode(g.karyawanId, g.mingguMulai, g.mingguSelesai); }
                return m;
              }(), builder: (c, kasMapSnap) {
                final kasMap = kasMapSnap.data?? {};
                int bersih(GajiMingguanData g) => _bersihAdil(pokok: g.totalGajiPokok, bonus: g.bonusMingguan, kasbon: kasMap[g.id]?? 0);
                final mingguList = all.where((g) =>!g.mingguMulai.isBefore(startWeek) &&!g.mingguSelesai.isAfter(endWeek)).toList();
                final bulanList = all.where((g) =>!g.mingguMulai.isBefore(startMonth) &&!g.mingguSelesai.isAfter(endMonth)).toList();
                final totalMinggu = mingguList.fold<int>(0, (s, g) => s + bersih(g));
                final totalBulan = bulanList.fold<int>(0, (s, g) => s + bersih(g));
                final totalAwal = all.fold<int>(0, (s, g) => s + bersih(g));
                final lunas = filtered.where((g) => g.statusBayar == 'LUNAS').toList();
                final totalLunas = lunas.fold<int>(0, (s, g) => s + bersih(g));

                return CustomScrollView(slivers: [
                  SliverToBoxAdapter(child: Column(children: [
                    if (_isLoading) const LinearProgressIndicator(color: caramel),
                    Container(width: double.infinity, margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: caramel.withOpacity(0.25), borderRadius: BorderRadius.circular(12), border: Border.all(color: caramel)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Beban Gaji Hari Ini: Rp ${fmt.format(bebanLive)}", style: TextStyle(fontWeight: FontWeight.bold, color: roast, fontSize: 11)), const Text("LIVE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))])),
                    Container(margin: const EdgeInsets.fromLTRB(8, 0, 8, 6), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: caramel.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: caramel)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("PERIODE SENIN-MINGGU INI", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), Text("12-18 OCT 2026", style: TextStyle(fontWeight: FontWeight.bold, color: roast))]), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: coffee, borderRadius: BorderRadius.circular(20)), child: const Text("AKTIF", style: TextStyle(color: Colors.white, fontSize: 11)))])),
                    Container(margin: const EdgeInsets.fromLTRB(8, 0, 8, 6), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: caramel, width: 6))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Minggu Ini • ${mingguList.length} karyawan\n12-18 Oct live", style: const TextStyle(fontSize: 12)), Text("Rp ${fmt.format(totalMinggu)}", style: TextStyle(fontWeight: FontWeight.bold, color: coffee))])),
                    Container(margin: const EdgeInsets.fromLTRB(8, 0, 8, 6), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: coffee, width: 6))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Bulan Ini Oct 2026\n01-13 Oct", style: const TextStyle(fontSize: 12)), Text("Rp ${fmt.format(totalBulan)}", style: TextStyle(fontWeight: FontWeight.bold, color: espresso))])),
                    Container(margin: const EdgeInsets.fromLTRB(8, 0, 8, 6), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: espresso, width: 6))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Dari Awal\nAPK Terinstall", style: TextStyle(fontSize: 12)), Text("Rp ${fmt.format(totalAwal)}", style: TextStyle(fontWeight: FontWeight.bold, color: roast))])),
                    Container(margin: const EdgeInsets.fromLTRB(8, 0, 8, 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: roast, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Akumulasi Terbayar (Lunas)", style: TextStyle(color: Color(0xFFA87336), fontSize: 11)), Text("Rp ${fmt.format(totalLunas)} • ${lunas.length} Lunas", style: const TextStyle(color: Color(0xFFA87336), fontWeight: FontWeight.bold))])),
                  ])),
                  SliverList.builder(itemCount: filtered.length, itemBuilder: (_, i) {
                    final g = filtered[i];
                    final kar = listKar.where((k) => k.id == g.karyawanId).firstOrNull;
                    final nama = kar?.nama?? "ID ${g.karyawanId}";
                    final col = _warna(g.statusBayar);
                    final kas = kasMap[g.id]?? 0;
                    if (_filterHanyaKasbon && kas <= 0) return const SizedBox.shrink();
                    if (_filterTanpaKasbon && kas > 0) return const SizedBox.shrink();
                    if (_filterHanyaBonus && g.bonusMingguan <= 0) return const SizedBox.shrink();
                    if (_filterTanpaBonus && g.bonusMingguan > 0) return const SizedBox.shrink();
                    final kotor = g.totalGajiPokok + g.bonusMingguan;
                    final bersihFinal = _bersihAdil(pokok: g.totalGajiPokok, bonus: g.bonusMingguan, kasbon: kas);
                    final sisa = kas > kotor? kas - kotor : 0;

                    return Card(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Container(decoration: BoxDecoration(border: Border(left: BorderSide(color: col, width: 6)), borderRadius: BorderRadius.circular(12)), child: ExpansionTile(
                      title: Text("$nama • ${_label(g.statusBayar)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text("Kotor Rp ${fmt.format(kotor)} • Bersih Rp ${fmt.format(bersihFinal)}", style: const TextStyle(fontSize: 11)),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text("Rp ${fmt.format(bersihFinal)}", style: TextStyle(fontWeight: FontWeight.bold, color: bersihFinal == 0? Colors.red : roast)), if (sisa > 0) Text("Sisa ${fmt.format(sisa)}", style: const TextStyle(fontSize: 9, color: Colors.red))]),
                      children: [
                        Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Gaji Pokok (Live):"), Text("Rp ${fmt.format(g.totalGajiPokok)}")]),
                          const SizedBox(height: 6),
                          FutureBuilder<double>(future: _getRatingLive(g.karyawanId, g.mingguMulai, g.mingguSelesai), builder: (c, rateSnap) {
                            final rating = rateSnap.data?? 0.0;
                            final saran = _saranBonusDariRating(rating);
                            return Column(children: [
                              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: caramel.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: caramel.withOpacity(0.3))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Rating Live Dashboard:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), Text(_bintangText(rating), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: coffee)), Text("${rating.toStringAsFixed(1)} akumulasi minggu ini", style: const TextStyle(fontSize: 10, color: Colors.grey))]),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: caramel, borderRadius: BorderRadius.circular(20)), child: Text("Saran Rp ${fmt.format(saran)}", style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                              ])),
                              const SizedBox(height: 8),
                              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: col, width: 4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("● Bonus Manual (Input User):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: roast)), Text("Rating ${rating.toStringAsFixed(1)} ⭐", style: TextStyle(fontSize: 11, color: coffee))]),
                                const SizedBox(height: 8),
                                InkWell(onTap: () => _dialogBonusManual(context, g, g.karyawanId, rating), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(border: Border.all(color: caramel.withOpacity(0.5)), borderRadius: BorderRadius.circular(8), color: caramel.withOpacity(0.05)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(g.bonusMingguan == 0? (saran == 0? "0 (tap isi manual)" : "Saran ${fmt.format(saran)} (tap edit manual)") : fmt.format(g.bonusMingguan), style: TextStyle(color: g.bonusMingguan == 0? Colors.grey : roast, fontWeight: FontWeight.bold)), Icon(Icons.edit, size: 16, color: caramel)]))),
                              ])),
                              const SizedBox(height: 8),
                              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: espresso, width: 4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Potongan Kasbon:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text("Rp ${fmt.format(kas)}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                                const SizedBox(height: 8),
                                InkWell(onTap: () => _dialogKasbon(context, g, g.karyawanId, kotor), child: Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Text(kas == 0? "0" : fmt.format(kas)))),
                                if (sisa > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text("Sisa Rp ${fmt.format(sisa)} ditahan minggu depan (adil)", style: const TextStyle(fontSize: 10, color: Colors.red))),
                              ])),
                              const SizedBox(height: 8),
                              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bersihFinal == 0? Colors.red.shade900 : roast, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Diterima (min 0):", style: TextStyle(color: Color(0xFFA87336), fontWeight: FontWeight.bold)), Text("Rp ${fmt.format(bersihFinal)}", style: const TextStyle(color: Color(0xFFA87336), fontWeight: FontWeight.bold))])),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.description, size: 16), label: const Text("slip"), style: ElevatedButton.styleFrom(backgroundColor: roast, foregroundColor: Colors.white), onPressed: () => _printSlip(nama: nama, periode: "${DateFormat('dd/MM').format(g.mingguMulai)}-${DateFormat('dd/MM/yy').format(g.mingguSelesai)}", pokok: g.totalGajiPokok, bonus: g.bonusMingguan, kasbon: kas, total: bersihFinal, rating: rating))),
                                const SizedBox(width: 8),
                                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.chat, size: 16), label: const Text("WA"), style: ElevatedButton.styleFrom(backgroundColor: col, foregroundColor: _text(col)), onPressed: () => _shareWA(nama: nama, periode: "${DateFormat('dd/MM').format(g.mingguMulai)}-${DateFormat('dd/MM/yy').format(g.mingguSelesai)}", pokok: g.totalGajiPokok, bonus: g.bonusMingguan, kasbon: kas, total: bersihFinal, rating: rating))),
                                const SizedBox(width: 8),
                                DropdownButton<String>(value: g.statusBayar, items: const [DropdownMenuItem(value: 'BELUM_GAJIAN', child: Text("Belum")), DropdownMenuItem(value: '1 MINGGU', child: Text("1 Minggu")), DropdownMenuItem(value: '2 MINGGU', child: Text("2 Minggu")), DropdownMenuItem(value: 'LUNAS', child: Text("Lunas"))], onChanged: (v) async { if (v!= null) await db.tandaiBayar(g.id, v); }),
                              ]),
                            ]);
                          }),
                        ])),
                      ],
                    )));
                  }),
                ]);
              });
            });
          });
        },
      ),
    );
  }
}