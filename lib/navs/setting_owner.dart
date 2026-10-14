import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../dbases/localdatabase.dart';
import '../dbases/setowner_db.dart';
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
  static const coffee = Color(0xFF613A1E);
  static const espresso = Color(0xFF4E2D17);
  static const roast = Color(0xFF3B2011);

  @override void dispose() {
    _kategoriController.dispose();
    _tarifController.dispose();
    _namaKaryawanController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image!= null) setState(() => _selectedImage = File(image.path));
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.camera_alt, color: caramel), title: const Text('Ambil Foto dari Kamera'), onTap: () { Navigator.of(ctx).pop(); _pickImage(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.photo_library, color: caramel), title: const Text('Pilih dari Galeri'), onTap: () { Navigator.of(ctx).pop(); _pickImage(ImageSource.gallery); }),
      ])),
    );
  }

  Widget _buildAvatar(String? path) {
    if (path!= null && path.trim().isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) return CircleAvatar(radius: 20, backgroundImage: FileImage(file));
    }
    return const CircleAvatar(radius: 20, backgroundColor: coffee, child: Icon(Icons.person, color: Colors.white, size: 20));
  }

  Future<void> _simpanKategori() async {
    final nama = _kategoriController.text.trim();
    final tarifStr = _tarifController.text.trim();
    if (nama.isEmpty || tarifStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi nama kategori dan tarif per hari!')));
      return;
    }
    final tarif = int.tryParse(tarifStr)?? 0;
    await db.tambahKategori(nama, tarif);
    _kategoriController.clear(); _tarifController.clear();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: coffee, content: const Text('Kategori berhasil disimpan', style: TextStyle(color: Colors.white))));
  }

  Future<void> _simpanKaryawan() async {
    final nama = _namaKaryawanController.text.trim();
    if (nama.isEmpty || _selectedKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi nama karyawan dan pilih kategori!')));
      return;
    }
    await db.tambahKaryawan(nama, _selectedKategori!.id, _selectedImage?.path);
    setState(() { _namaKaryawanController.clear(); _selectedKategori = null; _selectedImage = null; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: coffee, content: const Text('Karyawan berhasil ditambahkan', style: TextStyle(color: Colors.white))));
  }

  // --- FIX BACKUP KE DOWNLOAD ---
  Future<void> _handleBackup() async {
    if (_isBackupLoading) return;
    setState(() => _isBackupLoading = true);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup ke folder Download...'), duration: Duration(seconds: 1)));
      }
      final path = await BackupService.exportBackup();
      if (!mounted) return;
      if (path!= null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: roast,
          duration: const Duration(seconds: 5),
          content: Text('Backup (.bskro) Berhasil!\nSimpan di:\n$path', style: const TextStyle(color: Color(0xFFA87336))),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text('Gagal backup. Aktifkan izin File & Media di Pengaturan.')));
      }
    } finally {
      if (mounted) setState(() => _isBackupLoading = false);
    }
  }

      Future<void> _handleRestore() async {
    setState(() => _isBackupLoading = true);
    final hasil = await BackupService.importBackup();
    if (!mounted) return;
    setState(() => _isBackupLoading = false);
    
    if (hasil == 'SUKSES') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFF3B2011), content: Text('Restore berhasil! Data ditimpa.', style: TextStyle(color: Color(0xFFA87336)))),
      );
      setState(() {});
    } else if (hasil == 'BATAL') {
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(hasil)), // ini akan kasih tau error aslinya
      );
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('BACKUP & RESTORE DATA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _isBackupLoading? null : _handleBackup, icon: _isBackupLoading? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload, size: 18), label: const Text('Backup (.bskro)'), style: ElevatedButton.styleFrom(backgroundColor: roast, foregroundColor: Color(0xFFA87336), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(onPressed: _handleRestore, icon: const Icon(Icons.cloud_download, size: 18), label: const Text('Restore (.bskro)'), style: ElevatedButton.styleFrom(backgroundColor: caramel.withOpacity(0.25), foregroundColor: roast, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: caramel))))),
          ]),
          const Divider(height: 32, thickness: 1),
          const Text('TAMBAH KATEGORI / JABATAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 8),
          TextField(controller: _kategoriController, decoration: const InputDecoration(labelText: 'Nama Kategori', isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: _tarifController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tarif/Hari (Rp)', isDense: true)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _simpanKategori, style: ElevatedButton.styleFrom(backgroundColor: caramel.withOpacity(0.2), foregroundColor: roast, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Simpan Kategori'))),
          const Divider(height: 32, thickness: 1),
          const Text('TAMBAH KARYAWAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 12),
          Center(child: GestureDetector(onTap: _showImageSourceModal, child: Stack(alignment: Alignment.bottomRight, children: [CircleAvatar(radius: 36, backgroundColor: Colors.grey.shade300, backgroundImage: _selectedImage!= null? FileImage(_selectedImage!) : null, child: _selectedImage == null? const Icon(Icons.person, size: 40, color: Colors.grey) : null), CircleAvatar(radius: 12, backgroundColor: roast, child: const Icon(Icons.camera_alt, size: 12, color: Colors.white))]))),
          const SizedBox(height: 8),
          TextField(controller: _namaKaryawanController, decoration: const InputDecoration(labelText: 'Nama Karyawan', isDense: true)),
          const SizedBox(height: 12),
          StreamBuilder<List<KategoriKaryawanData>>(stream: db.watchKategori(), builder: (context, snapshot) {
            final categories = snapshot.data?? [];
            return Autocomplete<KategoriKaryawanData>(displayStringForOption: (option) => '${option.namaKategori} - Rp ${fmt.format(option.tarifPerHari)}', optionsBuilder: (textEditingValue) { if (textEditingValue.text.isEmpty) return categories; return categories.where((o) => o.namaKategori.toLowerCase().contains(textEditingValue.text.toLowerCase())); }, onSelected: (selection) { setState(() => _selectedKategori = selection); }, fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) { return TextField(controller: textEditingController, focusNode: focusNode, decoration: InputDecoration(labelText: 'Pilih Kategori / Jabatan', isDense: true, suffixIcon: textEditingController.text.isNotEmpty? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { textEditingController.clear(); setState(() => _selectedKategori = null); }) : const Icon(Icons.arrow_drop_down))); }, optionsViewBuilder: (context, onSelected, options) { return Align(alignment: Alignment.topLeft, child: Material(elevation: 4, borderRadius: BorderRadius.circular(8), child: Container(width: MediaQuery.of(context).size.width - 32, constraints: const BoxConstraints(maxHeight: 200), child: ListView.builder(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length, itemBuilder: (context, index) { final option = options.elementAt(index); return ListTile(title: Text(option.namaKategori), subtitle: Text('Rp ${fmt.format(option.tarifPerHari)} / hari'), onTap: () => onSelected(option)); })))); });
          }),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _simpanKaryawan, style: ElevatedButton.styleFrom(backgroundColor: caramel.withOpacity(0.2), foregroundColor: roast, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Simpan Karyawan'))),
          const Divider(height: 32, thickness: 1),
          const Text('DAFTAR KARYAWAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 8),
          StreamBuilder<List<KaryawanData>>(stream: db.watchKaryawan(), builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Text("Error: ${snapshot.error}");
            final list = snapshot.data?? [];
            if (list.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Belum ada data karyawan.', style: TextStyle(color: Colors.grey)));
            return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: list.length, itemBuilder: (context, index) { final item = list[index]; return ListTile(contentPadding: EdgeInsets.zero, leading: _buildAvatar(item.fotoPath), title: Text(item.nama, style: const TextStyle(fontWeight: FontWeight.w500)), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { await db.hapusKaryawan(item.id); })); });
          }),
        ]),
      ),
    );
  }
}