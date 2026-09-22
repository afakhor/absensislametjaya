import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'database.dart';
import 'export_pdf.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;


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



class SettingPage extends StatefulWidget {
  const SettingPage({super.key});
  @override State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final db = AppDatabase();
  final katNamaC = TextEditingController();
  final katTarifC = TextEditingController();
  final karNamaC = TextEditingController();
  KategoriKaryawanData? kategoriTerpilih;
  String? fotoPathTemp;
  final picker = ImagePicker();
  final formatRp = NumberFormat.decimalPattern('id');

  Future<void> pickFoto() async {
    final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final newPath = p.join(dir.path, 'karyawan_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(x.path).copy(newPath);
    setState(() => fotoPathTemp = newPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("1. Kategori & Tarif (Auto Complete)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          // AUTO COMPLETE KATEGORI + AUTO ISI TARIF
          StreamBuilder<List<KategoriKaryawanData>>(
            stream: db.select(db.kategoriKaryawan).watch(),
            builder: (c, snap) {
              final listKat = snap.data ?? [];
              final namaList = listKat.map((e) => e.namaKategori).toList();
              return Autocomplete<String>(
                optionsBuilder: (TextEditingValue val) {
                  if (val.text == '') return namaList;
                  return namaList.where((e) => e.toLowerCase().contains(val.text.toLowerCase()));
                },
                onSelected: (selected) {
                  final kat = listKat.firstWhere((e) => e.namaKategori == selected);
                  setState(() {
                    kategoriTerpilih = kat;
                    katNamaC.text = kat.namaKategori;
                    katTarifC.text = kat.tarifPerJam.toString();
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  // sinkron controller luar dengan dalam
                  katNamaC.addListener(() { if(controller.text != katNamaC.text) controller.text = katNamaC.text; });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: "Nama Kategori (ketik: Operator, Senior, dll)", border: OutlineInputBorder(), suffixIcon: Icon(Icons.history)),
                    onChanged: (v) {
                      katNamaC.text = v;
                      // cek apakah ada history
                      final found = listKat.where((e) => e.namaKategori.toLowerCase() == v.toLowerCase()).toList();
                      if(found.isNotEmpty){
                        setState(() {
                          kategoriTerpilih = found.first;
                          katTarifC.text = found.first.tarifPerJam.toString();
                        });
                      }
                    },
                  );
                },
              );
            }
          ),
          const SizedBox(height: 8),
          TextField(controller: katTarifC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Tarif/Jam (auto keisi)", border: OutlineInputBorder())),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.save), label: const Text("Tambah / Update Kategori"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white), onPressed: () async {
            if(katNamaC.text.isEmpty || katTarifC.text.isEmpty) return;
            // jika sudah ada update tarifnya
            final existing = await (db.select(db.kategoriKaryawan)..where((t) => t.namaKategori.equals(katNamaC.text))).getSingleOrNull();
            if(existing != null){
              await (db.update(db.kategoriKaryawan)..where((t) => t.id.equals(existing.id))).write(KategoriKaryawanCompanion(tarifPerJam: drift.Value(int.parse(katTarifC.text))));
            } else {
              await db.into(db.kategoriKaryawan).insert(KategoriKaryawanCompanion.insert(namaKategori: katNamaC.text, tarifPerJam: int.parse(katTarifC.text)));
            }
            katNamaC.clear(); katTarifC.clear(); setState(() => kategoriTerpilih = null);
          })),

          const Divider(height: 32),
          const Text("2. Tambah Karyawan + Foto + Pilih Kategori", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(controller: karNamaC, decoration: const InputDecoration(labelText: "Nama Karyawan", border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [
            fotoPathTemp != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(fotoPathTemp!), width: 60, height: 60, fit: BoxFit.cover)) : Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person)),
            const SizedBox(width: 12),
            ElevatedButton.icon(icon: const Icon(Icons.camera_alt), label: const Text("Foto Karyawan"), onPressed: pickFoto),
            if(fotoPathTemp != null) IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: ()=> setState(()=> fotoPathTemp = null)),
          ]),
          const SizedBox(height: 12),
          StreamBuilder<List<KategoriKaryawanData>>(
            stream: db.select(db.kategoriKaryawan).watch(),
            builder: (c, snap) {
              if(!snap.hasData) return const CircularProgressIndicator();
              if(snap.data!.isEmpty) return const Text("Buat kategori dulu di atas");
              return Column(
                children: snap.data!.map((kat) => Card(
                  color: kategoriTerpilih?.id == kat.id ? Colors.orange.shade50 : null,
                  child: ListTile(
                    leading: const Icon(Icons.work),
                    title: Text("${kat.namaKategori}"),
                    subtitle: Text("Rp ${formatRp.format(kat.tarifPerJam)}/jam"),
                    trailing: kategoriTerpilih?.id == kat.id ? const Icon(Icons.check_circle, color: Colors.green) : ElevatedButton(child: const Text("Pilih"), onPressed: (){ setState((){ kategoriTerpilih = kat; katNamaC.text = kat.namaKategori; katTarifC.text = kat.tarifPerJam.toString(); }); }),
                  ),
                )).toList(),
              );
            }
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(icon: const Icon(Icons.person_add), label: Text(kategoriTerpilih == null ? "Pilih Kategori Dulu" : "Simpan ${karNamaC.text.isEmpty ? 'Karyawan' : karNamaC.text} sebagai ${kategoriTerpilih!.namaKategori}"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: kategoriTerpilih == null ? null : () async {
            if(karNamaC.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama karyawan wajib"))); return; }
            await db.into(db.karyawan).insert(KaryawanCompanion.insert(nama: karNamaC.text, kategoriId: kategoriTerpilih!.id, fotoPath: drift.Value(fotoPathTemp)));
            await db.catatAudit(aktor: 'OWNER', aksi: 'TAMBAH_KARYAWAN', target: karNamaC.text, detail: 'Kategori ${kategoriTerpilih!.namaKategori} Tarif ${kategoriTerpilih!.tarifPerJam}');
            setState((){ karNamaC.clear(); fotoPathTemp = null; kategoriTerpilih = null; });
          })),

          const Divider(height: 32),
          const Text("3. Data Karyawan Tersimpan (Tap Foto untuk Preview)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          StreamBuilder<List<KaryawanData>>(
            stream: db.select(db.karyawan).watch(),
            builder: (c, snap) {
              if(!snap.hasData) return const Center(child: CircularProgressIndicator());
              if(snap.data!.isEmpty) return const Text("Belum ada karyawan");
              return Column(
                children: snap.data!.map((k) => FutureBuilder<KategoriKaryawanData?>(
                  future: (db.select(db.kategoriKaryawan)..where((t) => t.id.equals(k.kategoriId))).getSingleOrNull(),
                  builder: (c, katSnap) {
                    final kat = katSnap.data;
                    return Card(
                      elevation: 3,
                      child: ListTile(
                        leading: GestureDetector(
                          onTap: () {
                            if(k.fotoPath == null) return;
                            showDialog(context: context, builder: (_) => Dialog(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Image.file(File(k.fotoPath!), fit: BoxFit.cover),
                              Padding(padding: const EdgeInsets.all(8), child: Text(k.nama, style: const TextStyle(fontWeight: FontWeight.bold))),
                              TextButton(onPressed: ()=> Navigator.pop(context), child: const Text("Tutup"))
                            ]))));
                          },
                          child: k.fotoPath != null ? ClipOval(child: Image.file(File(k.fotoPath!), width: 50, height: 50, fit: BoxFit.cover)) : CircleAvatar(child: Text(k.nama[0])),
                        ),
                        title: Text(k.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("Kategori: ${kat?.namaKategori ?? 'Terhapus'}"),
                          Text("Gaji: Rp ${kat != null ? formatRp.format(kat.tarifPerJam) : '0'}/jam", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                        ]),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                          await (db.delete(db.karyawan)..where((t) => t.id.equals(k.id))).go();
                        }),
                      ),
                    );
                  }
                )).toList(),
              );
            }
          )
        ]),
      ),
    );
  }
}