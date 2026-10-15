import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../dbases/localdatabase.dart';
import 'backup_service.dart';

class OwnerPage extends StatefulWidget {
  const OwnerPage({super.key});
  @override State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  final db = AppDatabase();
  final ImagePicker _picker = ImagePicker();
  final fmt = NumberFormat("#,###", "id_ID");

  final _kategoriController = TextEditingController();
  final _tarifController = TextEditingController();
  final _namaKaryawanController = TextEditingController();

  KategoriKaryawanData? _selectedKategori;
  File? _selectedImage;
  bool _isBackupLoading = false;

  static const caramel = Color(0xFFA87336);
  static const cinnamon = Color(0xFF8F5D2E);
  static const mediumBrown = Color(0xFF7A4B26);
  static const coffee = Color(0xFF613A1E);
  static const roast = Color(0xFF3B2011);
  static const cream = Color(0xFFFDF6EC);

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.camera_alt, color: cinnamon), title: const Text('Kamera'), onTap: () { Navigator.of(ctx).pop(); _pickImage(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.photo_library, color: cinnamon), title: const Text('Galeri'), onTap: () { Navigator.of(ctx).pop(); _pickImage(ImageSource.gallery); }),
      ])),
    );
  }

  Future<void> _simpanKategori() async {
    if (_kategoriController.text.trim().isEmpty || _tarifController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi nama & tarif!')));
      return;
    }
    await db.tambahKategori(_kategoriController.text.trim(), int.tryParse(_tarifController.text.trim()) ?? 0);
    _kategoriController.clear(); _tarifController.clear();
    setState((){});
  }

  Future<void> _simpanKaryawan() async {
    if (_namaKaryawanController.text.trim().isEmpty || _selectedKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi nama & pilih kategori!')));
      return;
    }
    await db.tambahKaryawan(_namaKaryawanController.text.trim(), _selectedKategori!.id, _selectedImage?.path);
    setState(() { _namaKaryawanController.clear(); _selectedKategori = null; _selectedImage = null; });
  }

  // DIALOG PINDAH KATEGORI - NAIK/TURUN LEVEL
  void _dialogPindahKategori(KaryawanData kar) {
    int? selectedKatId = kar.kategoriId;
    showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        title: Text("Pindah Level ${kar.nama}", style: TextStyle(color: roast, fontWeight: FontWeight.bold, fontSize: 14)),
        content: StreamBuilder<List<KategoriKaryawanData>>(
          stream: db.watchKategori(),
          builder: (c, snap) {
            final cats = snap.data ?? [];
            return DropdownButtonFormField<int>(
              value: selectedKatId,
              decoration: InputDecoration(labelText: 'Pilih Kategori Baru', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: cats.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.namaKategori} - Rp ${fmt.format(e.tarifPerHari)}'))).toList(),
              onChanged: (v) => selectedKatId = v,
            );
          }
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx), child: Text("Batal", style: TextStyle(color: cinnamon))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: roast),
            onPressed: () async {
              if (selectedKatId != null && selectedKatId != kar.kategoriId) {
                await db.pindahKategoriKaryawan(kar.id, selectedKatId!);
                if (ctx.mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${kar.nama} pindah kategori, gaji minggu ini pakai tarif baru"), backgroundColor: roast)
                );
              }
            },
            child: Text("Pindahkan", style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    });
  }

  Future<void> _handleBackup() async {
    if (_isBackupLoading) return;
    setState(() => _isBackupLoading = true);
    final path = await BackupService.exportBackup();
    if (!mounted) return;
    setState(() => _isBackupLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: path != null ? roast : Colors.red,
      content: Text(path != null ? 'Backup OK: $path' : 'Gagal backup'),
    ));
  }

  Future<void> _handleRestore() async {
    setState(() => _isBackupLoading = true);
    final hasil = await BackupService.importBackup();
    if (!mounted) return;
    setState(() => _isBackupLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: hasil.contains('SUKSES') ? roast : Colors.red,
      content: Text(hasil),
    ));
    if (hasil.contains('SUKSES')) setState(() {});
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: caramel.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: roast.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1, color: roast)),
        const SizedBox(height: 12),
       ...children,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [roast, coffee, cinnamon], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _isBackupLoading ? null : _handleBackup,
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Backup'),
                style: ElevatedButton.styleFrom(backgroundColor: caramel, foregroundColor: Colors.white),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: _isBackupLoading ? null : _handleRestore,
                icon: const Icon(Icons.cloud_download, size: 18),
                label: const Text('Restore'),
                style: ElevatedButton.styleFrom(backgroundColor: cream, foregroundColor: roast),
              )),
            ]),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () async {
              final jml = await db.bersihkanIdNol();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Dibersihkan $jml data ID:0"), backgroundColor: roast));
              setState((){});
            },
            icon: Icon(Icons.cleaning_services),
            label: Text("Bersihkan ID:0 (jika masih ada)"),
            style: ElevatedButton.styleFrom(backgroundColor: mediumBrown, foregroundColor: Colors.white),
          ),
          const SizedBox(height: 16),
          _sectionCard(title: 'TAMBAH KATEGORI / JABATAN', children: [
            TextField(controller: _kategoriController, decoration: InputDecoration(labelText: 'Nama Kategori', filled: true, fillColor: cream, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: caramel)))),
            const SizedBox(height: 10),
            TextField(controller: _tarifController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Tarif / Hari (Rp)', filled: true, fillColor: cream, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _simpanKategori, style: ElevatedButton.styleFrom(backgroundColor: mediumBrown, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Simpan Kategori'))),
          ]),
          _sectionCard(title: 'TAMBAH KARYAWAN', children: [
            Center(child: GestureDetector(onTap: _showImageSourceModal, child: Stack(alignment: Alignment.bottomRight, children: [
              CircleAvatar(radius: 40, backgroundColor: caramel.withOpacity(0.2), backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null, child: _selectedImage == null ? const Icon(Icons.person, size: 40, color: cinnamon) : null),
              const CircleAvatar(radius: 14, backgroundColor: roast, child: Icon(Icons.camera_alt, size: 14, color: Colors.white)),
            ]))),
            const SizedBox(height: 12),
            TextField(controller: _namaKaryawanController, decoration: InputDecoration(labelText: 'Nama Karyawan', filled: true, fillColor: cream, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 10),
            StreamBuilder<List<KategoriKaryawanData>>(stream: db.watchKategori(), builder: (context, snap) {
              final cats = snap.data ?? [];
              return DropdownButtonFormField<KategoriKaryawanData>(
                value: _selectedKategori,
                decoration: InputDecoration(labelText: 'Pilih Kategori', filled: true, fillColor: cream, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: cats.map((e) => DropdownMenuItem(value: e, child: Text('${e.namaKategori} - Rp ${fmt.format(e.tarifPerHari)}'))).toList(),
                onChanged: (v) => setState(() => _selectedKategori = v),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _simpanKaryawan, style: ElevatedButton.styleFrom(backgroundColor: coffee, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Simpan Karyawan'))),
          ]),
          _sectionCard(title: 'DAFTAR KARYAWAN - TAP UNTUK PINDAH LEVEL', children: [
            StreamBuilder<List<KaryawanData>>(stream: db.watchKaryawan(), builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) return const Text('Belum ada karyawan', style: TextStyle(color: cinnamon));
              return Column(children: list.map((e) => ListTile(
                leading: CircleAvatar(backgroundColor: caramel.withOpacity(0.3), backgroundImage: e.fotoPath != null && File(e.fotoPath!).existsSync() ? FileImage(File(e.fotoPath!)) : null, child: e.fotoPath == null ? Text(e.nama[0].toUpperCase(), style: const TextStyle(color: roast)) : null),
                title: Text(e.nama, style: const TextStyle(color: roast, fontWeight: FontWeight.w600)),
                subtitle: Text("Tap untuk pindah kategori", style: TextStyle(fontSize: 10, color: cinnamon)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.swap_horiz, color: coffee), tooltip: "Pindah Kategori", onPressed: () => _dialogPindahKategori(e)),
                  IconButton(icon: const Icon(Icons.delete, color: cinnamon), onPressed: () => db.hapusKaryawan(e.id)),
                ]),
                onTap: () => _dialogPindahKategori(e),
              )).toList());
            }),
          ]),
        ]),
      ),
    );
  }
}
