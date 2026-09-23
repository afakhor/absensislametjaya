import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../dbases/localdatabase.dart';
import '../dbases/absen_db.dart';
import '../dbases/audit_db.dart';
import '../dbases/gaji_db.dart';
import '../dbases/setowner_db.dart';

class AbsenPage extends StatefulWidget {
  const AbsenPage({super.key});
  @override State<AbsenPage> createState() => _AbsenPageState();
}

class _AbsenPageState extends State<AbsenPage> {
  final db = AppDatabase();
  final auth = LocalAuthentication();
  String _statusIjin = "Cek ijin...";
  DateTime _tglPilih = DateTime.now();

  @override void initState() {
    super.initState();
    _requestSemuaIjinAndroid();
  }

  Future<void> _requestSemuaIjinAndroid() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera, Permission.storage, Permission.photos,
      Permission.location, Permission.locationWhenInUse,
      Permission.bluetooth, Permission.bluetoothScan, Permission.bluetoothConnect,
      Permission.bluetoothAdvertise, Permission.sensors,
    ].request();
    bool allGranted = statuses.values.every((s) => s.isGranted || s.isLimited);
    setState(() => _statusIjin = allGranted? "Semua ijin OK" : "Ada ijin ditolak, cek setting HP");
  }

  Future<bool> _cekFingerprintSupport() async {
    try {
      await Permission.sensors.request();
      final canCheck = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();
      final available = await auth.getAvailableBiometrics();
      return canCheck && isDeviceSupported && available.isNotEmpty;
    } catch (_) { return false; }
  }

  Future<void> _dialogTipeKerja(KaryawanData k, KategoriKaryawanData? kat, {required bool isFingerprint}) async {
    String tipe = 'FULL';
    final alasanC = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text("Absen - ID:${k.id} ${k.nama}", style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Owner tentukan: 1 hari atau ½ hari", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              RadioListTile<String>(
                title: Text("1 Hari (8 jam) - Rp ${kat?.tarifPerHari?? 0}"),
                value: 'FULL', groupValue: tipe,
                onChanged: (v) => setD(() => tipe = v!),
              ),
              RadioListTile<String>(
                title: Text("½ Hari (4 jam) - Rp ${(kat?.tarifPerHari?? 0) ~/ 2}"),
                value: 'SETENGAH', groupValue: tipe,
                onChanged: (v) => setD(() => tipe = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: alasanC, decoration: const InputDecoration(labelText: "Keterangan", border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("SIMPAN ABSEN"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
              onPressed: () async {
                // CEK BOCOR DI SINI - KUNCI UTAMA
                final sudah = await db.sudahAbsenHariIni(k.id, _tglPilih);
                if(sudah){
                  if(ctx.mounted) Navigator.pop(ctx);
                  if(!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: Colors.red.shade700, content: Text('ID:${k.id} ${k.nama} sudah absen hari ini', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  );
                  return;
                }

                try{
                  Navigator.pop(ctx);
                  double jam = tipe == 'FULL'? 8.0 : 4.0;
                  await db.into(db.absensi).insert(AbsensiCompanion.insert(
                    karyawanId: k.id,
                    jamMasuk: DateTime(_tglPilih.year, _tglPilih.month, _tglPilih.day, DateTime.now().hour, DateTime.now().minute),
                    totalJamKerja: drift.Value(jam),
                    metode: isFingerprint? 'FINGERPRINT' : 'MANUAL_OWNER_ID:${k.id}',
                    keterangan: drift.Value(alasanC.text.isEmpty? (tipe == 'FULL'? "Kerja Full" : "Setengah Hari") : alasanC.text),
                    tipeKerja: drift.Value(tipe),
                  ));
                  await db.catatAudit(
                    aktor: isFingerprint? k.nama : 'OWNER',
                    aksi: isFingerprint? 'ABSEN_FINGERPRINT' : 'MANUAL_OVERRIDE',
                    target: "ID:${k.id} - ${k.nama}",
                    detail: "Tgl ${_tglPilih.day}/${_tglPilih.month}/${_tglPilih.year} Tipe $tipe",
                  );
                  await db.prosesHitungGajiMingguan();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ ID:${k.id} ${k.nama} $tipe")));
                } catch(e){
                  if(e.toString().contains('SUDAH_ABSEN')){
                    if(!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text('ID:${k.id} ${k.nama} sudah absen hari ini')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prosesFingerprint(KaryawanData k, KategoriKaryawanData? kat) async {
    final sudah = await db.sudahAbsenHariIni(k.id, _tglPilih);
    if(sudah){
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red.shade700, content: Text('ID:${k.id} ${k.nama} sudah absen hari ini', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
      return;
    }

    await _requestSemuaIjinAndroid();
    final support = await _cekFingerprintSupport();
    if (!support) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fingerprint tidak aktif di HP ini")));
      return;
    }
    try {
      bool ok = await auth.authenticate(localizedReason: 'Absen ${k.nama} - ID:${k.id}', options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true));
      if (!ok) return;
      await _dialogTipeKerja(k, kat, isFingerprint: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fingerprint gagal: $e")));
    }
  }

  void _manualDenganIdKaryawan() {
    KaryawanData? karyawanTerpilih; KategoriKaryawanData? kategoriTerpilih;
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setStateDialog) {
      return AlertDialog(
        title: const Text("Manual Owner - Pakai ID"),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          StreamBuilder<List<KaryawanData>>(stream: db.watchKaryawan(), builder: (context, snapKaryawan) {
            final listKaryawan = snapKaryawan.data?? [];
            return FutureBuilder<List<KategoriKaryawanData>>(future: db.select(db.kategoriKaryawan).get(), builder: (context, snapKat) {
              final listKategori = snapKat.data?? [];
              Map<int, KategoriKaryawanData> katMap = {for (var k in listKategori) k.id: k};
              return Autocomplete<KaryawanData>(
                displayStringForOption: (k) => "${k.id} - ${k.nama}",
                optionsBuilder: (val) => val.text == ''? listKaryawan : listKaryawan.where((e) => e.id.toString().contains(val.text) || e.nama.toLowerCase().contains(val.text.toLowerCase())),
                onSelected: (k) => setStateDialog(() { karyawanTerpilih = k; kategoriTerpilih = katMap[k.kategoriId]; }),
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(controller: controller, focusNode: focusNode, decoration: const InputDecoration(labelText: "ID Karyawan", border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge))),
                optionsViewBuilder: (context, onSelected, options) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4, child: SizedBox(width: 300, child: ListView.builder(shrinkWrap: true, itemCount: options.length, itemBuilder: (_, i) {
                  final k = options.elementAt(i); final kat = katMap[k.kategoriId];
                  return ListTile(title: Text("ID:${k.id} - ${k.nama}"), subtitle: Text("${kat?.namaKategori} - Rp ${kat?.tarifPerHari}/hari"), onTap: () => onSelected(k));
                })))),
              );
            });
          }),
          const SizedBox(height: 12),
          if (karyawanTerpilih!= null) FutureBuilder<bool>(future: db.sudahAbsenHariIni(karyawanTerpilih!.id, _tglPilih), builder: (c,snap){
            final sudah = snap.data??false;
            return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: sudah? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: sudah? Colors.red.shade200 : Colors.green.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("ID: ${karyawanTerpilih!.id} - ${karyawanTerpilih!.nama}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("Gaji: Rp ${kategoriTerpilih?.tarifPerHari}/hari"),
              if(sudah) Text("⚠️ ID:${karyawanTerpilih!.id} ${karyawanTerpilih!.nama} sudah absen hari ini", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
            ]));
          }),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(onPressed: karyawanTerpilih == null? null : () async {
            final sudah = await db.sudahAbsenHariIni(karyawanTerpilih!.id, _tglPilih);
            if(sudah){
              if(!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red.shade700, content: Text('ID:${karyawanTerpilih!.id} ${karyawanTerpilih!.nama} sudah absen hari ini')));
              return;
            }
            Navigator.pop(context); 
            _dialogTipeKerja(karyawanTerpilih!, kategoriTerpilih, isFingerprint: false); 
          }, child: const Text("LANJUT")),
        ],
      );
    }));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Absen Wajib ${_tglPilih.day}/${_tglPilih.month} - $_statusIjin"), backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.calendar_today), onPressed: () async { final p = await showDatePicker(context: context, initialDate: _tglPilih, firstDate: DateTime(2023), lastDate: DateTime(2030)); if (p!= null) setState(() => _tglPilih = p); })]),
      floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.admin_panel_settings), label: const Text("Input Manual pakai ID"), onPressed: _manualDenganIdKaryawan),
      body: StreamBuilder<List<KaryawanData>>(stream: db.watchKaryawan(), builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        if (s.data!.isEmpty) return const Center(child: Text("Belum ada karyawan"));
        return StreamBuilder<List<AbsensiData>>(stream: db.watchAbsensiHari(_tglPilih), builder: (c, absenSnap) {
          final absenHariIni = absenSnap.data?? [];
          return ListView.builder(itemCount: s.data!.length, itemBuilder: (_, i) {
            var k = s.data![i];
            return FutureBuilder<KategoriKaryawanData?>(future: (db.select(db.kategoriKaryawan)..where((t) => t.id.equals(k.kategoriId))).getSingleOrNull(), builder: (c, katSnap) {
              final kat = katSnap.data; final absenKaryawan = absenHariIni.where((a) => a.karyawanId == k.id).toList(); final sudahAbsen = absenKaryawan.isNotEmpty;
              return Card(color: sudahAbsen? Colors.green.shade50 : Colors.red.shade50, child: ListTile(
                leading: k.fotoPath!= null? ClipOval(child: Image.file(File(k.fotoPath!), width: 50, height: 50, fit: BoxFit.cover)) : CircleAvatar(backgroundColor: sudahAbsen? Colors.green : Colors.red, child: Text(k.id.toString(), style: const TextStyle(color: Colors.white))),
                title: Text("ID:${k.id} - ${k.nama}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Kategori: ${kat?.namaKategori} - Rp ${kat?.tarifPerHari}/hari"),
                  Text(sudahAbsen? "✅ SUDAH ${absenKaryawan.first.tipeKerja} - ${absenKaryawan.first.keterangan}" : "❌ BELUM ABSEN - GAK GAJIAN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sudahAbsen? Colors.green.shade700 : Colors.red)),
                ]),
                trailing: sudahAbsen
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
                  : IconButton(icon: const Icon(Icons.fingerprint, color: Colors.green, size: 32), onPressed: () => _prosesFingerprint(k, kat)),
                onTap: sudahAbsen? (){
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ID:${k.id} ${k.nama} sudah absen hari ini')));
                } : null,
              ));
            });
          });
        });
      }),
    );
  }
}