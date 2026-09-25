import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dbases/localdatabase.dart';

class ExportPdfTBSlametJaya {
  static final _fmtRp = NumberFormat("#,###", "id_ID");
  static final _fmtTgl = DateFormat('dd MMM yyyy', 'id_ID');
  static final _fmtTglJam = DateFormat('dd MMM yyyy HH:mm', 'id_ID');

  static pw.Widget _header(String title, String sub) => pw.Column(
        cross: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("TB. SLAMET JAYA", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
          pw.Text("DUSUN JRANJANG RT 12/RW 6 KELURAHAN KERTOSUKO KECAMATAN KRUCIL KABUPATEN PROBOLINGGO (082229109246)", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(sub, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Divider(thickness: 2, color: PdfColors.orange800),
        ],
      );

  static Future<void> exportFullLogLiveAndAbsensi({
    required List<LaporanHarianData> allLaporan,
    required List<AbsensiData> allAbsensi,
    required Map<int, KaryawanData> karyawanMap,
    required DateTime periodeMulai,
    required DateTime periodeSelesai,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (c) => [
              _header("DATA KESELURUHAN - LOG LIVE & ABSENSI", "Periode: ${_fmtTgl.format(periodeMulai)} - ${_fmtTgl.format(periodeSelesai)} | ${allLaporan.length} hari & ${allAbsensi.length} absen"),
              pw.TableHelper.fromTextArray(
                headers: ["Tanggal", "Penjualan", "Ops", "Tambahan", "Gaji", "Kotor", "Bersih"],
                data: allLaporan
                    .map((l) => [
                          _fmtTgl.format(l.tanggal),
                          _fmtRp.format(l.totalPenjualan),
                          _fmtRp.format(l.bebanOperasional),
                          _fmtRp.format(l.tambahanLain),
                          _fmtRp.format(l.totalGajiHariIni),
                          _fmtRp.format(l.labaKotor),
                          _fmtRp.format(l.labaBersih)
                        ])
                    .toList(),
                headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
                cellStyle: const pw.TextStyle(fontSize: 7),
              ),
              pw.SizedBox(height: 16),
              pw.Text("LOG ABSENSI PER TANGGAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TableHelper.fromTextArray(
                headers: ["Tanggal Jam", "ID-Nama", "Tipe", "Metode"],
                data: allAbsensi.map((a) {
                  final kar = karyawanMap[a.karyawanId];
                  return [_fmtTglJam.format(a.jamMasuk), "${a.karyawanId}-${kar?.nama ?? ''}", a.tipeKerja, a.metode];
                }).toList(),
                headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
                cellStyle: const pw.TextStyle(fontSize: 7),
              ),
            ]));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Full_Log_${DateFormat('ddMMMyy_HHmm').format(DateTime.now())}.pdf');
  }

  static Future<void> exportSlipGajiMingguan({
    required KaryawanData karyawan,
    required KategoriKaryawanData kategori,
    required GajiMingguanData gaji,
    required List<AbsensiData> absensiMingguIni,
    double rataBintang = 0,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _header("SLIP GAJI MINGGUAN", "${_fmtTgl.format(gaji.mingguMulai)} - ${_fmtTgl.format(gaji.mingguSelesai)} | Bintang ${rataBintang.toStringAsFixed(1)} | ${karyawan.nama} (${kategori.namaKategori} Rp ${_fmtRp.format(kategori.tarifPerHari)}/hari)"),
              pw.SizedBox(height: 12),
              pw.Text("Rincian Absensi:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TableHelper.fromTextArray(
                headers: ["Tgl", "Tipe", "Jam"],
                data: absensiMingguIni.map((a) => [_fmtTgl.format(a.jamMasuk), a.tipeKerja, "${a.totalJamKerja} jam"]).toList(),
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 12),
              pw.Text("Total Hari Efektif: ${gaji.totalHariEfektif} | Pokok Rp ${_fmtRp.format(gaji.totalGajiPokok)} + Bonus Rp ${_fmtRp.format(gaji.bonusMingguan)} = TOTAL Rp ${_fmtRp.format(gaji.totalGaji)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
            ])));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Slip_${karyawan.nama}_${DateFormat('ddMMMyy').format(gaji.mingguMulai)}.pdf');
  }
}
