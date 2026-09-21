import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'database.dart';

class ExportPdfTBSlametJaya {
  static Future<void> exportSlipGajiMingguan({required KaryawanData karyawan, required KategoriKaryawanData kategori, required GajiMingguanData gaji, required List<AbsensiData> absensiMingguIni}) async {
    final pdf = pw.Document();
    final formatRp = NumberFormat.decimalPattern('id');
    pdf.addPage(pw.Page(build: (c) => pw.Column(children: [pw.Text("TB. SLAMET JAYA - SLIP GAJI"), pw.Text("${karyawan.nama} - Rp ${formatRp.format(gaji.totalGaji)}") ])));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }
  static Future<void> exportLaporanLaba({required Map<String,int> laba, required DateTime bulan, required List<TransaksiBisnisData> pendapatanList, required List<TransaksiBisnisData> bebanOpsList, required List<GajiMingguanData> gajiBulanIni}) async {
    final pdf = pw.Document();
    final formatRp = NumberFormat.decimalPattern('id');
    pdf.addPage(pw.Page(build: (c) => pw.Column(children: [pw.Text("LAPORAN LABA TB SLAMET JAYA"), pw.Text("Laba Bersih: Rp ${formatRp.format(laba['labaBersih'])}") ])));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }
}