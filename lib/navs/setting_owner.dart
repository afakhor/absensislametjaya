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

class SettingOwnerPage extends StatefulWidget { const SettingOwnerPage({super.key}); @override State<SettingOwnerPage> createState() => _SettingOwnerPageState(); }
class _SettingOwnerPageState extends State<SettingOwnerPage> {
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

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setting Owner"), backgroundColor: Colors.brown.shade800, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("1. Kategori & Tarif Gaji/Hari", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          StreamBuilder<List<KategoriKaryawanData>>(stream: db.watchKategori(), builder: (context, snap) {
            final listKat = snap.data?? [];
            return Autocomplete<String>(
              optionsBuilder: (val) { if (val.text=='') return listKat.map((e)=>e.namaKategori); return listKat.map((e)=>e.namaKategori).where((e)=>e.toLowerCase().contains(val.text.toLowerCase())); },
              onSelected: (s){ final kat = listKat.firstWhere((e)=>e.namaKategori==s); setState((){ kategoriTerpilih=kat; katNamaC.text=kat.namaKategori; katTarifC.text=kat.tarifPerHari.toString(); }); },
              fieldViewBuilder: (ctx,ctrl,fn,_) => TextField(controller: ctrl, focusNode: fn, decoration: const InputDecoration(labelText: "Nama Kategori", border: OutlineInputBorder())),
              optionsViewBuilder: (context, onSelected, options) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4, child: SizedBox(width: 300, child: ListView.builder(shrinkWrap: true, itemCount: options.length, itemBuilder: (_, i) => ListTile(title: Text(options.elementAt(i)), onTap: ()=>onSelected(options.elementAt(i))))))),
            );
          }),
          const SizedBox(height: 8),
          TextField(controller: katTarifC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Tarif/Hari", border: OutlineInputBorder(), prefixText: "Rp ")),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.save), label: const Text("Tambah / Update Kategori"), style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade800, foregroundColor: Colors.white), onPressed: () async { if (katNamaC.text.isEmpty||katTarifC.text.isEmpty) return; final ex = await (db.select(db.kategoriKaryawan)..where((t)=>t.namaKategori.equals(katNamaC.text))).getSingleOrNull(); if(ex!=null){ await (db.update(db.kategoriKaryawan)..where((t)=>t.id.equals(ex.id))).write(KategoriKaryawanCompanion(tarifPerHari: drift.Value(int.parse(katTarifC.text)))); } else { await db.into(db.kategoriKaryawan).insert(KategoriKaryawanCompanion.insert(namaKategori: katNamaC.text, tarifPerHari: int.parse(katTarifC.text))); } katNamaC.clear(); katTarifC.clear(); setState(()=> kategoriTerpilih=null); })),

          const Divider(height: 32),
          const Text("2. Tambah Karyawan + Foto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          TextField(controller: karNamaC, decoration: const InputDecoration(labelText: "Nama Karyawan", border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [fotoPathTemp!=null? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(fotoPathTemp!), width: 60, height: 60, fit: BoxFit.cover)) : Container(width:60,height:60,decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person)), const SizedBox(width: 12), ElevatedButton.icon(icon: const Icon(Icons.camera_alt), label: const Text("Foto Kamera"), onPressed: pickFoto)]),
          const SizedBox(height: 12),
          StreamBuilder<List<KategoriKaryawanData>>(stream: db.watchKategori(), builder: (c,snap){ if(!snap.hasData) return const CircularProgressIndicator(); if(snap.data!.isEmpty) return const Text("Buat kategori dulu"); return Column(children: snap.data!.map((kat)=> Card(child: ListTile(title: Text(kat.namaKategori), subtitle: Text("Rp ${formatRp.format(kat.tarifPerHari)}/hari"), trailing: kategoriTerpilih?.id==kat.id? const Icon(Icons.check_circle,color: Colors.green) : ElevatedButton(child: const Text("Pilih"), onPressed: (){ setState((){ kategoriTerpilih=kat; katNamaC.text=kat.namaKategori; katTarifC.text=kat.tarifPerHari.toString(); }); })))).toList()); }),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,height:50,child: ElevatedButton.icon(icon: const Icon(Icons.person_add), label: Text(kategoriTerpilih==null? "Pilih Kategori Dulu" : "Simpan Karyawan"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: kategoriTerpilih==null? null : () async { if(karNamaC.text.isEmpty) return; await db.into(db.karyawan).insert(KaryawanCompanion.insert(nama: karNamaC.text, kategoriId: kategoriTerpilih!.id, fotoPath: drift.Value(fotoPathTemp))); setState((){ karNamaC.clear(); fotoPathTemp=null; kategoriTerpilih=null; }); })),

          const Divider(height: 32),
          const Text("3. Data Karyawan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          StreamBuilder<List<KaryawanData>>(
            stream: db.watchKaryawan(),
            builder: (c,snap){
              if(!snap.hasData) return const Center(child: CircularProgressIndicator());
              if(snap.data!.isEmpty) return const Text("Belum ada karyawan");
              return Column(
                children: snap.data!.map((k){
                  return FutureBuilder<KategoriKaryawanData?>(
                    future: (db.select(db.kategoriKaryawan)..where((t)=>t.id.equals(k.kategoriId))).getSingleOrNull(),
                    builder: (c,katSnap){
                      final kat=katSnap.data;
                      return Card(child: ListTile(
                        leading: k.fotoPath!=null? ClipOval(child: Image.file(File(k.fotoPath!), width:50,height:50,fit:BoxFit.cover)) : CircleAvatar(child: Text(k.nama.isNotEmpty? k.nama[0] : '?')),
                        title: Text(k.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("ID:${k.id} | ${kat?.namaKategori??''} | Rp ${kat!=null? formatRp.format(kat.tarifPerHari) : '0'}/hari"),
                        trailing: IconButton(icon: const Icon(Icons.delete,color: Colors.red), onPressed: () async { await (db.delete(db.karyawan)..where((t)=>t.id.equals(k.id))).go(); }),
                      ));
                    }
                  );
                }).toList(),
              );
            }
          ),
        ])
      )
    );
  }
}