import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';
import 'database.dart';
import 'export_pdf.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: MainMenu()));

class MainMenu extends StatefulWidget { const MainMenu({super.key}); @override State<MainMenu> createState() => _MainMenuState(); }
class _MainMenuState extends State<MainMenu> {
  int _idx = 0;
  final pages = [const AbsenPage(), const GajiPage(), const LabaPage(), const AuditPage(), const SettingPage()];
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TB. SLAMET JAYA", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
      body: pages[_idx],
      bottomNavigationBar: NavigationBar(selectedIndex: _idx, onDestinationSelected: (i) => setState(() => _idx = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.fingerprint), label: 'Absen'),
        NavigationDestination(icon: Icon(Icons.payments), label: 'Gaji'),
        NavigationDestination(icon: Icon(Icons.analytics), label: 'Laba'),
        NavigationDestination(icon: Icon(Icons.security), label: 'Audit'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Owner'),
      ]),
    );
  }
}

class AbsenPage extends StatefulWidget { const AbsenPage({super.key}); @override State<AbsenPage> createState() => _AbsenPageState(); }
class _AbsenPageState extends State<AbsenPage> {
  final db = AppDatabase(); final auth = LocalAuthentication();
  @override Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<KaryawanData>>(stream: db.select(db.karyawans).watch(), builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        if (s.data!.isEmpty) return const Center(child: Text("Belum ada karyawan. Ke menu Owner > Tambah Kategori & Karyawan"));
        return ListView.builder(itemCount: s.data!.length, itemBuilder: (_, i) {
          var k = s.data![i];
          return Card(child: ListTile(
            title: Text(k.nama),
            subtitle: FutureBuilder<KategoriKaryawanData?>(future: (db.select(db.kategoriKaryawans)..where((t) => t.id.equals(k.kategoriId))).getSingleOrNull(), builder: (c, kat) => Text(kat.data!= null? "${kat.data!.namaKategori} - Rp ${kat.data!.tarifPerJam}/jam" : "Kategori terhapus")),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.fingerprint, color: Colors.green), onPressed: () async {
                try {
                  bool ok = await auth.authenticate(localizedReason: 'Absen ${k.nama}', options: const AuthenticationOptions(biometricOnly: true));
                  if (!ok) return;
                  await db.into(db.absensis).insert(AbsensisCompanion.insert(karyawanId: k.id, jamMasuk: DateTime.now(), totalJamKerja: const Value(8.0), metode: 'FINGERPRINT', keterangan: const Value('Valid')));
                  await db.catatAudit(aktor: k.nama, aksi: 'ABSEN_FINGERPRINT', target: k.nama, detail: '8 jam kerja');
                  await db.prosesHitungGajiMingguan();
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Absen Fingerprint Berhasil")));
                } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
              }),
              IconButton(icon: const Icon(Icons.admin_panel_settings, color: Colors.orange), onPressed: () => _manual(k)),
            ]),
          ));
        });
      }),
    );
  }
  void _manual(KaryawanData k) {
    final pinC = TextEditingController(); final alasanC = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text("Manual Owner untuk ${k.nama}"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: pinC, obscureText: true, decoration: const InputDecoration(labelText: "PIN Owner 123456")), TextField(controller: alasanC, decoration: const InputDecoration(labelText: "Alasan Wajib"))]),
      actions: [ElevatedButton(onPressed: () async { if (pinC.text!= '123456') return; await db.into(db.absensis).insert(AbsensisCompanion.insert(karyawanId: k.id, jamMasuk: DateTime.now(), totalJamKerja: const Value(8.0), metode: 'MANUAL_OWNER', keterangan: Value(alasanC.text))); await db.catatAudit(aktor: 'OWNER', aksi: 'MANUAL_OVERRIDE', target: k.nama, detail: alasanC.text); await db.prosesHitungGajiMingguan(); if (mounted) Navigator.pop(context); }, child: const Text("SIMPAN"))],
    ));
  }
}

