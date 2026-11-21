import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/features/forms/data/form_pdf_exporter.dart';
import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:counseling_is/features/forms/domain/form_submission.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Preview window for every form saved for one student.
///
/// Opens when the student's name is tapped in the saved-forms list, so the
/// list can group records by student instead of repeating the name on each
/// row. All of the student's forms are combined into one print-ready PDF,
/// and the per-form actions (open for editing, delete) live in this window.
class StudentFormsPreviewDialog extends StatefulWidget {
  const StudentFormsPreviewDialog({
    super.key,
    required this.studentName,
    required this.submissions,
    required this.onOpenForm,
    required this.onDeleteForm,
  });

  final String studentName;

  /// The student's saved records, newest first.
  final List<FormSubmission> submissions;

  /// Opens one record for editing on the underlying screen.
  final void Function(FormSubmission submission) onOpenForm;

  /// Deletes one record after confirmation; returns whether it was deleted.
  final Future<bool> Function(FormSubmission submission) onDeleteForm;

  static Future<void> show(
    BuildContext context, {
    required String studentName,
    required List<FormSubmission> submissions,
    required void Function(FormSubmission submission) onOpenForm,
    required Future<bool> Function(FormSubmission submission) onDeleteForm,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => StudentFormsPreviewDialog(
        studentName: studentName,
        submissions: submissions,
        onOpenForm: onOpenForm,
        onDeleteForm: onDeleteForm,
      ),
    );
  }

  @override
  State<StudentFormsPreviewDialog> createState() =>
      _StudentFormsPreviewDialogState();
}

class _StudentFormsPreviewDialogState extends State<StudentFormsPreviewDialog> {
  late final List<FormSubmission> _submissions = [...widget.submissions];

  /// The PDF is rebuilt whenever a record is removed from this window.
  Future<List<FormSubmission>>? _printable;

  Future<List<FormSubmission>> _resolvePrintable() {
    return _printable ??= Future.value(
      _submissions
          .where((submission) => counselingFormById(submission.formId) != null)
          .toList(growable: false),
    );
  }

  Future<void> _delete(FormSubmission submission) async {
    final deleted = await widget.onDeleteForm(submission);
    if (!deleted || !mounted) return;
    setState(() {
      _submissions.removeWhere((record) => record.id == submission.id);
      _printable = null;
    });
    if (_submissions.isEmpty && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _open(FormSubmission submission) {
    final open = widget.onOpenForm;
    Navigator.of(context).pop();
    open(submission);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final count = _submissions.length;

    return Dialog(
      // The preview reads as a document window, so it keeps square corners
      // instead of the rounded Material dialog default.
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
                          widget.studentName,
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          count == 1
                              ? '1 saved form · ready to print'
                              : '$count saved forms · ready to print',
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
            // A tab strip rather than separate pills: every tab sits on one
            // baseline, so the row reads as tabs above the preview.
            Container(
              height: 44,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.outlineVariant),
                ),
              ),
              child: _submissions.isEmpty
                  ? null
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      children: [
                        for (final submission in _submissions)
                          _FormTab(
                            submission: submission,
                            onOpen: () => _open(submission),
                            onDelete: () => _delete(submission),
                          ),
                      ],
                    ),
            ),
            Expanded(
              child: FutureBuilder<List<FormSubmission>>(
                future: _resolvePrintable(),
                builder: (context, snapshot) {
                  final printable = snapshot.data;
                  if (printable == null || printable.isEmpty) {
                    return Center(
                      child: Text(
                        'There are no printable forms for this student yet.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    );
                  }
                  return PdfPreview(
                    build: (_) async {
                      final export = await FormPdfExporter().exportBatch(
                        entries: [
                          for (final submission in printable)
                            (
                              form: counselingFormById(submission.formId)!,
                              data: submission.data,
                            ),
                        ],
                      );
                      return export.bytes;
                    },
                    pdfFileName: '${widget.studentName} forms',
                    // No debug toggle switch in this window.
                    canDebug: false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tab in the strip above the PDF preview: the label reopens the record
/// for editing, the trailing icon deletes it. Hovering or pressing the tab
/// reveals the underline indicator, the way a selected tab would look.
class _FormTab extends StatefulWidget {
  const _FormTab({
    required this.submission,
    required this.onOpen,
    required this.onDelete,
  });

  final FormSubmission submission;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_FormTab> createState() => _FormTabState();
}

class _FormTabState extends State<_FormTab> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final form = counselingFormById(widget.submission.formId);
    final label = form == null
        ? widget.submission.formId
        : '${form.documentNo} · ${form.title}';
    final active = _hovered || _pressed;

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active ? colors.primary : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: InkWell(
        onTap: widget.onOpen,
        onHover: (hovering) => setState(() => _hovered = hovering),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: active ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: active ? colors.primary : colors.onSurface,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete form',
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: colors.error,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
