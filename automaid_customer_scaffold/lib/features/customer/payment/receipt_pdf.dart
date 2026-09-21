import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Admin-configurable company info (Settings > Company Information) shown
/// as a letterhead at the top of the receipt. All fields optional — the
/// PDF falls back to a plain "Automaid" heading if none are set yet.
class ReceiptLetterhead {
  final String? companyName;
  final String? companyAddress;
  final String? companyPhone;
  final String? companyEmail;
  final String? companyRegistrationNo;

  const ReceiptLetterhead({
    this.companyName,
    this.companyAddress,
    this.companyPhone,
    this.companyEmail,
    this.companyRegistrationNo,
  });

  bool get hasAnyInfo =>
      companyName != null || companyAddress != null || companyPhone != null || companyEmail != null;
}

/// Builds a simple one-page PDF receipt from a title and a list of
/// label/value rows — deliberately generic so any receipt-like screen
/// (bag purchase, subscription, booking) can reuse this rather than each
/// building its own PDF layout.
Future<Uint8List> buildReceiptPdf({
  required String title,
  required List<MapEntry<String, String>> rows,
  String? footerNote,
  ReceiptLetterhead? letterhead,
}) async {
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            (letterhead?.hasAnyInfo ?? false) ? letterhead!.companyName ?? 'Automaid' : 'Automaid',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          if (letterhead?.companyAddress != null)
            pw.Text(letterhead!.companyAddress!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          if (letterhead?.companyPhone != null || letterhead?.companyEmail != null)
            pw.Text(
              [letterhead?.companyPhone, letterhead?.companyEmail].where((v) => v != null).join('  ·  '),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          if (letterhead?.companyRegistrationNo != null)
            pw.Text('Reg. No: ${letterhead!.companyRegistrationNo}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Text(title, style: const pw.TextStyle(fontSize: 14)),
          pw.Divider(),
          pw.SizedBox(height: 8),
          for (final row in rows)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(row.key, style: const pw.TextStyle(color: PdfColors.grey700)),
                  pw.Text(row.value),
                ],
              ),
            ),
          if (footerNote != null) ...[
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.Text(footerNote, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ],
      ),
    ),
  );

  return doc.save();
}
