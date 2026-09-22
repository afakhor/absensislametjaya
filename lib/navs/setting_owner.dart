import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../database.dart';

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
    return Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("1. Kategori & Tarif (Auto Complete)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      StreamBuilder<List<KategoriKaryawanData>>(stream: db.select(db.kategoriKaryawan).watch(), builder: (context, snap) {
        final listKat = snap.data?? [];
        final namaList = listKat.map((e) => e.namaKategori).toList();
        return Autocomplete<String>(optionsBuilder: (val) { if (val.text=='') return namaList; return namaList.where((e) => e.toLowerCase().contains(val.text.toLowerCase())); }, onSelected: (s){ final kat = listKat.firstWhere((e) => e.namaKategori==s); setState((){ kategoriTerpilih=kat; katNamaC.text=kat.namaKategori; katTarifC.text=kat.tarifPerJam.toString(); }); }, fieldViewBuilder: (ctx,ctrl,fn,_) => TextField(controller: ctrl, focusNode: fn, decoration: const InputDecoration(labelText: "Nama Kategori (Operator, Senior...)", border: OutlineInputBorder(), suffixIcon: Icon(Icons.history)), onChanged: (v){ katNamaC.text=v; final found=listKat.where((e)=>e.namaKategori.toLowerCase()==v.toLowerCase()).toList(); if(found.isNotEmpty){ setState((){ kategoriTerpilih=found.first; katTarifC.text=found.first.tarifPerJam.toString(); }); } }));
      }),
      const SizedBox(height: 8),
      TextField(controller: katTarifC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Tarif/Jam (auto keisi)", border: OutlineInputBorder())),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.save), label: const Text("Tambah / Update Kategori"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white), onPressed: () async { if (katNamaC.text.isEmpty||katTarifC.text.isEmpty) return; final ex = await (db.select(db.kategoriKaryawan)..where((t)=>t.namaKategori.equals(katNamaC.text))).getSingleOrNull(); if(ex!=null){ await (db.update(db.kategoriKaryawan)..where((t)=>t.id.equals(ex.id))).write(KategoriKaryawanCompanion(tarifPerJam: drift.Value(int.parse(katTarifC.text)))); } else { await db.into(db.kategoriKaryawan).insert(KategoriKaryawanCompanion.insert(namaKategori: katNamaC.text, tarifPerJam: int.parse(katTarifC.text))); } katNamaC.clear(); katTarifC.clear(); setState(()=> kategoriTerpilih=null); })),

      const Divider(height: 32),
      const Text("2. Tambah Karyawan + Foto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      TextField(controller: karNamaC, decoration: const InputDecoration(labelText: "Nama Karyawan", border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Row(children: [fotoPathTemp!=null? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(fotoPathTemp!), width: 60, height: 60, fit: BoxFit.cover)) : Container(width:60,height:60,decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person)), const SizedBox(width: 12), ElevatedButton.icon(icon: const Icon(Icons.camera_alt), label: const Text("Foto"), onPressed: pickFoto)]),
      const SizedBox(height: 12),
      StreamBuilder<List<KategoriKaryawanData>>(stream: db.select(db.kategoriKaryawan).watch(), builder: (c,snap){ if(!snap.hasData) return const CircularProgressIndicator(); if(snap.data!.isEmpty) return const Text("Buat kategori dulu"); return Column(children: snap.data!.map((kat)=> Card(color: kategoriTerpilih?.id==kat.id? Colors.orange.shade50:null, child: ListTile(leading: const Icon(Icons.work), title: Text(kat.namaKategori), subtitle: Text("Rp ${formatRp.format(kat.tarifPerJam)}/jam"), trailing: kategoriTerpilih?.id==kat.id? const Icon(Icons.check_circle,color: Colors.green) : ElevatedButton(child: const Text("Pilih"), onPressed: (){ setState((){ kategoriTerpilih=kat; katNamaC.text=kat.namaKategori; katTarifC.text=kat.tarifPerJam.toString(); }); })))).toList()); }),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity,height:50,child: ElevatedButton.icon(icon: const Icon(Icons.person_add), label: Text(kategoriTerpilih==null? "Pilih Kategori Dulu" : "Simpan Karyawan"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: kategoriTerpilih==null? null : () async { if(karNamaC.text.isEmpty) return; await db.into(db.karyawan).insert(KaryawanCompanion.insert(nama: karNamaC.text, kategoriId: kategoriTerpilih!.id, fotoPath: drift.Value(fotoPathTemp))); setState((){ karNamaC.clear(); fotoPathTemp=null; kategoriTerpilih=null; }); })),

      const Divider(height: 32),
      const Text("3. Data Karyawan (Tap Foto Preview)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      StreamBuilder<List<KaryawanData>>(stream: db.select(db.karyawan).watch(), builder: (c,snap){ if(!snap.hasData) return const CircularProgressIndicator(); if(snap.data!.isEmpty) return const Text("Belum ada karyawan"); return Column(children: snap.data!.map((k){ return FutureBuilder<KategoriKaryawanData?>(future: (db.select(db.kategoriKaryawan)..where((t)=>t.id.equals(k.kategoriId))).getSingleOrNull(), builder: (c,katSnap){ final kat=katSnap.data; return Card(elevation:3, child: ListTile(leading: GestureDetector(onTap: (){ if(k.fotoPath==null) return; showDialog(context: context, builder: (_)=> Dialog(child: Column(mainAxisSize: MainAxisSize.min, children: [Image.file(File(k.fotoPath!)), Padding(padding: const EdgeInsets.all(8), child: Text(k.nama, style: const TextStyle(fontWeight: FontWeight.bold))), TextButton(onPressed: ()=> Navigator.pop(context), child: const Text("Tutup"))]))); }, child: k.fotoPath!=null? ClipOval(child: Image.file(File(k.fotoPath!), width:50,height:50,fit:BoxFit.cover)) : CircleAvatar(child: Text(k.nama.isNotEmpty? k.nama[0] : '?'))), title: Text(k.nama, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Kategori: ${kat?.namaKategori?? 'Terhapus'}"), Text("Gaji: Rp ${kat!=null? formatRp.format(kat.tarifPerJam) : '0'}/jam", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold))]), trailing: IconButton(icon: const Icon(Icons.delete,color: Colors.red), onPressed: () async { await (db.delete(db.karyawan)..where((t)=>t.id.equals(k.id))).go(); })) ); }); }).toList()); })
    ])));
  }
}