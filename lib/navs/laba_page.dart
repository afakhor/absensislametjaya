import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../dbases/localdatabase.dart';
import '../export_pdf.dart';

class LabaPage extends StatefulWidget { const LabaPage({super.key}); @override State<LabaPage> createState() => _LabaPageState(); }

class _LabaPageState extends State<LabaPage> {
  final db = AppDatabase();
  final fmt = NumberFormat("#,###","id_ID");
  int? filterKaryawanId; int? filterKategoriId;
  String filterAkumulasi = 'Akumulasi Awal - Continue';
  DateTime? periodeMulai; DateTime? periodeSelesai;
  List<KaryawanData> allKaryawan = [];
  List<KategoriKaryawanData> allKategori = [];
  int totalOmset = 0; int totalBebanOps = 0; int totalTambahan = 0; int totalBebanGaji = 0; int totalPemasukan = 0; int totalBeban = 0; int labaKotor = 0; int labaBersih = 0; int totalAkumGaji = 0;

  @override void initState(){ super.initState(); _init(); }
  Future<void> _init() async {
    allKaryawan = await db.select(db.karyawan).get();
    allKategori = await db.select(db.kategoriKaryawan).get();
    final allAbs = await db.select(db.absensi).get();
    allAbs.sort((a,b)=> a.jamMasuk.compareTo(b.jamMasuk));
    final firstAbsen = allAbs.isNotEmpty? allAbs.first : null;
    periodeMulai = firstAbsen?.jamMasuk ?? DateTime.now().subtract(const Duration(days:30));
    periodeSelesai = DateTime.now();
    await _hitungAuto();
    setState((){});
  }

