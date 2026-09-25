import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../dbases/localdatabase.dart';
import '../dbases/absen_db.dart';

class AbsenPage extends StatefulWidget {
  const AbsenPage({super.key});

  @override
  State<AbsenPage> createState() => _AbsenPageState();
}

class _AbsenPageState extends State<AbsenPage> {
  final db = AppDatabase();
  DateTime _selectedDate = DateTime.now();

  // Helper Render Avatar Foto
  Widget _buildAvatar(String? fotoPath) {
    if (fotoPath != null && fotoPath.trim().isNotEmpty) {
      final file = File(fotoPath);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: 20,
          backgroundImage: FileImage(file),
        );
      }
    }
    return const CircleAvatar(
      radius: 20,
      backgroundColor: Colors.brown,
      child: Icon(Icons.person, color: Colors.white, size: 20),
    );
  }

  // Pick Date (Kalender)
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.brown.shade800,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Modal Sheet Absen Manual oleh Owner
  void _showAbsenManualModal(BuildContext context) {
    KaryawanData? selectedKaryawan;
    String tipeKerja = 'FULL'; // Default Full 1 Hari
    final keteranganController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Absen Manual (${DateFormat('dd/MM/yyyy').format(_selectedDate)})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Autocomplete Search Karyawan
                  StreamBuilder<List<KaryawanData>>(
                    stream: db.select(db.karyawan).watch(),
                    builder: (context, snapKaryawan) {
                      final listKaryawan = snapKaryawan.data ?? [];

                      return StreamBuilder<List<KategoriKaryawanData>>(
                        stream: db.select(db.kategoriKaryawan).watch(),
                        builder: (context, snapKategori) {
                          final listKategori = snapKategori.data ?? [];

                          return Autocomplete<KaryawanData>(
                            displayStringForOption: (KaryawanData k) {
                              final kat = listKategori.firstWhere(
                                (element) => element.id == k.kategoriId,
                                orElse: () => const KategoriKaryawanData(id: 0, namaKategori: '-', tarifPerHari: 0),
                              );
                              return "${k.id} - ${k.nama} (${kat.namaKategori} - Rp ${kat.tarifPerHari})";
                            },
                            optionsBuilder: (TextEditingValue textVal) {
                              if (textVal.text.isEmpty) {
                                return listKaryawan;
                              }
                              return listKaryawan.where((KaryawanData k) {
                                final kat = listKategori.firstWhere(
                                  (element) => element.id == k.kategoriId,
                                  orElse: () => const KategoriKaryawanData(id: 0, namaKategori: '', tarifPerHari: 0),
                                );
                                final searchStr = "${k.id} ${k.nama} ${kat.namaKategori}".toLowerCase();
                                return searchStr.contains(textVal.text.toLowerCase());
                              });
                            },
                            onSelected: (KaryawanData selection) {
                              setModalState(() {
                                selectedKaryawan = selection;
                              });
                            },
                            fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: textController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Cari Karyawan (ID / Nama / Kategori)',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: textController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            textController.clear();
                                            setModalState(() {
                                              selectedKaryawan = null;
                                            });
                                          },
                                        )
                                      : const Icon(Icons.search),
                                ),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: MediaQuery.of(context).size.width - 32,
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final k = options.elementAt(index);
                                        final kat = listKategori.firstWhere(
                                          (element) => element.id == k.kategoriId,
                                          orElse: () => const KategoriKaryawanData(id: 0, namaKategori: '-', tarifPerHari: 0),
                                        );

                                        return ListTile(
                                          leading: _buildAvatar(k.fotoPath),
                                          title: Text("ID: ${k.id} - ${k.nama}"),
                                          subtitle: Text("${kat.namaKategori} • Rp ${kat.tarifPerHari}/hari"),
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

                  // Dropdown Tipe Kerja
                  DropdownButtonFormField<String>(
                    value: tipeKerja,
                    decoration: const InputDecoration(
                      labelText: 'Durasi Kerja',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'FULL', child: Text('Full 1 Hari (8 Jam)')),
                      DropdownMenuItem(value: 'HALF', child: Text('½ Hari (4 Jam)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          tipeKerja = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Input Keterangan / Alasan
                  TextField(
                    controller: keteranganController,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan / Alasan (Opsional)',
                      hintText: 'Misal: Izin, Terlambat, dll.',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade800,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (selectedKaryawan == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pilih karyawan terlebih dahulu!')),
                          );
                          return;
                        }

                        // Cek apakah sudah absen pada tanggal terpilih
                        final sudahAbsen = await db.sudahAbsenHariIni(selectedKaryawan!.id, _selectedDate);
                        if (sudahAbsen) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Karyawan sudah absen pada tanggal ini!')),
                            );
                          }
                          return;
                        }

                        final jamMasukTarget = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          DateTime.now().hour,
                          DateTime.now().minute,
                        );

                        final jamKerja = (tipeKerja == 'FULL') ? 8.0 : 4.0;
                        final alasan = keteranganController.text.trim();

                        await db.into(db.absensi).insert(
                              AbsensiCompanion.insert(
                                karyawanId: selectedKaryawan!.id,
                                jamMasuk: jamMasukTarget,
                                totalJamKerja: drift.Value(jamKerja),
                                metode: 'MANUAL',
                                keterangan: drift.Value(alasan.isEmpty ? 'Absen Manual Owner' : alasan),
                                tipeKerja: drift.Value(tipeKerja),
                              ),
                            );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Absen manual berhasil disimpan untuk ${selectedKaryawan!.nama}')),
                          );
                        }
                      },
                      child: const Text('Lanjut (Simpan)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate;
    try {
      formattedDate = DateFormat('EEEE, dd/MM/yyyy', 'id_ID').format(_selectedDate);
    } catch (_) {
      formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        title: Text(
          "Absen: $formattedDate",
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Pilih Tanggal',
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Absen Manual Owner',
            onPressed: () => _showAbsenManualModal(context),
          ),
        ],
      ),
      body: StreamBuilder<List<KaryawanData>>(
        stream: db.select(db.karyawan).watch(),
        builder: (c, snap) {
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(
              child: Text("Belum ada data karyawan.\nSilakan tambahkan via menu Owner.", textAlign: TextAlign.center),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final kar = list[i];
              return Card(
                child: ListTile(
                  leading: _buildAvatar(kar.fotoPath),
                  title: Text(kar.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("ID Karyawan: ${kar.id}"),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.fingerprint),
                    label: const Text("Absen"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      try {
                        // Memasukkan tanggal terpilih (_selectedDate) ke fungsi absenFingerprint
                        await db.absenFingerprint(kar.id, tanggal: _selectedDate);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Absen berhasil untuk ${kar.nama}")),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Sudah absen pada tanggal ini!")),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
