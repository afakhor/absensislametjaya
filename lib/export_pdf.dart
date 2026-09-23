import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dbases/localdatabase.dart';

class ExportPdfTBSlametJaya {
  static final _fmtRp = NumberFormat.decimalPattern('id');
  static final _fmtTgl = DateFormat('dd MMM yyyy', 'id_ID');
  static final _fmtTglJam = DateFormat('dd MMM yyyy HH:mm', 'id_ID');
  static final _fmtBulan = DateFormat('MMMM yyyy', 'id_ID');

  static pw.Widget _header(String title, String sub) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text("TB. SLAMET JAYA", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
      pw.Text("Jl. Raya Toko Bangunan - Telp: 08xx-xxxx-xxxx", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 8),
      pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.Text(sub, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      pw.Divider(thickness: 2, color: PdfColors.orange800),
    ]
  );

  static pw.Widget _row(String label, int value, {bool bold = false, PdfColor? color}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      pw.Text("Rp ${_fmtRp.format(value)}", style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.black)),
    ])
  );

  // 1. SLIP GAJI MINGGUAN - FIX GAJI/HARI + BONUS MINGGUAN + STATUS MERAH/KUNING/HIJAU
  static Future<void> exportSlipGajiMingguan({
    required KaryawanData karyawan,
    required KategoriKaryawanData kategori,
    required GajiMingguanData gaji,
    required List<AbsensiData> absensiMingguIni,
  }) async {
    final pdf = pw.Document();
    String statusLabel = gaji.statusBayar == 'BELUM' ? 'BELUM TERIMA (MERAH)' : gaji.statusBayar == 'MINGGU1' ? 'AKUMULASI 1 MINGGU (KUNING)' : 'AKUMULASI 2 MINGGU / LUNAS (HIJAU)';
    PdfColor statusColor = gaji.statusBayar == 'BELUM' ? PdfColors.red800 : gaji.statusBayar == 'MINGGU1' ? PdfColors.orange800 : PdfColors.green800;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header("SLIP GAJI MINGGUAN - GAJI/HARI", "${_fmtTgl.format(gaji.mingguMulai)} - ${_fmtTgl.format(gaji.mingguSelesai)}"),
        pw.SizedBox(height: 8),
        pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("ID: ${karyawan.id} - Nama: ${karyawan.nama}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text("Kategori: ${kategori.namaKategori} - Rp ${_fmtRp.format(kategori.tarifPerHari)}/hari"),
          pw.Text("Status Bayar: $statusLabel", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: statusColor)),
          pw.Text("Tgl Bayar: ${gaji.tanggalBayar != null ? _fmtTglJam.format(gaji.tanggalBayar!) : '-'}", style: const pw.TextStyle(fontSize: 9)),
        ])),
        pw.SizedBox(height: 8),
        pw.Text("RINCIAN ABSENSI HARIAN (FULL=1 hari, SETENGAH=0.5 hari):", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: ["Tgl", "Tipe", "Hari Efektif", "Metode", "Ket"],
          data: absensiMingguIni.map((a) => [
            _fmtTgl.format(a.jamMasuk), 
            a.tipeKerja, 
            a.tipeKerja == 'FULL' ? '1' : '0.5',
            a.metode, 
            a.keterangan
          ]).toList(),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
          cellStyle: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 12),
        pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green200)), child: pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("Total Hari Masuk: ${gaji.totalHariMasuk}x", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Hari Efektif: ${gaji.totalHariEfektif} hari", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 4),
          _row("Gaji Pokok (${gaji.totalHariEfektif} x Rp ${_fmtRp.format(kategori.tarifPerHari)})", gaji.totalGajiPokok, bold: true),
          _row("Bonus Mingguan (Owner Input di Halaman Gaji)", gaji.bonusMingguan, bold: false, color: PdfColors.blue800),
          pw.Divider(),
          _row("TOTAL GAJI DITERIMA", gaji.totalGaji, bold: true, color: PdfColors.green800),
        ])),
        pw.Spacer(),
        pw.Text("Catatan: Merah=Belum terima, Kuning=Akumulasi 1 minggu, Hijau=Akumulasi 2 minggu/lunas", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Slip_${karyawan.nama}_${DateFormat('ddMMMyy').format(gaji.mingguMulai)}.pdf');
  }

  // 2. LAPORAN LABA BULANAN - TETAP SUPPORT
  static Future<void> exportLaporanLaba({
    required Map<String, int> laba,
    required DateTime bulan,
    required List<TransaksiData> pendapatanList,
    required List<TransaksiData> bebanOpsList,
    required List<GajiMingguanData> gajiBulanIni,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header("LAPORAN LABA BULANAN", _fmtBulan.format(bulan).toUpperCase()),
        _row("Pendapatan (Omset)", laba['pendapatan'] ?? laba['omset'] ?? 0),
        _row("Pemasukan Lain", laba['pemasukanLain'] ?? 0),
        _row("Beban Gaji Karyawan (Akumulasi Gaji/Hari)", laba['bebanGaji'] ?? 0, color: PdfColors.red800),
        _row("Beban Operasional", laba['bebanOps'] ?? laba['bebanOperasional'] ?? 0, color: PdfColors.red800),
        _row("Beban Lain", laba['bebanLain'] ?? 0, color: PdfColors.red800),
        pw.Divider(),
        _row("Total Pemasukan", laba['totalPemasukan'] ?? (laba['pendapatan'] ?? 0), bold: true),
        _row("Total Beban", laba['totalBeban'] ?? ((laba['bebanGaji'] ?? 0) + (laba['bebanOps'] ?? 0)), bold: true, color: PdfColors.red800),
        pw.Divider(thickness: 1.5),
        _row("Laba Kotor", laba['labaKotor'] ?? 0, bold: true, color: PdfColors.green700),
        _row("LABA BERSIH", laba['labaBersih'] ?? 0, bold: true, color: PdfColors.green800),
        pw.SizedBox(height: 12),
        pw.Text("Rincian Gaji/Hari: ${gajiBulanIni.length} transaksi gaji, Total Rp ${_fmtRp.format(laba['bebanGaji'] ?? 0)}", style: const pw.TextStyle(fontSize: 9)),
        pw.Text("Include: ${gajiBulanIni.fold(0.0, (p,e)=>p+e.totalHariEfektif)} hari efektif kerja", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ])
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Laba_${DateFormat('MMM_yyyy').format(bulan)}.pdf');
  }

  // 3. EXPORT SIMULASI LABA PERIODE
  static Future<void> exportSimulasiLabaPeriode({required SimulasiLabaData simulasi}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header("SIMULASI LABA PERIODE", "Periode: ${_fmtTgl.format(simulasi.periodeMulai)} - ${_fmtTgl.format(simulasi.periodeSelesai)}"),
        pw.SizedBox(height: 4),
        pw.Text("Tanggal Simulasi: ${_fmtTglJam.format(simulasi.tanggalSimulasi)}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        if (simulasi.catatan != null && simulasi.catatan!.isNotEmpty) pw.Text("Catatan: ${simulasi.catatan}", style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ["Komponen", "Nominal"],
          data: [
            ["Omset (input manual)", "Rp ${_fmtRp.format(simulasi.omset)}"],
            ["Pemasukan Lain-Lain", "Rp ${_fmtRp.format(simulasi.pemasukanLain)}"],
            ["", ""],
            ["Beban Operasional", "Rp ${_fmtRp.format(simulasi.bebanOperasional)}"],
            ["Beban Lain", "Rp ${_fmtRp.format(simulasi.bebanLain)}"],
            ["Beban Gaji Karyawan (Gaji/Hari + Bonus Mingguan)", "Rp ${_fmtRp.format(simulasi.bebanGaji)}"],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 12),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: pw.BoxDecoration(color: PdfColors.orange50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)), border: pw.Border.all(color: PdfColors.orange200)), child: pw.Column(children: [
          _row("Total Pemasukan (Omset + Lain)", simulasi.totalPemasukan, bold: true),
          _row("Total Beban (Ops + Lain + Gaji/Hari)", simulasi.totalBeban, bold: true, color: PdfColors.red800),
          pw.Divider(),
          _row("Laba Kotor (Omset - Ops)", simulasi.labaKotor, bold: true, color: PdfColors.green700),
          pw.Divider(thickness: 1),
          _row("LABA BERSIH (Total Masuk - Total Beban)", simulasi.labaBersih, bold: true, color: simulasi.labaBersih >= 0 ? PdfColors.green800 : PdfColors.red800),
        ])),
        pw.Spacer(),
        pw.Text("Dicetak oleh TB. SLAMET JAYA - Sistem Gaji/Hari", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ])
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Simulasi_Laba_${DateFormat('ddMMMyy').format(simulasi.periodeMulai)}-${DateFormat('ddMMMyy').format(simulasi.periodeSelesai)}.pdf');
  }

  // 4. BARU - EXPORT LOG AKUMULASI BEBAN GAJI CONTINUE
  static Future<void> exportLogBebanGajiContinue({
    required int totalAkumulasi,
    required String filterInfo,
    required List<GajiMingguanData> listGaji,
    required Map<int, KaryawanData> karyawanMap,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header("LOG AKUMULASI BEBAN GAJI - DARI AWAL SAMPAI CONTINUE", filterInfo),
        pw.SizedBox(height: 8),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: pw.BoxDecoration(color: PdfColors.brown50, border: pw.Border.all(color: PdfColors.brown200)), child: pw.Column(children: [
          _row("TOTAL AKUMULASI BEBAN GAJI CONTINUE", totalAkumulasi, bold: true, color: PdfColors.brown800),
          pw.Text("Jumlah Transaksi: ${listGaji.length} | Total Hari Efektif: ${listGaji.fold(0.0, (p,e)=>p+e.totalHariEfektif)} hari", style: const pw.TextStyle(fontSize: 9)),
        ])),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ["Tgl", "ID-Karyawan", "Hari", "Pokok", "Bonus Mingguan", "Total", "Status"],
          data: listGaji.map((g){
            final kar = karyawanMap[g.karyawanId];
            return [
              _fmtTgl.format(g.mingguMulai),
              "${g.karyawanId}-${kar?.nama??''}",
              "${g.totalHariEfektif}",
              "Rp ${_fmtRp.format(g.totalGajiPokok)}",
              "Rp ${_fmtRp.format(g.bonusMingguan)}",
              "Rp ${_fmtRp.format(g.totalGaji)}",
              g.statusBayar,
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.brown800),
          cellStyle: const pw.TextStyle(fontSize: 7),
        ),
      ])
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Log_Beban_Gaji_Continue_${DateFormat('ddMMMyy_HHmm').format(DateTime.now())}.pdf');
  }
}