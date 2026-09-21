import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
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
      body: StreamBuilder<List<KaryawanData>>(stream: db.select(db.karyawan).watch(), builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        if (s.data!.isEmpty) return const Center(child: Text("Belum ada karyawan. Ke menu Owner"));
        return ListView.builder(itemCount: s.data!.length, itemBuilder: (_, i) {
          var k = s.data![i];
          return Card(child: ListTile(
            title: Text(k.nama),
            subtitle: FutureBuilder<KategoriKaryawanData?>(future: (db.select(db.kategoriKaryawan)..where((t) => t.id.equals(k.kategoriId))).getSingleOrNull(), builder: (c, kat) => Text(kat.data!= null? "${kat.data!.namaKategori} - Rp ${kat.data!.tarifPerJam}/jam" : "Kategori hapus")),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.fingerprint, color: Colors.green), onPressed: () async {
                bool ok = await auth.authenticate(localizedReason: 'Absen ${k.nama}', options: const AuthenticationOptions(biometricOnly: true));
                if (!ok) return;
                await db.into(db.absensi).insert(AbsensiCompanion.insert(karyawanId: k.id, jamMasuk: DateTime.now(), totalJamKerja: const drift.Value(8.0), metode: 'FINGERPRINT', keterangan: const drift.Value('Valid')));
                await db.catatAudit(aktor: k.nama, aksi: 'ABSEN_FINGERPRINT', target: k.nama, detail: '8 jam');
                await db.prosesHitungGajiMingguan();
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
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: pinC, obscureText: true, decoration: const InputDecoration(labelText: "PIN 123456")), TextField(controller: alasanC, decoration: const InputDecoration(labelText: "Alasan Wajib"))]),
      actions: [ElevatedButton(onPressed: () async { if (pinC.text!= '123456') return; await db.into(db.absensi).insert(AbsensiCompanion.insert(karyawanId: k.id, jamMasuk: DateTime.now(), totalJamKerja: const drift.Value(8.0), metode: 'MANUAL_OWNER', keterangan: drift.Value(alasanC.text))); await db.catatAudit(aktor: 'OWNER', aksi: 'MANUAL_OVERRIDE', target: k.nama, detail: alasanC.text); await db.prosesHitungGajiMingguan(); if (mounted) Navigator.pop(context); }, child: const Text("SIMPAN"))],
    ));
  }
}

class GajiPage extends StatelessWidget {
  const GajiPage({super.key});
  @override Widget build(BuildContext context) {
    final db = AppDatabase();
    return Scaffold(
      appBar: AppBar(title: const Text("Gaji Mingguan"), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => db.prosesHitungGajiMingguan())]),
      body: StreamBuilder<List<GajiMingguanData>>(stream: db.select(db.gajiMingguan).watch(), builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(itemCount: s.data!.length, itemBuilder: (_, i) {
          var g = s.data![i];
          return FutureBuilder<KaryawanData?>(future: (db.select(db.karyawan)..where((t) => t.id.equals(g.karyawanId))).getSingleOrNull(), builder: (c, kar) {
            return ListTile(title: Text(kar.data?.nama?? "ID ${g.karyawanId}"), subtitle: Text("${g.totalJam} Jam"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text("Rp ${g.totalGaji}"),
              IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () async {
                if (kar.data == null) return;
                var kat = await (db.select(db.kategoriKaryawan)..where((t) => t.id.equals(kar.data!.kategoriId))).getSingle();
                var absen = await (db.select(db.absensi)..where((t) => t.karyawanId.equals(g.karyawanId))).get();
                await ExportPdfTBSlametJaya.exportSlipGajiMingguan(karyawan: kar.data!, kategori: kat, gaji: g, absensiMingguIni: absen);
              })
            ]));
          });
        });
      }),
    );
  }
}

class LabaPage extends StatefulWidget { const LabaPage({super.key}); @override State<LabaPage> createState() => _LabaPageState(); }
class _LabaPageState extends State<LabaPage> {
  final db = AppDatabase(); Map<String, int> laba = {};
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Laba Kotor & Bersih")), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("Beban Gaji Auto: Rp ${laba['bebanGaji']?? 0}"), Text("Laba Bersih: Rp ${laba['labaBersih']?? 0}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ElevatedButton(onPressed: () async { var h = await db.hitungLabaBulanan(DateTime.now()); setState(() => laba = h); }, child: const Text("Hitung Laba")),
      ElevatedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text("CETAK PDF LABA"), onPressed: () async {
        var h = await db.hitungLabaBulanan(DateTime.now());
        var pendapatan = await (db.select(db.transaksi)..where((t) => t.jenis.equals('PENDAPATAN'))).get();
var bebanOps = await (db.select(db.transaksi)..where((t) => t.jenis.equals('BEBAN_OPERASIONAL'))).get();
        var gajiBulan = await db.select(db.gajiMingguan).get();
        await ExportPdfTBSlametJaya.exportLaporanLaba(laba: h, bulan: DateTime.now(), pendapatanList: pendapatan, bebanOpsList: bebanOps, gajiBulanIni: gajiBulan);
      })
    ])));
  }
}

class AuditPage extends StatelessWidget {
  const AuditPage({super.key});
  @override Widget build(BuildContext context) {
    final db = AppDatabase();
    return Scaffold(body: StreamBuilder<List<AuditLogData>>(stream: (db.select(db.auditLog)..orderBy([(t) => drift.OrderingTerm.desc(t.waktu)])).watch(), builder: (c, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      return ListView.builder(itemCount: s.data!.length, itemBuilder: (_, i) {
        var l = s.data![i];
        return ListTile(title: Text("${l.aksi} - ${l.aktor}"), subtitle: Text("${l.target} - ${l.status}"));
      });
    }));
  }
}

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});
  @override Widget build(BuildContext context) {
    final db = AppDatabase(); final katNamaC = TextEditingController(); final katTarifC = TextEditingController(); final karNamaC = TextEditingController();
    return Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
      TextField(controller: katNamaC, decoration: const InputDecoration(labelText: "Nama Kategori")), TextField(controller: katTarifC, decoration: const InputDecoration(labelText: "Tarif/Jam")),
      ElevatedButton(onPressed: () async { await db.into(db.kategoriKaryawan).insert(KategoriKaryawanCompanion.insert(namaKategori: katNamaC.text, tarifPerJam: int.parse(katTarifC.text))); }, child: const Text("Tambah Kategori")),
      const Divider(), TextField(controller: karNamaC, decoration: const InputDecoration(labelText: "Nama Karyawan")),
      StreamBuilder<List<KategoriKaryawanData>>(stream: db.select(db.kategoriKaryawan).watch(), builder: (c, s) {
        if (!s.hasData) return const CircularProgressIndicator();
        return Column(children: s.data!.map((kat) => ListTile(title: Text(kat.namaKategori), trailing: ElevatedButton(child: const Text("Jadikan"), onPressed: () async { await db.into(db.karyawan).insert(KaryawanCompanion.insert(nama: karNamaC.text, kategoriId: kat.id)); }))).toList());
      })
    ])));
  }
}