  Future<void> _pilihPeriode() async {
    final pilih = await showModalBottomSheet<String>(context: context, builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: const Text('Akumulasi Awal - Continue'), onTap: ()=> Navigator.pop(context, 'Akumulasi Awal - Continue')),
      ListTile(title: const Text('Per Minggu'), onTap: ()=> Navigator.pop(context, 'Per Minggu')),
      ListTile(title: const Text('Per 2 Minggu'), onTap: ()=> Navigator.pop(context, 'Per 2 Minggu')),
      ListTile(title: const Text('Per Bulan'), onTap: ()=> Navigator.pop(context, 'Per Bulan')),
      ListTile(title: const Text('Per Range Tanggal'), onTap: ()=> Navigator.pop(context, 'Per Range Tanggal')),
      ListTile(title: const Text('Tgl Tertentu Sampai Continue'), onTap: ()=> Navigator.pop(context, 'Tgl Tertentu Sampai Continue')),
    ]));
    if(pilih==null) return;

    if(pilih=='Akumulasi Awal - Continue'){
      final all = await db.select(db.absensi).get(); all.sort((a,b)=> a.jamMasuk.compareTo(b.jamMasuk));
      final first = all.isNotEmpty? all.first : null;
      periodeMulai = first?.jamMasuk ?? DateTime.now().subtract(const Duration(days:30));
      periodeSelesai = DateTime.now();
    } else if(pilih=='Per Minggu'){
      final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
      if(picked==null) return;
      final minggu = await showDialog<int>(context: context, builder: (_)=> SimpleDialog(title: const Text('Pilih Minggu ke'), children: List.generate(4, (i)=> SimpleDialogOption(child: Text('Minggu ${i+1}'), onPressed: ()=> Navigator.pop(context, i+1)))));
      if(minggu==null) return;
      final start = DateTime(picked.year, picked.month, (minggu-1)*7 + 1);
      final end = DateTime(picked.year, picked.month, minggu*7).isAfter(DateTime(picked.year, picked.month+1,0))? DateTime(picked.year, picked.month+1,0) : DateTime(picked.year, picked.month, minggu*7);
      periodeMulai = start; periodeSelesai = end;
    } else if(pilih=='Per 2 Minggu'){
      final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
      if(picked==null) return;
      final sesi = await showDialog<int>(context: context, builder: (_)=> SimpleDialog(title: const Text('Pilih'), children: [SimpleDialogOption(child: const Text('Minggu 1-2 (Tgl 1-15)'), onPressed: ()=> Navigator.pop(context, 1)), SimpleDialogOption(child: const Text('Minggu 3-4 (Tgl 16-Akhir)'), onPressed: ()=> Navigator.pop(context, 2))]));
      if(sesi==null) return;
      if(sesi==1){ periodeMulai = DateTime(picked.year, picked.month, 1); periodeSelesai = DateTime(picked.year, picked.month, 15); }
      else { periodeMulai = DateTime(picked.year, picked.month, 16); periodeSelesai = DateTime(picked.year, picked.month+1, 0); }
    } else if(pilih=='Per Bulan'){
      final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
      if(picked==null) return;
      periodeMulai = DateTime(picked.year, picked.month, 1); periodeSelesai = DateTime(picked.year, picked.month+1, 0);
    } else if(pilih=='Per Range Tanggal'){
      final range = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now());
      if(range==null) return; periodeMulai = range.start; periodeSelesai = range.end;
    } else if(pilih=='Tgl Tertentu Sampai Continue'){
      final tgl = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
      if(tgl==null) return; periodeMulai = tgl; periodeSelesai = DateTime.now();
    }
    setState(()=> filterAkumulasi = pilih); await _hitungAuto();
  }

  Future<void> _hitungAuto() async {
    if(periodeMulai==null || periodeSelesai==null) return;
    final start = DateTime(periodeMulai!.year, periodeMulai!.month, periodeMulai!.day);
    final end = DateTime(periodeSelesai!.year, periodeSelesai!.month, periodeSelesai!.day, 23,59,59);
    final allLaporan = await db.select(db.laporanHarian).get();
    var lapFilter = allLaporan.where((l)=> l.tanggal.isAfter(start.subtract(const Duration(seconds:1))) && l.tanggal.isBefore(end.add(const Duration(seconds:1)))).toList();
    var allGaji = await db.select(db.gajiMingguan).get();
    if(filterKaryawanId!=null) allGaji = allGaji.where((g)=> g.karyawanId==filterKaryawanId).toList();
    if(filterKategoriId!=null){
      final ids = allKaryawan.where((k)=> k.kategoriId==filterKategoriId).map((k)=>k.id).toSet();
      allGaji = allGaji.where((g)=> ids.contains(g.karyawanId)).toList();
    }
    allGaji = allGaji.where((g)=> g.mingguMulai.isAfter(start.subtract(const Duration(seconds:1))) && g.mingguMulai.isBefore(end.add(const Duration(seconds:1)))).toList();
    int omset = 0, bebanOps=0, tambahan=0, gajiHarian=0;
    for(var l in lapFilter){ omset += l.totalPenjualan; bebanOps += l.bebanOperasional; tambahan += l.tambahanLain; gajiHarian += l.totalGajiHariIni; }
    int bebanGaji = gajiHarian>0? gajiHarian : allGaji.fold<int>(0, (p,e)=> p+e.totalGaji);
    final pemasukan = omset + tambahan; final beban = bebanOps + bebanGaji; final kotor = omset - bebanOps; final bersih = pemasukan - beban;
    if(mounted) setState((){
      totalOmset = omset; totalBebanOps = bebanOps; totalTambahan = tambahan; totalBebanGaji = bebanGaji;
      totalPemasukan = pemasukan; totalBeban = beban; labaKotor = kotor; labaBersih = bersih; totalAkumGaji = bebanGaji;
    });
  }

  Future<void> _cetakPdf() async {
    final allLaporan = await db.select(db.laporanHarian).get()..sort((a,b)=> a.tanggal.compareTo(b.tanggal));
    final allAbsen = await db.select(db.absensi).get()..sort((a,b)=> a.jamMasuk.compareTo(b.jamMasuk));
    final filteredLaporan = allLaporan.where((l)=> l.tanggal.isAfter(periodeMulai!.subtract(const Duration(days:1))) && l.tanggal.isBefore(periodeSelesai!.add(const Duration(days:1)))).toList();
    final filteredAbsen = allAbsen.where((a)=> a.jamMasuk.isAfter(periodeMulai!.subtract(const Duration(days:1))) && a.jamMasuk.isBefore(periodeSelesai!.add(const Duration(days:1)))).toList();
    final karMap = {for(var k in allKaryawan) k.id: k};
    await ExportPdfTBSlametJaya.exportFullLogLiveAndAbsensi(allLaporan: filteredLaporan, allAbsensi: filteredAbsen, karyawanMap: karMap, periodeMulai: periodeMulai!, periodeSelesai: periodeSelesai!);
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('Laba & Beban Gaji Continue'), backgroundColor: Colors.brown.shade800, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.print), onPressed: _cetakPdf)]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
        Card(elevation:3, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          DropdownButtonFormField<int?>(value: filterKaryawanId, decoration: const InputDecoration(labelText: 'Semua Karyawan'), items: [const DropdownMenuItem<int?>(value: null, child: Text('Semua Karyawan')), ...allKaryawan.map((k)=> DropdownMenuItem(value: k.id, child: Text('ID:${k.id}-${k.nama}')))], onChanged: (v){ setState(()=> filterKaryawanId=v); _hitungAuto(); }),
          const SizedBox(height:8),
          DropdownButtonFormField<int?>(value: filterKategoriId, decoration: const InputDecoration(labelText: 'Semua Kategori'), items: [const DropdownMenuItem<int?>(value: null, child: Text('Semua Kategori')), ...allKategori.map((k)=> DropdownMenuItem(value: k.id, child: Text(k.namaKategori)))], onChanged: (v){ setState(()=> filterKategoriId=v); _hitungAuto(); }),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(value: filterAkumulasi, decoration: const InputDecoration(labelText: 'Periode Akumulasi'), items: const [DropdownMenuItem(value: 'Akumulasi Awal - Continue', child: Text('Akumulasi Awal - Continue')), DropdownMenuItem(value: 'Per Minggu', child: Text('Per Minggu')), DropdownMenuItem(value: 'Per 2 Minggu', child: Text('Per 2 Minggu')), DropdownMenuItem(value: 'Per Bulan', child: Text('Per Bulan')), DropdownMenuItem(value: 'Per Range Tanggal', child: Text('Per Range Tanggal')), DropdownMenuItem(value: 'Tgl Tertentu Sampai Continue', child: Text('Tgl Tertentu Sampai Continue'))], onChanged: (v){ if(v!=null) _pilihPeriode(); }),
        ]))),
        Container(width: double.infinity, margin: const EdgeInsets.symmetric(vertical:12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.brown.shade50, borderRadius: BorderRadius.circular(12)), child: Column(children: [
          const Text('TOTAL AKUMULASI BEBAN GAJI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          Text('Rp ${fmt.format(totalAkumGaji)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.brown.shade800)),
          Text('${DateFormat('dd MMM yy').format(periodeMulai??DateTime.now())} - ${DateFormat('dd MMM yy').format(periodeSelesai??DateTime.now())} | $filterAkumulasi', style: const TextStyle(fontSize:10)),
        ])),
        Card(child: ListTile(leading: const Icon(Icons.calendar_month), title: Text(filterAkumulasi), subtitle: Text(periodeMulai==null?'Belum pilih': '${DateFormat('dd MMM yyyy').format(periodeMulai!)} - ${DateFormat('dd MMM yyyy').format(periodeSelesai!)}'), onTap: _pilihPeriode, trailing: const Icon(Icons.edit))),
        const SizedBox(height:8),
        Card(color: Colors.grey.shade100, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          _rowAuto('Omset (auto dari Log Live)', totalOmset),
          _rowAuto('Beban Operasional (auto)', totalBebanOps),
          _rowAuto('Beban Gaji (auto dari Log/ Gaji)', totalBebanGaji),
          const Divider(),
          Container(padding: const EdgeInsets.all(12), color: Colors.yellow.shade50, child: Column(children: [
            _rowAuto('Total Pemasukan: Omset+Tambahan', totalPemasukan, bold: true),
            _rowAuto('Total Beban: Ops+Gaji', totalBeban, bold: true),
            _rowAuto('Laba Kotor: Omset - Ops', labaKotor, bold: true),
            _rowAuto('Laba Bersih: Masuk - Beban', labaBersih, bold: true, color: labaBersih>=0? Colors.green : Colors.red),
          ])),
        ]))),
        const SizedBox(height:12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text('CETAK PDF FULL LOG LIVE & ABSENSI'), style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)), onPressed: _cetakPdf)),
      ])),
    );
  }
  Widget _rowAuto(String label, int value, {bool bold=false, Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical:4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: 12, fontWeight: bold? FontWeight.bold : FontWeight.normal)), Text('Rp ${fmt.format(value)}', style: TextStyle(fontWeight: bold? FontWeight.bold : FontWeight.normal, color: color))]));
}