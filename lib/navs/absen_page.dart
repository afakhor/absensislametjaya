import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:io';
import '../dbases/localdatabase.dart';
import '../dbases/absen_db.dart';
import '../dbases/audit_db.dart';
import '../dbases/gaji_db.dart';

class AbsenPage extends StatefulWidget {
  const AbsenPage({super.key});
  @override State<AbsenPage> createState() => _AbsenPageState();
}

class _AbsenPageState extends State<AbsenPage> {
  final db = AppDatabase();
  final auth = LocalAuthentication();

  Future<bool> _cekFingerprintSupport() async {
    try {
      final canCheck = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();
      final available = await auth.getAvailableBiometrics();
      return canCheck && isDeviceSupported && available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _prosesFingerprint(KaryawanData k, KategoriKaryawanData? kat) async {
    final support = await _cekFingerprintSupport();
    if (!support) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fingerprint tidak aktif / belum enroll di HP ini. Aktifkan di Pengaturan > Keamanan > Sidik Jari")));
      return;
    }

    try {
      bool ok = await auth.authenticate(
        localizedReason: 'Absen ${k.nama} - ID:${k.id} - ${kat?.namaKategori ?? ""}',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!ok) return;

      // AUTO SIMPAN FINGERPRINT SESUAI ID, NAMA, KATEGORI TERDAFTAR
      await db.absenFingerprint(k.id);
      await db.catatAudit(
        aktor: k.nama,
        aksi: 'ABSEN_FINGERPRINT',
        target: "ID:${k.id} - ${k.nama} - ${kat?.namaKategori ?? 'Tanpa Kategori'}",
        detail: 'Fingerprint valid 8 jam - Kategori ${kat?.namaKategori} - Tarif ${kat?.tarifPerJam}/jam',
      );
      await db.prosesHitungGajiMingguan();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Absen sukses ID:${k.id} ${k.nama} (${kat?.namaKategori})")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fingerprint gagal: $e")));
    }
  }

  void _manualDenganIdKaryawan() {
    final idC = TextEditingController();
    final alasanC = TextEditingController();
    KaryawanData? karyawanTerpilih;
    KategoriKaryawanData? kategoriTerpilih;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Manual Owner - Pakai ID Karyawan", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Ketik ID Karyawan (Auto Complete)", style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  // AUTO SUGGESTIONS ID KARYAWAN + NAMA + KATEGORI
                  StreamBuilder<List<KaryawanData>>(
                    stream: db.watchKaryawan(),
                    builder: (context, snapKaryawan) {
                      final listKaryawan = snapKaryawan.data ?? [];
                      return FutureBuilder<List<KategoriKaryawanData>>(
                        future: db.select(db.kategoriKaryawan).get(),
                        builder: (context, snapKat) {
                          final listKategori = snapKat.data ?? [];
                          Map<int, KategoriKaryawanData> katMap = {for (var k in listKategori) k.id: k};

                          return Autocomplete<KaryawanData>(
                            displayStringForOption: (k) => "${k.id} - ${k.nama}",
                            optionsBuilder: (TextEditingValue val) {
                              if (val.text == '') return listKaryawan;
                              return listKaryawan.where((e) =>
                                  e.id.toString().contains(val.text) ||
                                  e.nama.toLowerCase().contains(val.text.toLowerCase()));
                            },
                            onSelected: (KaryawanData k) {
                              setStateDialog(() {
                                karyawanTerpilih = k;
                                kategoriTerpilih = katMap[k.kategoriId];
                                idC.text = k.id.toString();
                              });
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "ID Karyawan (contoh: 1, 2, 3)",
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.badge),
                                  suffixIcon: Icon(Icons.history),
                                ),
                                onChanged: (v) {
                                  idC.text = v;
                                  final found = listKaryawan.where((e) => e.id.toString() == v).toList();
                                  if (found.isNotEmpty) {
                                    setStateDialog(() {
                                      karyawanTerpilih = found.first;
                                      kategoriTerpilih = katMap[found.first.kategoriId];
                                    });
                                  }
                                },
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  child: SizedBox(
                                    width: 300,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (_, i) {
                                        final k = options.elementAt(i);
                                        final kat = katMap[k.kategoriId];
                                        return ListTile(
                                          leading: k.fotoPath != null
                                              ? ClipOval(child: Image.file(File(k.fotoPath!), width: 35, height: 35, fit: BoxFit.cover))
                                              : CircleAvatar(child: Text(k.id.toString())),
                                          title: Text("ID:${k.id} - ${k.nama}"),
                                          subtitle: Text("${kat?.namaKategori ?? 'Tanpa Kategori'} - Rp ${kat?.tarifPerJam ?? 0}/jam"),
                                          onTap: () => onSelected(k),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // AUTO SINKRON TAMPILAN
                  if (karyawanTerpilih != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("ID Karyawan: ${karyawanTerpilih!.id}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text("Nama Karyawan: ${karyawanTerpilih!.nama}"),
                          Text("Kategori: ${kategoriTerpilih?.namaKategori ?? 'Terhapus'}"),
                          Text("Gaji: Rp ${kategoriTerpilih?.tarifPerJam ?? 0}/jam", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(controller: alasanC, decoration: const InputDecoration(labelText: "Alasan Wajib Manual", border: OutlineInputBorder())),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("SIMPAN MANUAL"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                onPressed: karyawanTerpilih == null
                    ? null
                    : () async {
                        await db.into(db.absensi).insert(AbsensiCompanion.insert(
                          karyawanId: karyawanTerpilih!.id,
                          jamMasuk: DateTime.now(),
                          totalJamKerja: const drift.Value(8.0),
                          metode: 'MANUAL_OWNER_ID:${karyawanTerpilih!.id}',
                          keterangan: drift.Value(alasanC.text.isEmpty ? 'Manual Owner' : alasanC.text),
                        ));
                        await db.catatAudit(
                          aktor: 'OWNER',
                          aksi: 'MANUAL_OVERRIDE',
                          target: "ID:${karyawanTerpilih!.id} - ${karyawanTerpilih!.nama}",
                          detail: "Kategori: ${kategoriTerpilih?.namaKategori} | Alasan: ${alasanC.text}",
                        );
                        await db.prosesHitungGajiMingguan();
                        if (context.mounted) Navigator.pop(context);
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.admin_panel_settings),
        label: const Text("Input Manual pakai ID"),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        onPressed: _manualDenganIdKaryawan,
      ),
      body: StreamBuilder<List<KaryawanData>>(
        stream: db.watchKaryawan(),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          if (s.data!.isEmpty) return const Center(child: Text("Belum ada karyawan. Ke menu Owner dulu\nTambah Karyawan + Foto + Kategori"));
          return ListView.builder(
            itemCount: s.data!.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (_, i) {
              var k = s.data![i];
              return FutureBuilder<KategoriKaryawanData?>(
                future: (db.select(db.kategoriKaryawan)..where((t) => t.id.equals(k.kategoriId))).getSingleOrNull(),
                builder: (c, katSnap) {
                  final kat = katSnap.data;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 2,
                    child: ListTile(
                      leading: k.fotoPath != null
                          ? ClipOval(child: Image.file(File(k.fotoPath!), width: 50, height: 50, fit: BoxFit.cover))
                          : CircleAvatar(backgroundColor: Colors.orange.shade100, child: Text(k.id.toString(), style: TextStyle(color: Colors.orange.shade800))),
                      title: Text("ID:${k.id} - ${k.nama}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("Kategori: ${kat?.namaKategori ?? 'Terhapus'}"),
                        Text("Gaji: Rp ${kat?.tarifPerJam ?? 0}/jam", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.fingerprint, color: Colors.green, size: 32),
                          tooltip: "Fingerprint ID:${k.id}",
                          onPressed: () => _prosesFingerprint(k, kat),
                        ),
                      ]),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}