import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../dbases/localdatabase.dart';
import '../dbases/setowner_db.dart';
import '../dbases/absen_db.dart';

class SettingOwnerPage extends StatefulWidget {
  const SettingOwnerPage({super.key});
  @override State<SettingOwnerPage> createState() => _SettingOwnerPageState();
}

class _SettingOwnerPageState extends State<SettingOwnerPage> {
  final db = AppDatabase();
  final katNamaC = TextEditingController();
  final katTarifC = TextEditingController();
  final karNamaC = TextEditingController();
  KategoriKaryawanData? kategoriTerpilih;
  String? fotoPathTemp;
  final picker = ImagePicker();
  final formatRp = NumberFormat.decimalPattern('id');
  final autoCtrl = TextEditingController();

  Future<void> pickFoto() async {
    final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final newPath = p.join(dir.path, 'karyawan_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(x.path).copy(newPath);
    setState(() => fotoPathTemp = newPath);
  }

  Future<void> _simpanKategori() async {
    if (katNamaC.text.trim().isEmpty || katTarifC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama & Tarif wajib diisi")));
      return;
    }
    final tarif = int.tryParse(katTarifC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (tarif <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tarif harus angka > 0")));
      return;
    }
    final ex = await (db.select(db.kategoriKaryawan)..where((t) => t.namaKategori.equals(katNamaC.text.trim()))).getSingleOrNull();
    if (ex != null) {
      await (db.update(db.kategoriKaryawan)..where((t) => t.id.equals(ex.id))).write(KategoriKaryawanCompanion(tarifPerHari: drift.Value(tarif)));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update kategori ${ex.namaKategori} jadi Rp $tarif/hari")));
    } else {
      await db.into(db.kategoriKaryawan).insert(KategoriKaryawanCompanion.insert(namaKategori: katNamaC.text.trim(), tarifPerHari: tarif));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kategori ${katNamaC.text} ditambahkan")));
    }
    katNamaC.clear();
    katTarifC.clear();
    autoCtrl.clear();
    setState(() => kategoriTerpilih = null);
  }

  Future<void> _simpanKaryawan() async {
    if (karNamaC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama karyawan wajib")));
      return;
    }
    if (kategoriTerpilih == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih kategori dulu")));
      return;
    }
    await db.into(db.karyawan).insert(KaryawanCompanion.insert(
      nama: karNamaC.text.trim(),
      kategoriId: kategoriTerpilih!.id,
      fotoPath: drift.Value(fotoPathTemp),
    ));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Karyawan ${karNamaC.text} ID auto disimpan")));
    setState(() {
      karNamaC.clear();
      fotoPathTemp = null;
      kategoriTerpilih = null;
    });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setting Owner"), backgroundColor: Colors.brown.shade800, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("1. Kategori & Tarif Gaji/Hari (Auto Complete)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          StreamBuilder<List<KategoriKaryawanData>>(
            stream: db.watchKategori(),
            builder: (context, snap) {
              final listKat = snap.data ?? [];
              final namaList = listKat.map((e) => e.namaKategori).toList();
              return Autocomplete<String>(
                optionsBuilder: (TextEditingValue val) {
                  if (val.text == '') return namaList;
                  return namaList.where((e) => e.toLowerCase().contains(val.text.toLowerCase()));
                },
                onSelected: (s) {
                  final kat = listKat.firstWhere((e) => e.namaKategori == s);
                  setState(() {
                    kategoriTerpilih = kat;
                    katNamaC.text = kat.namaKategori;
                    katTarifC.text = kat.tarifPerHari.toString();
                    autoCtrl.text = kat.namaKategori;
                  });
                },
                fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
                  // SYNC controller autocomplete ke katNamaC
                  if (autoCtrl.text != ctrl.text && ctrl.text.isEmpty == false) {
                    // biar gak loop
                  }
                  return TextField(
                    controller: ctrl,
                    focusNode: fn,
                    decoration: const InputDecoration(labelText: "Nama Kategori (Operator, Senior...)", border: OutlineInputBorder(), suffixIcon: Icon(Icons.history)),
                    onChanged: (v) {
                      katNamaC.text = v;
                      final found = listKat.where((e) => e.namaKategori.toLowerCase() == v.toLowerCase()).toList();
                      if (found.isNotEmpty) {
                        setState(() {
                          kategoriTerpilih = found.first;
                          katTarifC.text = found.first.tarifPerHari.toString();
                        });
                      }
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          TextField(controller: katTarifC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Tarif/Hari", border: OutlineInputBorder(), prefixText: "Rp ")),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(icon: const Icon(Icons.save), label: const Text("Tambah / Update Kategori"), style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade800, foregroundColor: Colors.white), onPressed: _simpanKategori),
          ),

          const Divider(height: 32),
          const Text("2. Tambah Karyawan + Foto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(controller: karNamaC, decoration: const InputDecoration(labelText: "Nama Karyawan (ID auto)", border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [
            fotoPathTemp != null? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(fotoPathTemp!), width: 60, height: 60, fit: BoxFit.cover)) : Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person)),
            const SizedBox(width: 12),
            ElevatedButton.icon(icon: const Icon(Icons.camera_alt), label: const Text("Foto Kamera"), onPressed: pickFoto)
          ]),
          const SizedBox(height: 12),
          StreamBuilder<List<KategoriKaryawanData>>(
            stream: db.watchKategori(),
            builder: (c, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              if (snap.data!.isEmpty) return const Text("Buat kategori dulu di atas");
              return Column(
                children: snap.data!.map((kat) => Card(color: kategoriTerpilih?.id == kat.id? Colors.orange.shade50 : null, child: ListTile(title: Text(kat.namaKategori), subtitle: Text("Rp ${formatRp.format(kat.tarifPerHari)}/hari"), trailing: kategoriTerpilih?.id == kat.id? const Icon(Icons.check_circle, color: Colors.green) : ElevatedButton(child: const Text("Pilih"), onPressed: () { setState(() { kategoriTerpilih = kat; katNamaC.text = kat.namaKategori; katTarifC.text = kat.tarifPerHari.toString(); }); })))).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(icon: const Icon(Icons.person_add), label: Text(kategoriTerpilih == null? "Pilih Kategori Dulu" : "Simpan Karyawan ID Auto"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: kategoriTerpilih == null? null : _simpanKaryawan)),

          const Divider(height: 32),
          const Text("3. Data Karyawan (ID Auto Increment)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          StreamBuilder<List<KaryawanData>>(
            stream: db.watchKaryawan(),
            builder: (c, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (snap.data!.isEmpty) return const Text("Belum ada karyawan, tambah di atas");
              return Column(
                children: snap.data!.map((k) {
                  // FIX KURUNG - INI YANG BIKIN ERROR TADI
                  return FutureBuilder<KategoriKaryawanData?>(
                    future: (db.select(db.kategoriKaryawan)..where((t) => t.id.equals(k.kategoriId))).getSingleOrNull(),
                    builder: (c, katSnap) {
                      final kat = katSnap.data;
                      return Card(
                        elevation: 2,
                        child: ListTile(
                          leading: k.fotoPath != null? ClipOval(child: Image.file(File(k.fotoPath!), width: 50, height: 50, fit: BoxFit.cover)) : CircleAvatar(child: Text(k.id.toString())),
                          title: Text("ID:${k.id} - ${k.nama}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${kat?.namaKategori?? 'Kategori hapus'} | Rp ${kat!= null? formatRp.format(kat.tarifPerHari) : '0'}/hari"),
                          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { await (db.delete(db.karyawan)..where((t) => t.id.equals(k.id))).go(); }),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ]),
      ),
    );
  }
}