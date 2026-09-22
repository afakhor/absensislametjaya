import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:io';
import '../database.dart';

class AbsenPage extends StatefulWidget { const AbsenPage({super.key}); @override State<AbsenPage> createState() => _AbsenPageState(); }
class _AbsenPageState extends State<AbsenPage> {
  final db = AppDatabase(); final auth = LocalAuthentication();
  @override Widget build(BuildContext context) {
    return Scaffold(body: StreamBuilder<List<KaryawanData>>(stream: db.select(db.karyawan).watch(), builder: (c, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      if (s.data!.isEmpty) return const Center(child: Text("Belum ada karyawan. Ke menu Owner"));
      return ListView.builder(itemCount: s.data!.length, itemBuilder: (_, i) {
        var k = s.data![i];
        return Card(child: ListTile(
          leading: k.fotoPath!= null? ClipOval(child: Image.file(File(k.fotoPath!), width: 45, height: 45, fit: BoxFit.cover)) : CircleAvatar(child: Text(k.nama.isNotEmpty? k.nama[0] : '?')),
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
    }));
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