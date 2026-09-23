import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dbases/localdatabase.dart';

class ExportPdfTBSlametJaya {
  static final _fmtRp = NumberFormat("#,###", "id_ID");
  static final _fmtTgl = DateFormat('dd MMM yyyy', 'id_ID');
  static final _fmtTglJam = DateFormat('dd MMM yyyy HH:mm', 'id_ID');
  static final _fmtBulan = DateFormat('MMMM yyyy', 'id_ID');

  static pw.Widget _header(String title, String sub) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text("TB. SLAMET JAYA", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
      pw.Text("DUSUN JRANJANG RT 12/RW 6 KELURAHAN KERTOSUKO KECAMATAN KRUCIL KABUPATEN PROBOLINGGO (082229109246)", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
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

  // 1. SLIP GAJI MINGGUAN - GAJI/HARI + BONUS MINGGUAN + MERAH/KUNING/HIJAU + BINTANG
  static Future<void> exportSlipGajiMingguan({
    required KaryawanData karyawan,
    required KategoriKaryawanData kategori,
    required GajiMingguanData gaji,
    required List<AbsensiData> absensiMingguIni,
    double rataBintang = 0,
  }) async {
    final pdf = pw.Document();
    String statusLabel = gaji.statusBayar == 'BELUM' ? 'BELUM TERIMA (MERAH)' : gaji.statusBayar == 'MINGGU1' ? 'AKUMULASI 1 MINGGU (KUNING)' : 'AKUMULASI 2 MINGGU / LUNAS (HIJAU)';
    PdfColor statusColor = gaji.statusBayar == 'BELUM' ? PdfColors.red800 : gaji.statusBayar == 'MINGGU1' ? PdfColors.orange800 : PdfColors.green800;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header("SLIP GAJI MINGGUAN KARYAWAN TB. SLAMET JAYA", "${_fmtTgl.format(gaji.mingguMulai)} - ${_fmtTgl.format(gaji.mingguSelesai)}"),
        pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("ID: ${karyawan.id} - Nama: ${karyawan.nama}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text("Kategori: ${kategori.namaKategori} - Rp ${_fmtRp.format(kategori.tarifPerHari)}/hari | Rata Bintang: ${rataBintang.toStringAsFixed(1)} ⭐"),
          pw.Text("Status Bayar: $statusLabel", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: statusColor)),
          pw.Text("Tgl Bayar: ${gaji.tanggalBayar != null ? _fmtTglJam.format(gaji.tanggalBayar!) : '-'}", style: const pw.TextStyle(fontSize: 9)),
        ])),
        pw.SizedBox(height: 8),
        pw.Text("RINCIAN ABSENSI HARIAN (FULL=1 hari, SETENGAH=0.5 hari):", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: ["Tgl", "Tipe", "Efektif", "Metode", "Ket"],
          data: absensiMingguIni.map((a) => [_fmtTgl.format(a.jamMasuk), a.tipeKerja, a.tipeKerja == 'FULL' ? '1' : '0.5', a.metode, a.keterangan]).toList(),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
          cellStyle: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 12),
        pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green200)), child: pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("Total Masuk: ${gaji.totalHariMasuk}x", style: const pw.TextStyle(fontSize: 10)),
            pw.Text("Hari Efektif: ${gaji.totalHariEfektif} hari", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ]),
          _row("Gaji Pokok (${gaji.totalHariEfektif} x Rp ${_fmtRp.format(kategori.tarifPerHari)})", gaji.totalGajiPokok, bold: true),
          _row("Bonus Mingguan (Bintang ${rataBintang.toStringAsFixed(1)} auto 5/10/15%)", gaji.bonusMingguan, color: PdfColors.blue800),
          pw.Divider(),
          _row("TOTAL GAJI DITERIMA", gaji.totalGaji, bold: true, color: PdfColors.green800),
        ])),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Slip_${karyawan.nama}_${DateFormat('ddMMMyy').format(gaji.mingguMulai)}.pdf');
  }

  // 2. LAPORAN LABA AUTO - AMBIL DARI DASHBOARD LOG + ABSENSI (YANG BIRU)
  static Future<void> exportLabaAuto({
    required DateTime periodeMulai,
    required DateTime periodeSelesai,
    required String filterInfo,
    required int totalOmset,
    required int totalBebanOps,
    required int totalTambahan,
    required int totalBebanGaji,
    required int totalPemasukan,
    required int totalBeban,
    required int labaKotor,
    required int labaBersih,
    required List<LaporanHarianData> logLiveList,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (c) => [
        _header("LABA & BEBAN GAJI CONTINUE - AUTO DARI DASHBOARD", "$filterInfo | ${ _fmtTgl.format(periodeMulai)} - ${ _fmtTgl.format(periodeSelesai)}"),
        pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: PdfColors.orange50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))), child: pw.Column(children: [
          _row("TOTAL AKUMULASI GAJI KARYAWAN", totalBebanGaji, bold: true),
          _row("Omset TB. SLAMET", totalOmset),
          _row("Beban Operasional", totalBebanOps, color: PdfColors.red800),
          _row("Tambahan Lain", totalTambahan),
          pw.Divider(),
          _row("Total Pemasukan", totalPemasukan, bold: true),
          _row("Total Beban", totalBeban, bold: true, color: PdfColors.red800),
          pw.Divider(thickness: 1.5),
          _row("LABA KOTOR", labaKotor, bold: true, color: PdfColors.green700),
          _row("LABA BERSIH", labaBersih, bold: true, color: labaBersih>=0? PdfColors.green800 : PdfColors.red800),
        ])),
        pw.SizedBox(height: 12),
        pw.Text("RINCIAN TERSIMPAN", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.TableHelper.fromTextArray(
          headers: ["Tanggal","Penjualan","Beban Ops","Tambahan","Gaji","Kotor","Bersih","Ket"],
          data: logLiveList.map((l)=> [ _fmtTgl.format(l.tanggal), "Rp ${_fmtRp.format(l.totalPenjualan)}", "Rp ${_fmtRp.format(l.bebanOperasional)}", "Rp ${_fmtRp.format(l.tambahanLain)}", "Rp ${_fmtRp.format(l.totalGajiHariIni)}", "Rp ${_fmtRp.format(l.labaKotor)}", "Rp ${_fmtRp.format(l.labaBersih)}", l.keteranganTambahan]).toList(),
          headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
          cellStyle: const pw.TextStyle(fontSize: 6),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Laba_Auto_${DateFormat('ddMMMyy').format(periodeMulai)}-${DateFormat('ddMMMyy').format(periodeSelesai)}.pdf');
  }

  // 3. FULL LOG LIVE + ABSENSI - UNTUK TOMBOL CETAK PDF DI LABA
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
        _header("DATA KESELURUHAN", "Periode: ${_fmtTgl.format(periodeMulai)} - ${_fmtTgl.format(periodeSelesai)} | Total ${allLaporan.length} hari log & ${allAbsensi.length} absen"),
        pw.Text("AKUMULASI GAJI SAMPAI SAAT INI", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: ["Tanggal","Penjualan","Ops","Tambahan","Gaji","Kotor","Bersih"],
          data: allLaporan.map((l)=> [ _fmtTgl.format(l.tanggal), _fmtRp.format(l.totalPenjualan), _fmtRp.format(l.bebanOperasional), _fmtRp.format(l.tambahanLain), _fmtRp.format(l.totalGajiHariIni), _fmtRp.format(l.labaKotor), _fmtRp.format(l.labaBersih)]).toList(),
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
          cellStyle: const pw.TextStyle(fontSize: 7),
        ),
        pw.SizedBox(height: 16),
        pw.Text("LOG ABSENSI PER TANGGAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: ["Tanggal Jam","ID-Nama","Tipe","Jam","Metode","Keterangan"],
          data: allAbsensi.map((a){
            final kar = karyawanMap[a.karyawanId];
            return [ _fmtTglJam.format(a.jamMasuk), "${a.karyawanId}-${kar?.nama??''}", a.tipeKerja, "${a.totalJamKerja}", a.metode, a.keterangan];
          }).toList(),
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
          cellStyle: const pw.TextStyle(fontSize: 7),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Full_Log_Live_Absensi_${DateFormat('ddMMMyy_HHmm').format(DateTime.now())}.pdf');
  }

  // 4. LOG AKUMULASI BEBAN GAJI CONTINUE (yang biru)
  static Future<void> exportLogBebanGajiContinue({
    required int totalAkumulasi,
    required String filterInfo,
    required List<GajiMingguanData> listGaji,
    required Map<int, KaryawanData> karyawanMap,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (c) => [
        _header("AKUMULASI GAJI KARYAWAN SAMPAI SAAT INI", filterInfo),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: pw.BoxDecoration(color: PdfColors.grey200, border: pw.Border.all(color: PdfColors.grey400)), child: pw.Column(children: [
          _row("AKUMULASI GAJI KARYAWAN SAMPAI SAAT INI", totalAkumulasi, bold: true),
          pw.Text("Jumlah Transaksi: ${listGaji.length} | Total Hari Efektif: ${listGaji.fold(0.0, (p,e)=>p+e.totalHariEfektif)} hari", style: const pw.TextStyle(fontSize: 9)),
        ])),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ["Tgl", "ID-Karyawan", "Hari", "Pokok", "Bonus", "Total", "Status"],
          data: listGaji.map((g){
            final kar = karyawanMap[g.karyawanId];
            return [_fmtTgl.format(g.mingguMulai), "${g.karyawanId}-${kar?.nama??''}", "${g.totalHariEfektif}", "Rp ${_fmtRp.format(g.totalGajiPokok)}", "Rp ${_fmtRp.format(g.bonusMingguan)}", "Rp ${_fmtRp.format(g.totalGaji)}", g.statusBayar];
          }).toList(),
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
          cellStyle: const pw.TextStyle(fontSize: 7),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'Log_Beban_Gaji_Continue_${DateFormat('ddMMMyy_HHmm').format(DateTime.now())}.pdf');
  }
}