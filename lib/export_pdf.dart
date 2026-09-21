import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'database.dart';

class ExportPdfTBSlametJaya {
  static Future<void> exportSlipGajiMingguan({
    required KaryawanData karyawan,
    required KategoriKaryawanData kategori,
    required GajiMingguanData gaji,
    required List<AbsensiData> absensiMingguIni,
  }) async {
    final pdf = pw.Document();
    final formatRp = NumberFormat.decimalPattern('id');
    final formatTgl = DateFormat('dd MMM yyyy', 'id_ID');
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (c) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("TB. SLAMET JAYA", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
          pw.Text("SLIP GAJI MINGGUAN ${formatTgl.format(gaji.mingguMulai)} - ${formatTgl.format(gaji.mingguSelesai)}"),
          pw.Divider(),
          pw.Text("Nama: ${karyawan.nama}"),
          pw.Text("Kategori: ${kategori.namaKategori} - Rp ${formatRp.format(kategori.tarifPerJam)}/jam"),
          pw.Text("Total Jam: ${gaji.totalJam} jam"),
          pw.SizedBox(height: 10),
          pw.Text("TOTAL GAJI: Rp ${formatRp.format(gaji.totalGaji)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Slip_${karyawan.nama}.pdf');
  }

  static Future<void> exportLaporanLaba({
    required Map<String, int> laba,
    required DateTime bulan,
    required List<TransaksiData> pendapatanList,
    required List<TransaksiData> bebanOpsList,
    required List<GajiMingguanData> gajiBulanIni,
  }) async {
    final pdf = pw.Document();
    final formatRp = NumberFormat.decimalPattern('id');
    final formatBulan = DateFormat('MMMM yyyy', 'id_ID');
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (c) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("TB. SLAMET JAYA - LAPORAN LABA", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
          pw.Text(formatBulan.format(bulan).toUpperCase()),
          pw.Divider(),
          pw.Text("Pendapatan: Rp ${formatRp.format(laba['pendapatan'])}"),
          pw.Text("Beban Gaji (Auto Absensi): Rp ${formatRp.format(laba['bebanGaji'])}"),
          pw.Text("Beban Ops: Rp ${formatRp.format(laba['bebanOps'])}"),
          pw.Divider(),
          pw.Text("LABA KOTOR: Rp ${formatRp.format(laba['labaKotor'])}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.Text("LABA BERSIH: Rp ${formatRp.format(laba['labaBersih'])}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Laba_${DateFormat('MMM_yyyy').format(bulan)}.pdf');
  }
}