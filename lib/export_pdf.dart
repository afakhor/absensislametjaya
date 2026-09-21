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
    final formatTgl = DateFormat('dd MMMM yyyy', 'id_ID');
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (c) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text("TB. SLAMET JAYA", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
            pw.Text("Toko Bangunan - Material Lengkap", style: pw.TextStyle(fontSize: 9)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text("SLIP GAJI MINGGUAN", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text("${formatTgl.format(gaji.mingguMulai)} - ${formatTgl.format(gaji.mingguSelesai)}", style: pw.TextStyle(fontSize: 10)),
          ]),
        ]),
        pw.Divider(thickness: 2), pw.SizedBox(height: 10),
        pw.Table.fromTextArray(headers: ['Nama', 'Kategori', 'Tarif/Jam'], data: [[karyawan.nama, kategori.namaKategori, "Rp ${formatRp.format(kategori.tarifPerJam)}"]], headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), headerDecoration: pw.BoxDecoration(color: PdfColors.orange800)),
        pw.SizedBox(height: 15), pw.Text("Rincian Absensi:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(headers: ['Tgl', 'Jam Masuk', 'Jam Kerja', 'Metode'], data: absensiMingguIni.map((a) => [DateFormat('dd/MM').format(a.jamMasuk), DateFormat('HH:mm').format(a.jamMasuk), "${a.totalJamKerja} jam", a.metode]).toList(), headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9), headerDecoration: pw.BoxDecoration(color: PdfColors.grey800), cellStyle: pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 15),
        pw.Container(padding: pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all()), child: pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Jam: ${gaji.totalJam} Jam"), pw.Text("Rp ${formatRp.format(kategori.tarifPerJam)}/jam")]),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("TOTAL GAJI BERSIH:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)), pw.Text("Rp ${formatRp.format(gaji.totalGaji)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green800))]),
        ])),
        pw.Spacer(), pw.Text("Dicetak otomatis dari Aplikasi Absensi TB. Slamet Jaya", style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Slip_${karyawan.nama}.pdf');
  }

  static Future<void> exportLaporanLaba({
    required Map<String, int> laba,
    required DateTime bulan,
    required List<TransaksiBisnisData> pendapatanList,
    required List<TransaksiBisnisData> bebanOpsList,
    required List<GajiMingguanData> gajiBulanIni,
  }) async {
    final pdf = pw.Document();
    final formatRp = NumberFormat.decimalPattern('id');
    final formatBulan = DateFormat('MMMM yyyy', 'id_ID');
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (c) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("TB. SLAMET JAYA - LAPORAN LABA BULANAN", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
        pw.Text(formatBulan.format(bulan).toUpperCase()), pw.Divider(thickness: 2),
        pw.Text("A. PENDAPATAN", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
        pw.Table.fromTextArray(headers: ['Tgl', 'Keterangan', 'Nominal'], data: pendapatanList.map((e) => [DateFormat('dd/MM').format(e.tanggal), e.keterangan, "Rp ${formatRp.format(e.nominal)}"]).toList()),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Total: Rp ${formatRp.format(laba['pendapatan'])}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 10),
        pw.Text("B. BEBAN GAJI (Auto Absensi)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
        pw.Table.fromTextArray(headers: ['ID Kar', 'Jam', 'Gaji'], data: gajiBulanIni.map((g) => ["ID ${g.karyawanId}", "${g.totalJam}", "Rp ${formatRp.format(g.totalGaji)}"]).toList()),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Total Beban Gaji: Rp ${formatRp.format(laba['bebanGaji'])}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red))),
        pw.SizedBox(height: 10),
        pw.Text("C. BEBAN OPERASIONAL"), pw.Table.fromTextArray(headers: ['Tgl', 'Keterangan', 'Nominal'], data: bebanOpsList.map((e) => [DateFormat('dd/MM').format(e.tanggal), e.keterangan, "Rp ${formatRp.format(e.nominal)}"]).toList()),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Total Ops: Rp ${formatRp.format(laba['bebanOps'])}")),
        pw.Divider(),
        pw.Container(padding: pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: PdfColors.grey200), child: pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("LABA KOTOR (A-B)"), pw.Text("Rp ${formatRp.format(laba['labaKotor'])}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800))]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("LABA BERSIH (A-B-C)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("Rp ${formatRp.format(laba['labaBersih'])}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green800))]),
        ])),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Laba_${DateFormat('MMM_yyyy').format(bulan)}.pdf');
  }
}