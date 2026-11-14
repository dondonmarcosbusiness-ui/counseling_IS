import 'dart:typed_data';

import 'package:counseling_is/core/export/csv_export.dart';
import 'package:counseling_is/features/reports/data/report_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders a [ReportTable] as CSV text or PDF bytes for saving and
/// printing. Works entirely offline.
class ReportExporter {
  /// The table as CSV (header row plus data rows, with a UTF-8 BOM).
  String exportCsv(ReportTable table, {String? title, String? subtitle}) {
    final rows = <List<String>>[];
    if (title != null) rows.add(['Report', title]);
    if (subtitle != null) rows.add(['Details', subtitle]);
    if (rows.isNotEmpty) rows.add([]);
    rows
      ..add(table.columns)
      ..addAll(table.rows);
    return encodeCsv(rows);
  }

  /// The table as a paginated A4 PDF with repeating column headers.
  Future<Uint8List> exportPdf({
    required ReportTable table,
    required String title,
    required String subtitle,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _titleBlock(
          title: context.pageNumber == 1 ? title : '$title (continued)',
          subtitle: subtitle,
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          if (table.rows.isEmpty)
            pw.Text(
              'No records match the current filters.',
              style: const pw.TextStyle(fontSize: 10),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: [for (final column in table.columns) _pdfText(column)],
              data: [
                for (final row in table.rows)
                  [for (final cell in row) _pdfText(cell)],
              ],
              cellPadding: const pw.EdgeInsets.all(4),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _titleBlock({required String title, required String subtitle}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _pdfText(title),
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            _pdfText(subtitle),
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  /// The built-in PDF fonts only cover Latin-1; dashes outside that range
  /// are replaced so they still appear in the document.
  String _pdfText(String text) =>
      text.replaceAll(RegExp('[\u2010-\u2015]'), '-');
}
