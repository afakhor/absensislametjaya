import 'package:flutter/material.dart';
import '../dbases/localdatabase.dart';
import '../dbases/absen_db.dart';

class AbsenPage extends StatefulWidget {
  const AbsenPage({super.key});
  @override
  State<AbsenPage> createState() => _AbsenPageState();
}

class _AbsenPageState extends State<AbsenPage> {
  final db = AppDatabase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<KaryawanData>>(
        stream: db.select(db.karyawan).watch(),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data ?? [];
          if (list.isEmpty) return const Center(child: Text("Belum ada data karyawan"));

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final kar = list[i];
              return ListTile(
                title: Text(kar.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("ID Karyawan: ${kar.id}"),
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.fingerprint),
                  label: const Text("Absen"),
                  onPressed: () async {
                    try {
                      await db.absenFingerprint(kar.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Absen berhasil untuk ${kar.nama}")));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sudah absen hari ini!")));
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
