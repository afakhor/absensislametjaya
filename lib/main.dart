import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'navs/absen_page.dart';
import 'navs/gaji_page.dart';
import 'navs/dashboard_page.dart'; // INI SUDAH 3 IN 1: LIVE | LOG | ABSENSI
import 'navs/laba_page.dart';
import 'navs/setting_owner.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: MainMenu()));

class MainMenu extends StatefulWidget { const MainMenu({super.key}); @override State<MainMenu> createState() => _MainMenuState(); }

class _MainMenuState extends State<MainMenu> {
  int _idx = 0;

  final pages = [
    const AbsenPage(), // 0 - Absen harian FULL/½ hari gaji/hari tanpa bonus
    const GajiPage(), // 1 - Bonus mingguan di sini + Merah/Kuning/Hijau
    const DashboardPage(), // 2 - 1 HALAMAN 3 TAB: Live | Log (bisa tanggal tertentu & range) | Kalender Absensi (Merah/Kuning/Hijau, klik kuning lihat bolong & ½ hari)
    const LabaPage(), // 3 - Simulasi laba
    const SettingOwnerPage(), // 4 - Owner
  ];

  @override
  void initState() {
    super.initState();
    _requestAllPermissionsAwal();
  }

  Future<void> _requestAllPermissionsAwal() async {
    await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.location,
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.sensors,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TB. SLAMET JAYA", style: TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.brown.shade800, 
        foregroundColor: Colors.white,
      ),
      body: pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx, 
        onDestinationSelected: (i) => setState(() => _idx = i), 
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fingerprint), label: 'Absen'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'Gaji'),
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'), // LIVE + LOG + KALENDER
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Laba'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Owner'),
        ],
      ),
    );
  }
}