class GajiPage extends StatelessWidget { const GajiPage({super.key}); @override Widget build(BuildContext context) { final db = AppDatabase(); return Scaffold(appBar: AppBar(title: const Text("Gaji Mingguan Auto Fix"), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => db.prosesHitungGajiMingguan())]), body: StreamBuilder<List<GajiMingguanData>>(stream: db.select(db.gajiMingguans).watch(), builder: (c, s) { if (!s.hasData) return const Center(child: CircularProgressIndicator()); if (s.data!.isEmpty) return const Center(child: Text("Belum ada gaji. Absen dulu karyawan")); return ListView.builder(itemCount: s.data!.length, itemBuilder: (_, i) { var g = s.data![i]; return FutureBuilder<KaryawanData?>(future: (db.select(db.karyawans)..where((t) => t.id.equals(g.karyawanId))).getSingleOrNull(), builder: (c, kar) { return FutureBuilder<KategoriKaryawanData?>(future: kar.data!= null? (db.select(db.kategoriKaryawans)..where((t) => t.id.equals(kar.data!.kategoriId))).getSingleOrNull() : Future.value(null), builder: (c, kat) { return ListTile(title: Text(kar.data?.nama?? "ID ${g.karyawanId}"), subtitle: Text("${g.totalJam} Jam | ${DateFormat('dd MMM').format(g.mingguMulai)}"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("Rp ${NumberFormat.decimalPattern('id').format(g.totalGaji)}", style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), onPressed: () async { if (kar.data == null || kat.data == null) return; var absen = await (db.select(db.absensis)..where((t) => t.karyawanId.equals(g.karyawanId))).get(); await ExportPdfTBSlametJaya.exportSlipGajiMingguan(karyawan: kar.data!, kategori: kat.data!, gaji: g, absensiMingguIni: absen); })])); }); }); }); })); } }

class LabaPage extends StatefulWidget { const LabaPage({super.key}); @override State<LabaPage> createState() => _LabaPageState(); }
class _LabaPageState extends State<LabaPage> { final db = AppDatabase(); Map<String, int> laba = {}; final omsetC = TextEditingController(); final bebanC = TextEditingController(); final ketC = TextEditingController(); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Laba Kotor & Bersih - Beban Gaji Auto")), body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [TextField(controller: omsetC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Input Manual: Omset / Pendapatan")), TextField(controller: bebanC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Input Manual: Sewa, Listrik, dll")), TextField(controller: ketC, decoration: const InputDecoration(labelText: "Keterangan")), const SizedBox(height: 10), Row(children: [Expanded(child: ElevatedButton(onPressed: () async { if (omsetC.text.isNotEmpty) { await db.into(db.transaksiBisnis).insert(TransaksiBisnisCompanion.insert(jenis: 'PENDAPATAN', keterangan: ketC.text.isEmpty? 'Omset' : ketC.text, nominal: int.parse(omsetC.text), tanggal: DateTime.now())); omsetC.clear(); } var h = await db.hitungLabaBulanan(DateTime.now()); setState(() => laba = h); }, child: const Text("Tambah Pendapatan"))), const SizedBox(width: 8), Expanded(child: ElevatedButton(onPressed: () async { if (bebanC.text.isNotEmpty) { await db.into(db.transaksiBisnis).insert(TransaksiBisnisCompanion.insert(jenis: 'BEBAN_OPERASIONAL', keterangan: ketC.text.isEmpty? 'Beban Ops' : ketC.text, nominal: int.parse(bebanC.text), tanggal: DateTime.now())); bebanC.clear(); } var h = await db.hitungLabaBulanan(DateTime.now()); setState(() => laba = h); }, child: const Text("Tambah Beban Ops")))]), const SizedBox(height: 10), ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("HITUNG ULANG LABA"), onPressed: () async { var h = await db.hitungLabaBulanan(DateTime.now()); setState(() => laba = h); }), const Divider(), Text("Pendapatan: Rp ${laba['pendapatan']?? 0}"), Text("Beban Gaji (Otomatis): Rp ${laba['bebanGaji']?? 0}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), Text("Beban Ops: Rp ${laba['bebanOps']?? 0}"), const Divider(), Text("LABA KOTOR: Rp ${laba['labaKotor']?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 18)), Text("LABA BERSIH: Rp ${laba['labaBersih']?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 22)), const SizedBox(height: 20), ElevatedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text("CETAK PDF LAPORAN LABA - TERPISAH"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)), onPressed: () async { var h = await db.hitungLabaBulanan(DateTime.now()); var pendapatan = await (db.select(db.transaksiBisnis)..where((t) => t.jenis.equals('PENDAPATAN'))).get(); var bebanOps = await (db.select(db.transaksiBisnis)..where((t) => t.jenis.equals('BEBAN_OPERASIONAL'))).get(); var gajiBulan = await db.select(db.gajiMingguans).get(); await ExportPdfTBSlametJaya.exportLaporanLaba(laba: h, bulan: DateTime.now(), pendapatanList: pendapatan, bebanOpsList: bebanOps, gajiBulanIni: gajiBulan); })]))); } }

