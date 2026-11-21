import 'dart:io';

import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/features/clients/data/individual_student_sheet_docx_exporter.dart';
import 'package:counseling_is/features/clients/data/individual_student_sheet_pdf_exporter.dart';
import 'package:counseling_is/features/clients/data/word_pdf_converter.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Builds the preview PDF for one student's sheet. Injectable so tests can
/// supply bytes without driving the Word template pipeline.
typedef StudentSheetPdfBuilder = Future<Uint8List> Function(Client client);

/// Print-ready preview of one student's Individual Student Information Sheet,
/// filled straight from the student record. Opens from the Students list (the
/// preview action on a row) and from the student's detail window, so a sheet
/// can be printed without saving a form first.
///
/// The preview renders the real Word template through Microsoft Word whenever
/// that is possible, so the sheet keeps its exact original layout; the
/// built-in PDF renderer is the fallback.
class StudentSheetPreviewDialog extends StatefulWidget {
  const StudentSheetPreviewDialog({
    super.key,
    required this.client,
    this.builder,
  });

  final Client client;
  final StudentSheetPdfBuilder? builder;

  static Future<void> show(
    BuildContext context, {
    required Client client,
    StudentSheetPdfBuilder? builder,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          StudentSheetPreviewDialog(client: client, builder: builder),
    );
  }

  @override
  State<StudentSheetPreviewDialog> createState() =>
      _StudentSheetPreviewDialogState();
}

Future<Uint8List> _defaultSheetPdf(Client client) async {
  // Widget tests never drive Microsoft Word: keep them on the pure-Dart
  // renderer so the suite stays fast and deterministic.
  final inTests = Platform.environment.containsKey('FLUTTER_TEST');
  if (Platform.isWindows && !inTests && await WordPdfConverter.isAvailable()) {
    try {
      final docx = await const IndividualStudentSheetDocxExporter().export(
        client,
      );
      return await const WordPdfConverter().convert(docx);
    } catch (error) {
      debugPrint('Sheet preview fell back to the built-in renderer: $error');
    }
  }
  final export = await IndividualStudentSheetPdfExporter().export(client);
  return export.bytes;
}

class _StudentSheetPreviewDialogState extends State<StudentSheetPreviewDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final client = widget.client;

    return Dialog(
      // A document window: square corners instead of the rounded Material
      // dialog default, matching the student forms preview.
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SizedBox(
        width: 1050,
        height: MediaQuery.sizeOf(context).height * .88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.fullName,
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          'Individual Student Information Sheet · '
                          'ready to print',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close preview',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: PdfPreview(
                build: (_) =>
                    widget.builder?.call(client) ?? _defaultSheetPdf(client),
                pdfFileName:
                    '${client.fullName} — Individual Student Information Sheet',
                // No debug toggle switch in this window.
                canDebug: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
