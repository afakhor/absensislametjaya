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

  // 1. SLIP GAJI MINGGUAN - TETAP
  static Future<void> exportSlipGajiMingguan({
    required KaryawanData karyawan,
    required KategoriKaryawanData kategori,
    required GajiMingguanData gaji,
    required List<AbsensiData> absensiMingguIni,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header("SLIP GAJI MINGGUAN", "${_fmtTgl.format(gaji.mingguMulai)} - ${_fmtTgl.format(gaji.mingguSelesai)}"),
        pw.SizedBox(height: 8),
        pw.Text("ID: ${karyawan.id} - Nama: ${karyawan.nama}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text("Kategori: ${kategori.namaKategori} - Rp ${_fmtRp.format(kategori.tarifPerJam)}/jam"),
        pw.Text("Total Jam: ${gaji.totalJam} jam"),
        pw.Divider(),
        pw.Text("RINCIAN ABSENSI:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: ["Tgl", "Masuk", "Jam", "Metode"],
          data: absensiMingguIni.map((a) => [_fmtTgl.format(a.jamMasuk), DateFormat('HH:mm').format(a.jamMasuk), "${a.totalJamKerja} jam", a.metode]).toList(),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
          cellStyle: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 12),
        pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green200)), child: pw.Column(children: [
          _row("Total Jam Kerja", gaji.totalJam.toInt(), bold: true),
          _row("Tarif/Jam", kategori.tarifPerJam),
          pw.Divider(),
          _row("TOTAL GAJI", gaji.totalGaji, bold: true, color: PdfColors.green800),
        ])),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Slip_${karyawan.nama}_${DateFormat('ddMMMyy').format(gaji.mingguMulai)}.pdf');
  }

  // 2. LAPORAN LABA LAMA - TETAP SUPPORT + FIX BIAR GAK ERROR KEY TIDAK ADA
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
        _row("Beban Gaji Karyawan", laba['bebanGaji'] ?? 0, color: PdfColors.red800),
        _row("Beban Operasional", laba['bebanOps'] ?? laba['bebanOperasional'] ?? 0, color: PdfColors.red800),
        _row("Beban Lain", laba['bebanLain'] ?? 0, color: PdfColors.red800),
        pw.Divider(),
        _row("Total Pemasukan", laba['totalPemasukan'] ?? (laba['pendapatan'] ?? 0), bold: true),
        _row("Total Beban", laba['totalBeban'] ?? ((laba['bebanGaji'] ?? 0) + (laba['bebanOps'] ?? 0)), bold: true, color: PdfColors.red800),
        pw.Divider(thickness: 1.5),
        _row("Laba Kotor", laba['labaKotor'] ?? 0, bold: true, color: PdfColors.green700),
        _row("LABA BERSIH", laba['labaBersih'] ?? 0, bold: true, color: PdfColors.green800),
        pw.SizedBox(height: 12),
        pw.Text("Rincian Gaji: ${gajiBulanIni.length} transaksi gaji, Total Rp ${_fmtRp.format(laba['bebanGaji'] ?? 0)}", style: const pw.TextStyle(fontSize: 9)),
      ])
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Laba_${DateFormat('MMM_yyyy').format(bulan)}.pdf');
  }

  // 3. BARU - EXPORT SIMULASI LABA PERIODE (YANG DIPAKAI LABA_PAGE KALKULATOR)
  static Future<void> exportSimulasiLabaPeriode({
    required SimulasiLabaData simulasi,
  }) async {
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
            ["Beban Gaji Karyawan (auto sesuai tgl)", "Rp ${_fmtRp.format(simulasi.bebanGaji)}"],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: PdfColors.orange50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)), border: pw.Border.all(color: PdfColors.orange200)),
          child: pw.Column(children: [
            _row("Total Pemasukan (Omset + Lain)", simulasi.totalPemasukan, bold: true),
            _row("Total Beban (Ops + Lain + Gaji)", simulasi.totalBeban, bold: true, color: PdfColors.red800),
            pw.Divider(),
            _row("Laba Kotor (Omset - Ops)", simulasi.labaKotor, bold: true, color: PdfColors.green700),
            pw.Divider(thickness: 1),
            _row("LABA BERSIH (Total Masuk - Total Beban)", simulasi.labaBersih, bold: true, color: simulasi.labaBersih >= 0 ? PdfColors.green800 : PdfColors.red800),
          ])
        ),
        pw.Spacer(),
        pw.Text("Dicetak oleh TB. SLAMET JAYA - Sistem Kalkulator Laba", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ])
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Simulasi_Laba_${DateFormat('ddMMMyy').format(simulasi.periodeMulai)}-${DateFormat('ddMMMyy').format(simulasi.periodeSelesai)}.pdf');
  }
}