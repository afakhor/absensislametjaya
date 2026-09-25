import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'navs/absen_page.dart';
import 'navs/gaji_page.dart';
import 'navs/dashboard_page.dart';
import 'navs/laba_page.dart';
import 'navs/setting_owner.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MainMenu(),
  ));
}

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _idx = 0;

  // Gunakan List<Widget> dengan mengacu pada OwnerPage
  final List<Widget> _pages = const [
    AbsenPage(),
    GajiPage(),
    DashboardPage(),
    LabaPage(),
    OwnerPage(), // Menggunakan nama kelas yang sesuai di settingowner.dart
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
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "TB. SLAMET JAYA",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _idx,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fingerprint), label: 'Absen'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'Gaji'),
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Laba'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Owner'),
        ],
      ),
    );
  }
}
