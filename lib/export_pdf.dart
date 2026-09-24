import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dbases/localdatabase.dart';

class ExportPdfTBSlametJaya {
  static final _fmtRp = NumberFormat("#,###", "id_ID");
  static final _fmtTgl = DateFormat('dd MMM yyyy', 'id_ID');
  static final _fmtTglJam = DateFormat('dd MMM yyyy HH:mm', 'id_ID');

  static pw.Widget _header(String title, String sub) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text("TB. SLAMET JAYA", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
    pw.Text("DUSUN JRANJANG RT 12/RW 6 KELURAHAN KERTOSUKO KECAMATAN KRUCIL KABUPATEN PROBOLINGGO (082229109246)", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    pw.SizedBox(height: 8), pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
    pw.Text(sub, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
    pw.Divider(thickness: 2, color: PdfColors.orange800),
  ]);

  static pw.Widget _row(String label, int value, {bool bold = false, PdfColor? color}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      pw.Text("Rp ${_fmtRp.format(value)}", style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.black)),
    ]));

  static Future<void> exportFullLogLiveAndAbsensi({required List<LaporanHarianData> allLaporan, required List<AbsensiData> allAbsensi, required Map<int, KaryawanData> karyawanMap, required DateTime periodeMulai, required DateTime periodeSelesai}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (c) => [
      _header("DATA KESELURUHAN - LOG LIVE & ABSENSI", "Periode: ${_fmtTgl.format(periodeMulai)} - ${_fmtTgl.format(periodeSelesai)} | ${allLaporan.length} hari & ${allAbsensi.length} absen"),
      pw.TableHelper.fromTextArray(headers: ["Tanggal","Penjualan","Ops","Tambahan","Gaji","Kotor","Bersih"], data: allLaporan.map((l)=> [ _fmtTgl.format(l.tanggal), _fmtRp.format(l.totalPenjualan), _fmtRp.format(l.bebanOperasional), _fmtRp.format(l.tambahanLain), _fmtRp.format(l.totalGajiHariIni), _fmtRp.format(l.labaKotor), _fmtRp.format(l.labaBersih)]).toList(), headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white), headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800), cellStyle: const pw.TextStyle(fontSize: 7)),
      pw.SizedBox(height: 16),
      pw.Text("LOG ABSENSI PER TANGGAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.TableHelper.fromTextArray(headers: ["Tanggal Jam","ID-Nama","Tipe","Metode"], data: allAbsensi.map((a){ final kar = karyawanMap[a.karyawanId]; return [ _fmtTglJam.format(a.jamMasuk), "${a.karyawanId}-${kar?.nama??''}", a.tipeKerja, a.metode]; }).toList(), headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white), headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800), cellStyle: const pw.TextStyle(fontSize: 7)),
    ]));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Full_Log_${DateFormat('ddMMMyy_HHmm').format(DateTime.now())}.pdf');
  }

  static Future<void> exportSlipGajiMingguan({required KaryawanData karyawan, required KategoriKaryawanData kategori, required GajiMingguanData gaji, required List<AbsensiData> absensiMingguIni, double rataBintang = 0}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _header("SLIP GAJI MINGGUAN", "${_fmtTgl.format(gaji.mingguMulai)} - ${_fmtTgl.format(gaji.mingguSelesai)} | Bintang ${rataBintang.toStringAsFixed(1)}"),
      _row("Gaji Pokok", gaji.totalGajiPokok, bold: true), _row("Bonus Mingguan", gaji.bonusMingguan, color: PdfColors.blue800), _row("TOTAL", gaji.totalGaji, bold: true, color: PdfColors.green800),
    ])));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }
}