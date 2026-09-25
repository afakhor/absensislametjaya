import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../dbases/localdatabase.dart';
import '../dbases/setowner_db.dart';

class SettingOwnerPage extends StatefulWidget {
  const SettingOwnerPage({super.key});
  @override
  State<SettingOwnerPage> createState() => _SettingOwnerPageState();
}

class _SettingOwnerPageState extends State<SettingOwnerPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###", "id_ID");
  final namaKarC = TextEditingController();
  final namaKatC = TextEditingController();
  final tarifKatC = TextEditingController();
  int? selectedKategoriId;

  @override
  void dispose() {
    namaKarC.dispose();
    namaKatC.dispose();
    tarifKatC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text("TAMBAH KATEGORI / JABATAN", style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: namaKatC, decoration: const InputDecoration(labelText: "Nama Kategori (misal: Tukang)")),
          TextField(controller: tarifKatC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Tarif/Hari (Rp)")),
          ElevatedButton(
            onPressed: () async {
              if (namaKatC.text.isNotEmpty && tarifKatC.text.isNotEmpty) {
                await db.tambahKategori(namaKatC.text, int.parse(tarifKatC.text));
                namaKatC.clear();
                tarifKatC.clear();
                setState(() {});
              }
            },
            child: const Text("Simpan Kategori"),
          ),
          const Divider(height: 32),
          const Text("TAMBAH KARYAWAN", style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: namaKarC, decoration: const InputDecoration(labelText: "Nama Karyawan")),
          StreamBuilder<List<KategoriKaryawanData>>(
            stream: db.watchKategori(),
            builder: (c, snap) {
              final list = snap.data ?? [];
              return DropdownButton<int>(
                value: selectedKategoriId,
                hint: const Text("Pilih Kategori"),
                isExpanded: true,
                items: list.map((k) => DropdownMenuItem(value: k.id, child: Text("${k.namaKategori} - Rp ${fmt.format(k.tarifPerHari)}"))).toList(),
                onChanged: (v) => setState(() => selectedKategoriId = v),
              );
            },
          ),
          ElevatedButton(
            onPressed: () async {
              if (namaKarC.text.isNotEmpty && selectedKategoriId != null) {
                await db.tambahKaryawan(namaKarC.text, selectedKategoriId!, null);
                namaKarC.clear();
                setState(() {});
              }
            },
            child: const Text("Simpan Karyawan"),
          ),
          const Divider(height: 32),
          const Text("DAFTAR KARYAWAN", style: TextStyle(fontWeight: FontWeight.bold)),
          StreamBuilder<List<KaryawanData>>(
            stream: db.watchKaryawan(),
            builder: (c, snap) {
              final list = snap.data ?? [];
              return Column(
                children: list.map((k) => ListTile(
                  title: Text(k.nama),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => db.hapusKaryawan(k.id),
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