class AuditPage extends StatelessWidget { const AuditPage({super.key}); @override Widget build(BuildContext context) { final db = AppDatabase(); return Scaffold(body: StreamBuilder<List<AuditLogData>>(stream: (db.select(db.auditLogs)..orderBy([(t) => OrderingTerm.desc(t.waktu))]).watch(), builder: (c, s) { if (!s.hasData) return const Center(child: CircularProgressIndicator()); return ListView.builder(itemCount: s.data!.length, itemBuilder: (_, i) { var l = s.data![i]; return Container(margin: const EdgeInsets.all(4), decoration: BoxDecoration(color: l.status == 'MENCURIGAKAN'? Colors.red.shade50 : Colors.white, border: Border(left: BorderSide(color: l.status == 'MENCURIGAKAN'? Colors.red : Colors.green, width: 4))), child: ListTile(title: Text("${l.aksi} oleh ${l.aktor}", style: TextStyle(fontWeight: FontWeight.bold, color: l.status == 'MENCURIGAKAN'? Colors.red : Colors.black)), subtitle: Text("${DateFormat('dd MMM HH:mm:ss').format(l.waktu)}\nTarget: ${l.target}\nDetail: ${l.detail}\nStatus: ${l.status}"))); }); })); } }

class SettingPage extends StatelessWidget { const SettingPage({super.key}); @override Widget build(BuildContext context) { final db = AppDatabase(); final katNamaC = TextEditingController(); final katTarifC = TextEditingController(); final karNamaC = TextEditingController(); return Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("1. Buat Kategori & Tarif / Jam", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Row(children: [Expanded(child: TextField(controller: katNamaC, decoration: const InputDecoration(labelText: "Nama (Operator/Senior)"))), const SizedBox(width: 8), Expanded(child: TextField(controller: katTarifC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Tarif/Jam"))), IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 35), onPressed: () async { if (katNamaC.text.isEmpty || katTarifC.text.isEmpty) return; await db.into(db.kategoriKaryawans).insert(KategoriKaryawanCompanion.insert(namaKategori: katNamaC.text, tarifPerJam: int.parse(katTarifC.text))); await db.catatAudit(aktor: 'OWNER', aksi: 'BUAT_KATEGORI', target: katNamaC.text, detail: 'Tarif ${katTarifC.text}/jam'); katNamaC.clear(); katTarifC.clear(); })]), const Divider(), const Text("2. Buat Karyawan + Pilih Kategori", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), TextField(controller: karNamaC, decoration: const InputDecoration(labelText: "Nama Karyawan Baru")), const SizedBox(height: 8), StreamBuilder<List<KategoriKaryawanData>>(stream: db.select(db.kategoriKaryawans).watch(), builder: (c, s) { if (!s.hasData) return const CircularProgressIndicator(); if (s.data!.isEmpty) return const Text("Buat kategori dulu"); return Column(children: s.data!.map((kat) => Card(child: ListTile(title: Text("${kat.namaKategori} - Rp ${kat.tarifPerJam}/jam"), trailing: ElevatedButton(child: const Text("Jadikan Karyawan Ini"), onPressed: () async { if (karNamaC.text.isEmpty) return; await db.into(db.karyawans).insert(KaryawansCompanion.insert(nama: karNamaC.text, kategoriId: kat.id)); await db.catatAudit(aktor: 'OWNER', aksi: 'TAMBAH_KARYAWAN', target: karNamaC.text, detail: 'Kategori ${kat.namaKategori}'); karNamaC.clear(); }))))).toList(); }), const Divider(), const Text("Daftar Karyawan:"), StreamBuilder<List<KaryawanData>>(stream: db.select(db.karyawans).watch(), builder: (c, s) => Column(children: (s.data?? []).map((k) => FutureBuilder<KategoriKaryawanData?>(future: (db.select(db.kategoriKaryawans)..where((t) => t.id.equals(k.kategoriId))).getSingleOrNull(), builder: (c, kat) => ListTile(title: Text(k.nama), subtitle: Text(kat.data!= null? "${kat.data!.namaKategori} - Rp ${kat.data!.tarifPerJam}/jam" : "Kategori hapus"), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { await (db.delete(db.karyawans)..where((t) => t.id.equals(k.id))).go(); await db.catatAudit(aktor: 'OWNER', aksi: 'HAPUS_KARYAWAN', target: k.nama, detail: 'Hapus'); })))).toList()))]))); } }