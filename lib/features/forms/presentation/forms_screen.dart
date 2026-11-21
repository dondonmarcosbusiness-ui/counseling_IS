import 'dart:async';
import 'dart:io';

import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_data_table.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:counseling_is/core/widgets/confirm_dialog.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/core/widgets/list_states.dart';
import 'package:counseling_is/core/widgets/picker_field.dart';
import 'package:counseling_is/core/widgets/success_banner.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/forms/data/form_docx_exporter.dart';
import 'package:counseling_is/features/forms/data/form_pdf_exporter.dart';
import 'package:counseling_is/features/forms/data/form_submission_repository.dart';
import 'package:counseling_is/features/forms/data/word_print_preview.dart';
import 'package:counseling_is/features/forms/domain/composite_form.dart';
import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:counseling_is/features/forms/domain/form_submission.dart';
import 'package:counseling_is/features/forms/presentation/referral_email_dialog.dart';
import 'package:counseling_is/features/forms/presentation/student_forms_preview_dialog.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class FormsScreen extends StatefulWidget {
  const FormsScreen({super.key});

  @override
  State<FormsScreen> createState() => _FormsScreenState();
}

enum _FormsView { fill, saved }

class _FormsScreenState extends State<FormsScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  CounselingForm _selectedForm = counselingFormCatalog.first;
  late final TabController _tabController;
  FormSubmission? _activeSubmission;
  int _formRevision = 0;
  String _query = '';
  bool _tabPinned = false;
  String? _tabNotice;
  final Set<int> _selectedSubmissionIds = {};
  String? _batchError;
  late Future<List<FormSubmission>> _future;
  late Future<List<Client>> _clientsFuture;
  _FormsView _view = _FormsView.saved;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  /// Groups the loaded records into rows of the saved-forms table: one row
  /// per student so a name is never repeated, and one row for each record
  /// that was saved without a student so it stays reachable.
  List<_SavedFormRow> _groupSavedForms(List<FormSubmission> submissions) {
    final rows = <_SavedFormRow>[];
    final rowIndexByClient = <int, int>{};
    for (final submission in submissions) {
      final clientId = submission.clientId;
      if (clientId == null) {
        rows.add(_SavedFormRow(studentName: null, submissions: [submission]));
        continue;
      }
      final index = rowIndexByClient[clientId];
      if (index == null) {
        // The list is newest first, so the first record of a student is the
        // row's "last saved" value and sets the row's position.
        rowIndexByClient[clientId] = rows.length;
        rows.add(
          _SavedFormRow(
            studentName: submission.clientName,
            submissions: [submission],
          ),
        );
      } else {
        rows[index].submissions.add(submission);
      }
    }
    return rows;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: counselingFormCatalog.length,
      vsync: this,
    );
    _future = _load();
    _clientsFuture = context.read<ClientRepository>().search(
      const ClientQuery(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<List<FormSubmission>> _load() {
    return context.read<FormSubmissionRepository>().list(searchText: _query);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  /// Selects or clears every record behind one table row, so a whole
  /// student's forms are chosen with a single checkbox.
  void _toggleRowSelection(List<FormSubmission> records, bool? selected) {
    setState(() {
      for (final record in records) {
        if (record.id == null) continue;
        if (selected == true) {
          _selectedSubmissionIds.add(record.id!);
        } else {
          _selectedSubmissionIds.remove(record.id!);
        }
      }
      _batchError = null;
    });
  }

  bool _isRowSelected(List<FormSubmission> records) => records.any(
    (record) => record.id != null && _selectedSubmissionIds.contains(record.id),
  );

  Future<void> _deleteSelectedSubmissions(
    List<FormSubmission> visibleSubmissions,
  ) async {
    final selected = visibleSubmissions
        .where(
          (submission) =>
              submission.id != null &&
              _selectedSubmissionIds.contains(submission.id),
        )
        .toList();
    if (selected.isEmpty) return;

    await _deleteSubmissions(selected);
  }

  /// Deletes [records] after confirmation. Returns whether the records were
  /// actually removed, so callers such as the student preview window can
  /// drop them from their own list.
  Future<bool> _deleteSubmissions(List<FormSubmission> records) async {
    if (records.isEmpty) return false;
    final count = records.length;
    final confirmed = await showConfirmDialog(
      context,
      title: count == 1 ? 'Delete saved form?' : 'Delete saved forms?',
      message: count == 1
          ? 'This form record will be permanently deleted.'
          : 'These $count form records will be permanently deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return false;

    try {
      final repository = context.read<FormSubmissionRepository>();
      if (count == 1) {
        await repository.delete(records.single.id!);
      } else {
        await repository.deleteMany(records.map((record) => record.id!));
      }
      if (!mounted) return false;
      setState(() {
        for (final record in records) {
          if (record.id != null) _selectedSubmissionIds.remove(record.id);
        }
        _batchError = null;
      });
      _refresh();
      return true;
    } on AppException catch (error) {
      if (mounted) _showMessage(error.message);
      return false;
    } catch (_) {
      if (mounted) {
        _showMessage(
          'The form record${count == 1 ? '' : 's'} could not be deleted.',
        );
      }
      return false;
    }
  }

  void _handleFormTabChange(int index) {
    if (_tabPinned) {
      setState(
        () =>
            _tabNotice = 'This form is pinned. Unpin it before switching tabs.',
      );
      _tabController.animateTo(
        counselingFormCatalog.indexOf(_selectedForm),
        duration: Duration.zero,
      );
      return;
    }

    setState(() {
      _selectedForm = counselingFormCatalog[index];
      _activeSubmission = null;
      _tabNotice = null;
      _formRevision++;
    });
  }

  void _togglePinTab() {
    setState(() {
      _tabPinned = !_tabPinned;
      _tabNotice = null;
    });
  }

  void _newSubmission(CounselingForm form) {
    final index = counselingFormCatalog.indexOf(form);
    setState(() {
      _selectedForm = form;
      _activeSubmission = null;
      _tabNotice = null;
      _formRevision++;
      _view = _FormsView.fill;
    });
    _tabController.animateTo(index);
  }

  void _editSubmission(FormSubmission submission) {
    final form = counselingFormById(submission.formId);
    if (form == null) return;
    if (!counselingFormCatalog.contains(form)) {
      // Retired form (CC Form 1): the sheet is now part of the New student
      // dialog, so it no longer opens on this screen.
      _showMessage(
        'The Student Information Sheet is no longer filled here. '
        'New students are registered through the New student form.',
      );
      return;
    }
    if (_tabPinned && form.id != _selectedForm.id) {
      setState(
        () => _tabNotice =
            'This form is pinned. Unpin it before opening another saved form.',
      );
      return;
    }
    setState(() {
      _selectedForm = form;
      _activeSubmission = submission;
      _tabNotice = null;
      _formRevision++;
      _view = _FormsView.fill;
    });
    _tabController.animateTo(counselingFormCatalog.indexOf(form));
  }

  void _handleInlineFormSaved() {
    _refresh();
    setState(() {
      _activeSubmission = null;
      _formRevision++;
      _view = _FormsView.saved;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Form saved.')));
  }

  /// One form's entry in the "Forms" cell: the tappable title over its
  /// document number.
  Widget _formCellEntry(FormSubmission submission) {
    final theme = Theme.of(context);
    final form = counselingFormById(submission.formId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: form == null ? null : () => _editSubmission(submission),
          child: Text(form?.title ?? submission.formId),
        ),
        Text(
          form?.documentNo ?? 'Form',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Opens the preview window holding every form saved for one table row,
  /// laid out as one print-ready document.
  void _openStudentPreview(_SavedFormRow row) {
    StudentFormsPreviewDialog.show(
      context,
      studentName:
          row.studentName ??
          counselingFormById(row.newest.formId)?.title ??
          'Saved form',
      submissions: row.submissions,
      onOpenForm: _editSubmission,
      onDeleteForm: (submission) => _deleteSubmissions([submission]),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary,
                    colors.primary.withValues(alpha: .84),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student forms',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Complete and securely save the Care Center forms.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: .82),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: SegmentedButton<_FormsView>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? colors.primary
                          : Colors.transparent,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    side: const WidgetStatePropertyAll(BorderSide.none),
                    textStyle: WidgetStatePropertyAll(
                      theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: _FormsView.fill,
                      label: Text('Fill form'),
                      icon: Icon(Icons.edit_outlined),
                    ),
                    ButtonSegment(
                      value: _FormsView.saved,
                      label: Text('Saved forms'),
                      icon: Icon(Icons.folder_open_outlined),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (selection) => setState(() {
                    _view = selection.first;
                    _tabNotice = null;
                  }),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_view == _FormsView.fill) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Available forms',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Text(
                        '${counselingFormCatalog.length} templates',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    left: BorderSide(color: colors.outlineVariant),
                    right: BorderSide(color: colors.outlineVariant),
                    bottom: BorderSide(color: colors.outlineVariant),
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    onTap: _handleFormTabChange,
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    tabs: [
                      for (final form in counselingFormCatalog)
                        Tab(
                          child: Tooltip(
                            message: '${form.documentNo} · ${form.title}',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '${form.documentNo} · ${form.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_selectedForm.id == form.id && _tabPinned)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: const Icon(
                                      Icons.push_pin_rounded,
                                      size: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _tabNotice == null
                    ? const SizedBox.shrink(key: ValueKey('no-tab-notice'))
                    : Padding(
                        key: const ValueKey('tab-notice'),
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.push_pin_outlined,
                                size: 18,
                                color: colors.onSecondaryContainer,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _tabNotice!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _togglePinTab,
                                child: const Text('Unpin'),
                              ),
                              IconButton(
                                tooltip: 'Dismiss message',
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    setState(() => _tabNotice = null),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedForm.documentNo} · ${_selectedForm.title}'
                        '${_activeSubmission == null ? '' : ' · Editing saved form'}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (_tabPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: Text(
                          'Pinned',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: _tabPinned ? 'Unpin form tab' : 'Pin form tab',
                      onPressed: _togglePinTab,
                      icon: Icon(
                        _tabPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              CounselingFormPage(
                key: ValueKey(
                  '${_selectedForm.id}-${_activeSubmission?.id ?? 'new'}-$_formRevision',
                ),
                form: _selectedForm,
                submission: _activeSubmission,
                clientsFuture: _clientsFuture,
                embedded: true,
                onSaved: _handleInlineFormSaved,
              ),
            ],
            if (_view == _FormsView.saved) ...[
              Row(
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    color: colors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Saved forms', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search student or form',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      onChanged: (value) => setState(() {
                        _query = value;
                        _selectedSubmissionIds.clear();
                        _batchError = null;
                        _future = _load();
                      }),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (_activeSubmission != null) ...[
                    OutlinedButton.icon(
                      onPressed: () => _newSubmission(_selectedForm),
                      icon: const Icon(Icons.add),
                      label: const Text('New blank form'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (_selectedSubmissionIds.isNotEmpty)
                    FutureBuilder<List<FormSubmission>>(
                      future: _future,
                      builder: (context, snapshot) {
                        final selected =
                            (snapshot.data ?? const <FormSubmission>[])
                                .where(
                                  (submission) =>
                                      submission.id != null &&
                                      _selectedSubmissionIds.contains(
                                        submission.id,
                                      ),
                                )
                                .toList();
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_selectedSubmissionIds.length} selected'),
                            const SizedBox(width: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _deleteSelectedSubmissions(selected),
                              icon: const Icon(Icons.delete_outline),
                              label: Text('Delete (${selected.length})'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.error,
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _selectedSubmissionIds.clear();
                                _batchError = null;
                              }),
                              child: const Text('Clear'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                        );
                      },
                    ),
                  IconButton(
                    onPressed: _refresh,
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_batchError != null) ...[
                ErrorBanner(message: _batchError!),
                const SizedBox(height: AppSpacing.sm),
              ],
              FutureBuilder<List<FormSubmission>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return LoadErrorState(onRetry: _refresh);
                  }
                  final submissions = snapshot.data!;
                  if (submissions.isEmpty) {
                    return EmptyListState(
                      icon: Icons.description_outlined,
                      title: _query.isEmpty
                          ? 'No saved forms yet'
                          : 'No matching forms',
                      message: _query.isEmpty
                          ? 'Switch to the Fill form tab to start a new record.'
                          : 'Try a different search or form type.',
                    );
                  }
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: AppDataTable(
                      showCheckboxColumn: true,
                      // Cells stack a form title over its number, so rows
                      // must be allowed to grow past the control height.
                      dataRowMaxHeight: double.infinity,
                      columns: const [
                        DataColumn(label: Text('Student')),
                        DataColumn(label: Text('Forms')),
                        DataColumn(label: Text('Last saved')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final row in _groupSavedForms(submissions))
                          DataRow(
                            key: ValueKey(row.newest.id),
                            selected: _isRowSelected(row.submissions),
                            onSelectChanged: (selected) =>
                                _toggleRowSelection(row.submissions, selected),
                            cells: [
                              DataCell(
                                row.studentName == null
                                    ? const Text('No linked student')
                                    : InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () => _openStudentPreview(row),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                            horizontal: 6,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                row.studentName!,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: colors.primary,
                                                ),
                                              ),
                                              Text(
                                                row.submissions.length == 1
                                                    ? '1 saved form'
                                                    : '${row.submissions.length} saved forms',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                              DataCell(
                                Builder(
                                  builder: (context) {
                                    // Only the newest form is listed so the
                                    // row stays one line tall; the rest are
                                    // reachable from the preview window.
                                    final visible = row.submissions
                                        .take(1)
                                        .toList(growable: false);
                                    final extra =
                                        row.submissions.length - visible.length;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final (index, submission)
                                            in visible.indexed)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom:
                                                  index == visible.length - 1 &&
                                                      extra == 0
                                                  ? 0
                                                  : AppSpacing.sm,
                                            ),
                                            child: _formCellEntry(submission),
                                          ),
                                        if (extra > 0)
                                          InkWell(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            onTap: () =>
                                                _openStudentPreview(row),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                    horizontal: 4,
                                                  ),
                                              child: Text(
                                                '+$extra more',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colors.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              DataCell(
                                Text(formatDateTime(row.newest.updatedAt)),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Preview and print forms',
                                      icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                      ),
                                      onPressed: () => _openStudentPreview(row),
                                    ),
                                    IconButton(
                                      tooltip: row.submissions.length == 1
                                          ? 'Delete form'
                                          : 'Delete forms',
                                      icon: const Icon(Icons.delete_outline),
                                      style: IconButton.styleFrom(
                                        foregroundColor: colors.error,
                                      ),
                                      onPressed: () =>
                                          _deleteSubmissions(row.submissions),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One row of the saved-forms table: either every record saved for a single
/// student, or one record that was saved without a student.
class _SavedFormRow {
  _SavedFormRow({
    required this.studentName,
    required List<FormSubmission> submissions,
  }) : submissions = [...submissions];

  /// Null for records that were saved without a linked student.
  final String? studentName;

  /// The student's records, newest first.
  final List<FormSubmission> submissions;

  /// The record that sets the row's "last saved" value and position.
  FormSubmission get newest => submissions.first;

  bool get isLinked => studentName != null;
}

/// Everything the merged page needs to fill several forms for one student
/// in a single pass: the composite rendering, the student to save against,
/// and the latest saved record per form so existing records are updated
/// instead of duplicated.
class BatchFormSpec {
  const BatchFormSpec({
    required this.composite,
    required this.clientId,
    this.batchId,
    this.existingByForm = const {},
  });

  /// The chosen forms merged into one page.
  final CompositeForm composite;

  /// Student the whole batch is saved against.
  final int? clientId;

  /// Set when reopening a batch that was saved before.
  final String? batchId;

  /// Latest saved record per form ID, refreshed after every save.
  final Map<String, FormSubmission> existingByForm;
}

/// A value read back from a saved source record before the merged page
/// initialises its fields — [group] and [part] are the record's own name
/// fields, which may differ from the composite's canonical ones.
class _BatchSourceValue {
  const _BatchSourceValue({
    required this.value,
    required this.data,
    required this.group,
    required this.part,
  });

  final Object? value;
  final Map<String, Object?> data;
  final String? group;
  final FormNamePart? part;
}

class CounselingFormPage extends StatefulWidget {
  const CounselingFormPage({
    super.key,
    required this.form,
    this.submission,
    this.clientsFuture,
    this.embedded = false,
    this.onSaved,
    this.batch,
  });

  final CounselingForm form;
  final FormSubmission? submission;
  final Future<List<Client>>? clientsFuture;
  final bool embedded;
  final VoidCallback? onSaved;

  /// Non-null when this page renders a batch: [form] is then the composite
  /// of every chosen form.
  final BatchFormSpec? batch;

  @override
  State<CounselingFormPage> createState() => _CounselingFormPageState();
}

class _CounselingFormPageState extends State<CounselingFormPage> {
  static const _fieldLabelHeight = 40.0;

  final _pdfExporter = FormPdfExporter();
  final _docxExporter = FormDocxExporter();
  final _textControllers = <String, TextEditingController>{};
  final _dates = <String, DateTime?>{};
  final _choices = <String, String?>{};
  final _multipleChoices = <String, Set<String>>{};
  final _repeatableEntries =
      <String, List<Map<String, TextEditingController>>>{};
  final _checks = <String, bool>{};
  final _autoFilledTextValues = <String, String>{};
  final _autoFilledDates = <String, DateTime>{};
  final _autoFilledChoices = <String, String>{};
  Map<String, Object?> _profile = const {};
  List<Client> _clients = [];
  int? _clientId;
  final _existingByForm = <String, FormSubmission>{};
  String? _batchId;
  bool _clientsLoading = true;
  bool _saving = false;
  bool _exporting = false;
  String? _error;

  /// Inline confirmation of the last successful save, shown at the top of
  /// the form until it is dismissed or a new save starts.
  String? _notice;

  bool get _isEdit => widget.submission != null;

  bool get _isBatch => widget.batch != null;

  String get _batchSaveLabel => _isBatch
      ? 'Save all'
      : _isEdit
      ? 'Save changes'
      : 'Save form';

  bool get _hasAnyAnswer =>
      _clientId != null ||
      _textControllers.values.any(
        (controller) => controller.text.trim().isNotEmpty,
      ) ||
      _dates.values.any((date) => date != null) ||
      _choices.values.any((choice) => choice != null) ||
      _multipleChoices.values.any((choices) => choices.isNotEmpty) ||
      _repeatableEntries.values.any(
        (entries) => entries.any(
          (entry) => entry.values.any(
            (controller) => controller.text.trim().isNotEmpty,
          ),
        ),
      ) ||
      _checks.values.any((checked) => checked);

  Map<FormNamePart, String> _legacyNameParts(String legacyName) {
    final parts = <FormNamePart, String>{
      FormNamePart.first: '',
      FormNamePart.middle: '',
      FormNamePart.last: '',
      FormNamePart.suffix: '',
    };
    final trimmed = legacyName.trim();
    if (trimmed.isEmpty) return parts;

    final commaParts = trimmed.split(',').map((part) => part.trim()).toList();
    final lastName = commaParts.length > 1 ? commaParts.first : '';
    final givenParts = commaParts.length > 1
        ? commaParts.skip(1).expand((part) => part.split(RegExp(r'\s+')))
        : trimmed.split(RegExp(r'\s+'));
    final tokens = givenParts.where((part) => part.isNotEmpty).toList();
    if (lastName.isNotEmpty) {
      parts[FormNamePart.last] = lastName;
    } else if (tokens.length > 1) {
      parts[FormNamePart.last] = tokens.removeLast();
    }

    const suffixes = {'jr', 'jr.', 'sr', 'sr.', 'ii', 'iii', 'iv', 'v'};
    if (tokens.isNotEmpty && suffixes.contains(tokens.last.toLowerCase())) {
      parts[FormNamePart.suffix] = tokens.removeLast();
    }
    if (tokens.isNotEmpty) {
      parts[FormNamePart.first] = tokens.removeAt(0);
    }
    if (tokens.isNotEmpty) {
      parts[FormNamePart.middle] = tokens.join(' ');
    }
    return parts;
  }

  @override
  void initState() {
    super.initState();
    final submission = widget.submission;
    _clientId = submission?.clientId ?? widget.batch?.clientId;
    _batchId = widget.batch?.batchId;
    _existingByForm.addAll(widget.batch?.existingByForm ?? const {});

    // Batch mode: read each source record back under the composite IDs the
    // merged page renders, so reopening a batch restores every form.
    final batchValues = <String, _BatchSourceValue>{};
    final composite = widget.batch?.composite;
    if (composite != null) {
      for (final source in composite.sourceForms) {
        final record = _existingByForm[source.id];
        if (record == null) continue;
        for (final section in source.sections) {
          for (final question in section.questions) {
            final compositeId = composite.compositeIdFor(
              source.id,
              question.id,
            );
            final value = record.data[question.id];
            final current = batchValues[compositeId];
            if (current == null || (current.value == null && value != null)) {
              batchValues[compositeId] = _BatchSourceValue(
                value: value,
                data: record.data,
                group: question.nameGroup,
                part: question.namePart,
              );
            }
          }
        }
      }
    }

    for (final section in widget.form.sections) {
      for (final question in section.questions) {
        final sourceValue = batchValues[question.id];
        _initializeQuestion(
          question,
          composite == null
              ? submission?.data[question.id]
              : sourceValue?.value,
          legacyData: composite == null ? submission?.data : sourceValue?.data,
          legacyGroup: composite == null
              ? question.nameGroup
              : sourceValue?.group,
          legacyPart: composite == null ? question.namePart : sourceValue?.part,
        );
      }
    }
    _loadClients();
  }

  /// Seeds one field from a saved answer, falling back to the legacy
  /// full-name string older records stored under the name group.
  void _initializeQuestion(
    FormQuestion question,
    Object? value, {
    Map<String, Object?>? legacyData,
    String? legacyGroup,
    FormNamePart? legacyPart,
  }) {
    if (value == null &&
        legacyData != null &&
        legacyGroup != null &&
        legacyPart != null &&
        legacyData[legacyGroup] is String) {
      value = _legacyNameParts(legacyData[legacyGroup] as String)[legacyPart]!;
    }
    switch (question.type) {
      case FormInputType.text:
      case FormInputType.multiline:
        _textControllers[question.id] = TextEditingController(
          text: value as String? ?? '',
        );
      case FormInputType.date:
        _dates[question.id] = DateTime.tryParse(value as String? ?? '');
      case FormInputType.choice:
        _choices[question.id] = value as String?;
      case FormInputType.choices:
        _multipleChoices[question.id] = value is List
            ? value.whereType<String>().toSet()
            : <String>{};
      case FormInputType.checkbox:
        _checks[question.id] = value == true;
      case FormInputType.repeatable:
        _repeatableEntries[question.id] = _initialRepeatableEntries(
          question,
          value,
        );
    }
  }

  List<Map<String, TextEditingController>> _initialRepeatableEntries(
    FormQuestion question,
    Object? value,
  ) {
    final oldRows = <Map<String, String>>[];
    if (value is List<Object?>) {
      for (final item in value) {
        if (item is! Map<Object?, Object?>) continue;
        oldRows.add({
          for (final entry in item.entries)
            entry.key.toString(): entry.value?.toString() ?? '',
        });
      }
    } else if (value is String && value.trim().isNotEmpty) {
      for (final line in value.split(RegExp(r'\r?\n'))) {
        if (line.trim().isEmpty) continue;
        final parts = line.split('|');
        if (question.id == 'session_records' && parts.length == 1) {
          oldRows.add({'summary': line.trim()});
          continue;
        }
        oldRows.add({
          for (final (index, field) in question.entryFields.indexed)
            if (index < parts.length) field.id: parts[index].trim(),
        });
      }
    }
    final rows = oldRows.isEmpty ? [<String, String>{}] : oldRows;
    return [
      for (final row in rows)
        {
          for (final field in question.entryFields)
            field.id: TextEditingController(text: row[field.id] ?? ''),
        },
    ];
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    for (final entries in _repeatableEntries.values) {
      for (final entry in entries) {
        for (final controller in entry.values) {
          controller.dispose();
        }
      }
    }
    super.dispose();
  }

  void _addRepeatableEntry(FormQuestion question) {
    setState(() {
      _repeatableEntries[question.id]!.add({
        for (final field in question.entryFields)
          field.id: TextEditingController(),
      });
    });
  }

  void _removeRepeatableEntry(FormQuestion question, int index) {
    final entries = _repeatableEntries[question.id]!;
    if (entries.length <= 1) return;
    setState(() {
      final removed = entries.removeAt(index);
      for (final controller in removed.values) {
        controller.dispose();
      }
    });
  }

  Future<void> _loadClients() async {
    try {
      final clients =
          await (widget.clientsFuture ??
              context.read<ClientRepository>().search(const ClientQuery()));
      if (mounted) {
        final linkedClient = clients
            .where((client) => client.id == _clientId)
            .firstOrNull;
        if (linkedClient != null) {
          _applyClientToStudentFields(linkedClient);
        }
        setState(() {
          _clients = clients;
          _clientsLoading = false;
        });
        unawaited(_loadProfile(_clientId));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _clientsLoading = false;
          _error = 'Could not load the student list.';
        });
      }
    }
  }

  void _linkClient(int? clientId) {
    final client = _clients.where((item) => item.id == clientId).firstOrNull;
    setState(() {
      _clientId = clientId;
      if (client != null) _applyClientToStudentFields(client);
    });
    unawaited(_loadProfile(clientId));
  }

  /// Loads the personal information the counselor already recorded in the
  /// student's Student Information Sheet so it never has to be typed again.
  Future<void> _loadProfile(int? clientId) async {
    if (clientId == null || widget.form.id == 'student_information') {
      return;
    }
    try {
      final repository = context.read<FormSubmissionRepository>();
      final data = await repository.latestDataForClient(
        clientId,
        'student_information',
      );
      if (!mounted || _clientId != clientId || data == null) return;
      setState(() {
        _profile = data;
        _applyProfileToFields();
      });
    } catch (_) {
      // Auto-fill is a convenience; the form stays fully editable without it.
    }
  }

  String _profileText(String key) => (_profile[key] as String?)?.trim() ?? '';

  String _profileName(String group, String part) =>
      _profileText('${group}_$part');

  void _applyProfileToFields() {
    if (_profile.isEmpty) return;
    // Prefer the guardian, then the mother, then the father.
    String? parentGroup;
    String parentContact = '';
    for (final (group, contactKey) in const [
      ('guardian_name', 'guardian_contact_address'),
      ('mother_name', 'mother_contact'),
      ('father_name', 'father_contact'),
    ]) {
      if (_profileName(group, 'first').isNotEmpty ||
          _profileName(group, 'last').isNotEmpty) {
        parentGroup = group;
        parentContact = _profileText(contactKey);
        break;
      }
    }
    const partKeys = {
      FormNamePart.first: 'first',
      FormNamePart.middle: 'middle',
      FormNamePart.last: 'last',
      FormNamePart.suffix: 'suffix',
    };
    final birthDate = DateTime.tryParse(_profileText('date_of_birth'));

    for (final section in widget.form.sections) {
      for (final question in section.questions) {
        final controller = _textControllers[question.id];
        if (controller != null) {
          String? value;
          if (question.nameGroup == 'parent_guardian' &&
              parentGroup != null &&
              question.namePart != null) {
            value = _profileName(parentGroup, partKeys[question.namePart]!);
          } else if (question.id == 'grade_section') {
            value = _profileText('grade_section');
          } else if (question.id == 'home_address' ||
              question.id == 'address_visited') {
            value = _profileText('home_address');
          } else if (question.id == 'religion') {
            value = _profileText('religion');
          } else if (question.id == 'guardian_contact') {
            value = parentContact;
          } else if (question.id == 'contact_number' &&
              (widget.form.id == 'counseling_intake' || _isBatch)) {
            value = parentContact;
          } else if (question.id == 'age' &&
              controller.text.trim().isEmpty &&
              birthDate != null) {
            value = _clientAge(birthDate).toString();
          }
          if (value != null && value.isNotEmpty) {
            _applyAutoFilledText(question.id, controller, value);
          }
        }

        if (question.type == FormInputType.date &&
            question.id == 'date_of_birth' &&
            _dates[question.id] == null &&
            birthDate != null) {
          _dates[question.id] = birthDate;
          _autoFilledDates[question.id] = birthDate;
        }

        if (question.type == FormInputType.choice && question.id == 'sex') {
          final value = _profileText('sex');
          final current = _choices[question.id];
          if (value.isNotEmpty &&
              question.options.contains(value) &&
              (current == null || current == _autoFilledChoices[question.id])) {
            _choices[question.id] = value;
            _autoFilledChoices[question.id] = value;
          }
        }
      }
    }
  }

  void _applyClientToStudentFields(Client client) {
    const identityNameGroups = {'student_name', 'learner_name', 'client_name'};
    final parentNames = <String, Map<FormNamePart, String>>{
      'father_name': _legacyNameParts(client.fatherName ?? ''),
      'mother_name': _legacyNameParts(client.motherName ?? ''),
      'guardian_name': _legacyNameParts(client.guardianName ?? ''),
    };
    final legacyNameParts = _legacyNameParts(client.fullName);
    final nameParts = {
      FormNamePart.first: _clientNamePart(
        client.firstName,
        legacyNameParts,
        FormNamePart.first,
      ),
      FormNamePart.middle: _clientNamePart(
        client.middleName,
        legacyNameParts,
        FormNamePart.middle,
      ),
      FormNamePart.last: _clientNamePart(
        client.lastName,
        legacyNameParts,
        FormNamePart.last,
      ),
      FormNamePart.suffix: _clientNamePart(
        client.suffix,
        legacyNameParts,
        FormNamePart.suffix,
      ),
    };

    final simpleValues = <String, String>{
      'contact_number': client.phone ?? '',
      if (client.dateOfBirth != null)
        'age': _clientAge(client.dateOfBirth!).toString(),
      if (client.gradeSection != null) 'grade_section': client.gradeSection!,
      if (client.address != null) ...{
        'home_address': client.address!,
        'address_visited': client.address!,
      },
      if (client.religion != null) 'religion': client.religion!,
      if (client.fatherJob != null) 'father_occupation': client.fatherJob!,
      if (client.fatherEducation != null)
        'father_education': client.fatherEducation!,
      if (client.motherJob != null) 'mother_occupation': client.motherJob!,
      if (client.motherEducation != null)
        'mother_education': client.motherEducation!,
      if (client.guardianRelationship != null)
        'guardian_relationship': client.guardianRelationship!,
    };

    for (final section in widget.form.sections) {
      for (final question in section.questions) {
        final controller = _textControllers[question.id];
        if (controller != null) {
          String? value;
          final parentParts = parentNames[question.nameGroup];
          if (question.nameGroup != null &&
              identityNameGroups.contains(question.nameGroup)) {
            value = nameParts[question.namePart];
          } else if (parentParts != null && question.namePart != null) {
            value = parentParts[question.namePart]!;
          } else if (identityNameGroups.contains(question.id)) {
            value = client.fullName;
          } else if (simpleValues.containsKey(question.id)) {
            value = simpleValues[question.id];
          }
          if (value != null) {
            _applyAutoFilledText(question.id, controller, value);
          }
        }

        if (question.type == FormInputType.choice && question.id == 'sex') {
          final value = client.sex;
          final current = _choices[question.id];
          if (value != null &&
              question.options.contains(value) &&
              (current == null || current == _autoFilledChoices[question.id])) {
            _choices[question.id] = value;
            _autoFilledChoices[question.id] = value;
          }
        }

        if (question.type == FormInputType.date &&
            question.id == 'date_of_birth') {
          final previousValue = _autoFilledDates[question.id];
          final currentValue = _dates[question.id];
          if (currentValue == null || currentValue == previousValue) {
            _dates[question.id] = client.dateOfBirth;
            if (client.dateOfBirth == null) {
              _autoFilledDates.remove(question.id);
            } else {
              _autoFilledDates[question.id] = client.dateOfBirth!;
            }
          } else {
            _autoFilledDates.remove(question.id);
          }
        }
      }
    }
  }

  String _clientNamePart(
    String? value,
    Map<FormNamePart, String> legacyParts,
    FormNamePart part,
  ) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? legacyParts[part]! : trimmed;
  }

  void _applyAutoFilledText(
    String fieldId,
    TextEditingController controller,
    String value,
  ) {
    final currentValue = controller.text.trim();
    final previousValue = _autoFilledTextValues[fieldId];
    if (currentValue.isEmpty || currentValue == previousValue) {
      controller.text = value;
      if (value.trim().isEmpty) {
        _autoFilledTextValues.remove(fieldId);
      } else {
        _autoFilledTextValues[fieldId] = value;
      }
    } else {
      _autoFilledTextValues.remove(fieldId);
    }
  }

  int _clientAge(DateTime dateOfBirth) {
    final today = DateTime.now();
    var age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDate(FormQuestion question) async {
    final now = DateTime.now();
    final current = _dates[question.id];
    final picked = await _showDatePicker(current ?? now);
    if (picked != null && mounted) {
      setState(() => _dates[question.id] = picked);
    }
  }

  Future<void> _pickRepeatableDate(
    FormQuestion question,
    int entryIndex,
    FormEntryField field,
  ) async {
    final controller = _repeatableEntries[question.id]![entryIndex][field.id]!;
    final current = DateTime.tryParse(controller.text);
    final picked = await _showDatePicker(current ?? DateTime.now());
    if (picked != null && mounted) {
      setState(() {
        controller.text = _dateValue(picked);
      });
    }
  }

  Future<DateTime?> _showDatePicker(DateTime initialDate) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 100),
    );
  }

  String _dateValue(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  DateTime? _parseDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> _save() async {
    if (_isBatch) {
      await _saveBatch();
      return;
    }
    if (!_hasAnyAnswer) {
      setState(() => _error = 'Enter at least one response before saving.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = _collectData();
    final repository = context.read<FormSubmissionRepository>();
    try {
      final existing = widget.submission;
      if (existing == null) {
        await repository.create(
          formId: widget.form.id,
          clientId: _clientId,
          data: data,
        );
      } else {
        await repository.update(
          FormSubmission(
            id: existing.id,
            formId: widget.form.id,
            clientId: _clientId,
            data: data,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
          ),
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'The form record could not be saved.';
          _saving = false;
        });
      }
      return;
    }

    if (!mounted) return;
    if (widget.onSaved != null) {
      widget.onSaved!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  /// Saves every selected form as its own record in one batch. Forms the
  /// administrator left untouched are skipped; existing records for the
  /// student are updated in place.
  Future<void> _saveBatch() async {
    final spec = widget.batch!;
    if (_clientId == null) {
      setState(() => _error = 'Select a student before saving the batch.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });

    final compositeData = _collectData();
    final byForm = spec.composite.split(compositeData);
    final toSave = <String, Map<String, Object?>>{
      for (final entry in byForm.entries)
        if (spec.composite.isAnswered(entry.key, compositeData))
          entry.key: entry.value,
    };
    if (toSave.isEmpty) {
      setState(() {
        _saving = false;
        _error = 'Fill in at least one of the selected forms before saving.';
      });
      return;
    }

    _batchId ??= 'batch-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final saved = await context.read<FormSubmissionRepository>().saveBatch(
        clientId: _clientId!,
        batchId: _batchId!,
        dataByForm: toSave,
        existingIdsByForm: {
          for (final entry in _existingByForm.entries)
            entry.key: entry.value.id,
        },
      );
      if (!mounted) return;
      final skipped = byForm.length - saved.length;
      setState(() {
        _existingByForm.addAll(saved);
        _saving = false;
        _error = null;
        _notice = skipped == 0
            ? 'Saved ${saved.length} form${saved.length == 1 ? '' : 's'}.'
            : 'Saved ${saved.length} of ${byForm.length} forms — '
                  '$skipped empty form${skipped == 1 ? '' : 's'} skipped.';
      });
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'The batch could not be saved.';
          _saving = false;
        });
      }
    }
  }

  Map<String, Object?> _collectData() {
    final data = <String, Object?>{};
    for (final section in widget.form.sections) {
      for (final question in section.questions) {
        switch (question.type) {
          case FormInputType.text:
          case FormInputType.multiline:
            data[question.id] = _textControllers[question.id]!.text.trim();
          case FormInputType.date:
            final value = _dates[question.id];
            data[question.id] = value == null ? null : _dateValue(value);
          case FormInputType.choice:
            data[question.id] = _choices[question.id];
          case FormInputType.choices:
            data[question.id] = _multipleChoices[question.id]!.toList();
          case FormInputType.checkbox:
            data[question.id] = _checks[question.id] ?? false;
          case FormInputType.repeatable:
            data[question.id] = [
              for (final entry in _repeatableEntries[question.id]!)
                if (entry.values.any(
                  (controller) => controller.text.trim().isNotEmpty,
                ))
                  {
                    for (final field in question.entryFields)
                      field.id: entry[field.id]!.text.trim(),
                  },
            ];
        }
      }
    }
    return data;
  }

  /// Plain-text summary of the referral for the e-mail body. Only the
  /// referral itself is included, never counseling session notes.
  ({String subject, String body}) _referralEmailContent() {
    final data = _collectData();
    String text(String key) => (data[key] as String?)?.trim() ?? '';
    String name(String group) => [
      text('${group}_first'),
      text('${group}_middle'),
      text('${group}_last'),
      text('${group}_suffix'),
    ].where((part) => part.isNotEmpty).join(' ');
    List<String> list(String key) =>
        (data[key] as List?)?.whereType<String>().toList() ?? const [];

    final learner = name('learner_name');
    final reasons = [
      for (final reason in list('referral_reasons'))
        if (reason == 'Others' && text('other_reason').isNotEmpty)
          'Others: ${text('other_reason')}'
        else
          reason,
    ];
    final referrer = [
      name('referring_person'),
      text('designation'),
    ].where((part) => part.isNotEmpty).join(', ');
    final lines = <String>[
      'REFERRAL FORM (CC Form 4)',
      'Carranglan National High School — Guidance Office',
      '',
      'Learner: ${learner.isEmpty ? '—' : learner}',
      'Grade and section: ${text('grade_section').isEmpty ? '—' : text('grade_section')}',
      'Referred by: ${referrer.isEmpty ? '—' : referrer}',
      'Date referred: ${(data['referral_date'] as String?) ?? '—'}',
      '',
      'Reasons for referral:',
      if (reasons.isEmpty) '—' else ...reasons.map((reason) => '- $reason'),
      '',
      'Brief description of concern:',
      text('concern_description').isEmpty ? '—' : text('concern_description'),
      '',
      'Actions already taken:',
      if (list('actions_taken').isEmpty)
        '—'
      else
        ...list('actions_taken').map((action) => '- $action'),
      '',
      'Sent from Counseling IS. This message contains confidential learner '
          'information protected under the Data Privacy Act of 2012.',
    ];
    return (
      subject:
          'Referral — ${learner.isEmpty ? 'learner' : learner} — Carranglan NHS',
      body: lines.join('\n'),
    );
  }

  Future<void> _sendReferralEmail() async {
    final content = _referralEmailContent();
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          ReferralEmailDialog(subject: content.subject, body: content.body),
    );
  }

  /// Fills the original Word template (the exact form the school supplied)
  /// with the answers and opens it in Word's print preview, so the printed
  /// form keeps the original layout.
  Future<void> _printOriginalLayout() async {
    if (_exporting || _clientsLoading) return;
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Word document', extensions: ['docx']),
      ],
      suggestedName:
          '${widget.form.id}-${DateTime.now().toIso8601String().split('T').first}.docx',
    );
    if (location == null || !mounted) return;
    setState(() {
      _exporting = true;
      _error = null;
    });

    var message = 'The form was saved and opened in Word print preview.';
    try {
      final result = await _docxExporter.export(
        form: widget.form,
        data: _collectData(),
      );
      var path = location.path;
      if (!path.toLowerCase().endsWith('.docx')) path = '$path.docx';
      await File(path).writeAsBytes(result.bytes, flush: true);
      try {
        await const WordPrintPreview().open(path);
      } on AppException catch (error) {
        message = '${error.message} The form was saved to: $path';
      } catch (_) {
        message =
            'The form was saved to $path but could not be opened '
            'automatically. Open the file to print it.';
      }
    } catch (_) {
      message = 'Could not create the Word form.';
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
            content: Text(message),
          ),
        );
      }
    }
  }

  Future<void> _exportForPrinting() async {
    if (_exporting || _clientsLoading) return;
    final composite = widget.batch?.composite;
    final compositeData = _collectData();
    final entries = <({CounselingForm form, Map<String, Object?> data})>[];
    if (composite != null) {
      final byForm = composite.split(compositeData);
      for (final source in composite.sourceForms) {
        if (composite.isAnswered(source.id, compositeData)) {
          entries.add((form: source, data: byForm[source.id]!));
        }
      }
      if (entries.isEmpty) {
        setState(() => _error = 'Fill in at least one form before exporting.');
        return;
      }
    } else {
      entries.add((form: widget.form, data: compositeData));
    }
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF document', extensions: ['pdf']),
      ],
      suggestedName:
          '${composite == null ? widget.form.id : 'batch-forms'}-'
          '${DateTime.now().toIso8601String().split('T').first}.pdf',
    );
    if (location == null || !mounted) return;
    setState(() {
      _exporting = true;
      _error = null;
    });

    try {
      final result = await _pdfExporter.exportBatch(entries: entries);
      await File(location.path).writeAsBytes(result.bytes, flush: true);

      var printMessage = 'The PDF was saved and is ready to print.';
      Object? printError;
      try {
        final printed = await Printing.layoutPdf(
          name: composite == null
              ? '${widget.form.title}.pdf'
              : 'Combined student forms.pdf',
          format: result.pageFormat,
          onLayout: (_) async => result.bytes,
        );
        if (!printed) {
          printMessage = 'The PDF was saved. The print dialog was closed without printing.';
        }
      } catch (error) {
        printError = error;
        printMessage = error is AppException
            ? error.message
            : 'The PDF was saved, but the print dialog could not be opened.';
      }

      if (mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            width: MediaQuery.sizeOf(context).width >= 600 ? 520 : null,
            backgroundColor: scheme.surface,
            elevation: 4,
            showCloseIcon: true,
            closeIconColor: scheme.onSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    printError == null
                        ? Icons.check_circle_outline
                        : Icons.save_alt,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printError == null ? 'PDF exported' : 'PDF saved',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        printMessage,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 7),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is AppException
              ? error.message
              : 'The completed form could not be exported for printing.';
        });
      } else {
        rethrow;
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paperBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    );
    final paperFocusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
    );
    final formDocument = ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Theme(
              data: theme.copyWith(
                inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLowest,
                  isDense: true,
                  border: paperBorder,
                  enabledBorder: paperBorder,
                  focusedBorder: paperFocusedBorder,
                  disabledBorder: paperBorder,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  constraints: const BoxConstraints(minHeight: 50),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_notice != null) ...[
                    SuccessBanner(
                      message: _notice!,
                      onDismiss: () => setState(() => _notice = null),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _buildDocumentHeading(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildClientField(),
                  const SizedBox(height: AppSpacing.lg),
                  ..._buildFormSections(),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.form.id == 'referral')
                  IconButton(
                    onPressed: _saving || _exporting
                        ? null
                        : _sendReferralEmail,
                    icon: const Icon(Icons.forward_to_inbox_outlined),
                    tooltip: 'Send referral by e-mail',
                  ),
                if (!_isBatch)
                  IconButton(
                    onPressed: _saving || _exporting
                        ? null
                        : _printOriginalLayout,
                    icon: _exporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined),
                    tooltip: 'Print (exact form layout, opens Word)',
                  ),
                IconButton(
                  onPressed: _saving || _exporting ? null : _exportForPrinting,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: _isBatch
                      ? 'Save as PDF (all forms in this batch)'
                      : 'Save as PDF (app layout)',
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_batchSaveLabel),
                ),
              ],
            ),
          ),
          formDocument,
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _saving ? null : () => context.pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to forms',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.form.title),
            Text(
              '${widget.form.documentNo}'
              '${_isEdit ? ' · Edit saved form' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (widget.form.id == 'referral')
            IconButton(
              onPressed: _saving || _exporting ? null : _sendReferralEmail,
              icon: const Icon(Icons.forward_to_inbox_outlined),
              tooltip: 'Send referral by e-mail',
            ),
          if (!_isBatch)
            IconButton(
              onPressed: _saving || _exporting ? null : _printOriginalLayout,
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_outlined),
              tooltip: 'Print (exact form layout, opens Word)',
            ),
          IconButton(
            onPressed: _saving || _exporting ? null : _exportForPrinting,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: _isBatch
                ? 'Save as PDF (all forms in this batch)'
                : 'Save as PDF (app layout)',
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_batchSaveLabel),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: SingleChildScrollView(child: formDocument),
    );
  }

  /// The merged page's sections, each preceded by its source form's
  /// banner so the page reads as the original forms in sequence.
  List<Widget> _buildFormSections() {
    final composite = widget.batch?.composite;
    final children = <Widget>[];
    for (var index = 0; index < widget.form.sections.length; index++) {
      final banner = composite?.sectionBanners[index];
      if (banner != null) {
        children.add(_buildFormBanner(banner));
        children.add(const SizedBox(height: AppSpacing.sm));
      }
      children.add(_buildSection(widget.form.sections[index]));
      children.add(const SizedBox(height: AppSpacing.lg));
    }
    return children;
  }

  Widget _buildFormBanner(String text) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            size: 18,
            color: colors.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentHeading() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        Text(
          widget.form.documentNo.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.form.title.toUpperCase(),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Divider(color: colors.outlineVariant, thickness: 1),
      ],
    );
  }

  Widget _buildClientField() {
    if (_clientsLoading) {
      return const LinearProgressIndicator();
    }
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth < AppDropdownDefaults.menuWidth
            ? constraints.maxWidth
            : AppDropdownDefaults.menuWidth,
        child: AppDropdownFormField<int>(
          initialValue: _clientId,
          isExpanded: true,
          menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
          decoration: InputDecoration(
            labelText: _isBatch
                ? 'Linked student'
                : 'Linked student (optional)',
            helperText: _isBatch
                ? 'Every form in this batch is saved against this student.'
                : 'Link this record to an existing student.',
            suffixIcon: _isBatch || _clientId == null
                ? null
                : IconButton(
                    tooltip: 'Remove student link',
                    onPressed: _saving
                        ? null
                        : () => setState(() => _clientId = null),
                    icon: const Icon(Icons.clear),
                  ),
          ),
          items: _clients
              .map(
                (client) => DropdownMenuItem(
                  value: client.id,
                  child: Text(
                    client.isArchived
                        ? '${client.fullName} (archived)'
                        : client.fullName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _saving || _isBatch ? null : _linkClient,
        ),
      ),
    );
  }

  Widget _buildSection(FormSection section) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          color: AppColors.navy,
          child: Text(
            section.title.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: .35,
            ),
          ),
        ),
        if (section.information != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            section.information!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final fieldWidth = constraints.maxWidth < 620
                ? constraints.maxWidth
                : (constraints.maxWidth - AppSpacing.md) / 2;
            final widgets = <Widget>[];
            final handledNameGroups = <String>{};
            for (final question in section.questions) {
              final group = question.nameGroup;
              if (group != null) {
                if (handledNameGroups.add(group)) {
                  final groupQuestions = section.questions
                      .where((item) => item.nameGroup == group)
                      .toList();
                  widgets.add(
                    SizedBox(
                      width: constraints.maxWidth,
                      child: _buildNameGroup(group, groupQuestions),
                    ),
                  );
                }
                continue;
              }

              final isFullWidth =
                  question.type == FormInputType.multiline ||
                  question.type == FormInputType.choices ||
                  question.type == FormInputType.checkbox ||
                  question.type == FormInputType.repeatable;
              widgets.add(
                SizedBox(
                  width: isFullWidth ? constraints.maxWidth : fieldWidth,
                  child: _buildQuestion(question),
                ),
              );
            }
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: widgets,
            );
          },
        ),
      ],
    );
  }

  Widget _buildNameGroup(String group, List<FormQuestion> questions) {
    final title = group
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final spacing = AppSpacing.sm;
            final widths = constraints.maxWidth < 620
                ? List<double>.filled(questions.length, constraints.maxWidth)
                : List<double>.filled(
                    questions.length,
                    (constraints.maxWidth - spacing * (questions.length - 1)) /
                        questions.length,
                  );
            return Wrap(
              spacing: spacing,
              runSpacing: AppSpacing.sm,
              children: [
                for (var index = 0; index < questions.length; index++)
                  SizedBox(
                    width: widths[index],
                    child: _buildNamePart(questions[index]),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildNamePart(FormQuestion question) {
    final label = switch (question.namePart) {
      FormNamePart.first => 'First name',
      FormNamePart.middle => 'Middle name (optional)',
      FormNamePart.last => 'Last name',
      FormNamePart.suffix => 'Suffix (optional)',
      null => question.label,
    };
    return AppField(
      label: label,
      labelHeight: _fieldLabelHeight,
      child: TextField(
        key: ValueKey(question.id),
        controller: _textControllers[question.id],
        enabled: !_saving,
        decoration: InputDecoration(hintText: 'Enter ${label.toLowerCase()}'),
      ),
    );
  }

  Widget _buildQuestion(FormQuestion question) {
    switch (question.type) {
      case FormInputType.text:
      case FormInputType.multiline:
        final isMultiline = question.type == FormInputType.multiline;
        return AppField(
          label: question.label,
          labelHeight: _fieldLabelHeight,
          child: TextField(
            controller: _textControllers[question.id],
            enabled: !_saving,
            minLines: isMultiline ? 3 : 1,
            maxLines: isMultiline ? 6 : 1,
            decoration: InputDecoration(
              hintText:
                  question.hint ?? 'Enter ${question.label.toLowerCase()}',
            ),
          ),
        );
      case FormInputType.date:
        final date = _dates[question.id];
        return PickerField(
          label: question.label,
          labelHeight: _fieldLabelHeight,
          icon: Icons.calendar_today_outlined,
          displayValue: date == null ? 'Not set' : formatDate(date),
          height: 50,
          onTap: _saving ? () {} : () => _pickDate(question),
          onClear: date == null || _saving
              ? null
              : () => setState(() => _dates[question.id] = null),
          enabled: !_saving,
        );
      case FormInputType.choice:
        if (_isGenderQuestion(question.label, question.id)) {
          return AppField(
            label: question.label,
            labelHeight: _fieldLabelHeight,
            child: Wrap(
              spacing: AppSpacing.md,
              children: [
                for (final option in question.options)
                  InkWell(
                    onTap: _saving
                        ? null
                        : () => setState(() => _choices[question.id] = option),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          key: ValueKey('${question.id}_$option'),
                          value: _choices[question.id] == option,
                          onChanged: _saving
                              ? null
                              : (selected) => setState(
                                  () => _choices[question.id] = selected == true
                                      ? option
                                      : null,
                                ),
                        ),
                        Text(option),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }
        return AppDropdownFormField<String>(
          initialValue: _choices[question.id],
          isExpanded: true,
          menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
          labelHeight: _fieldLabelHeight,
          decoration: InputDecoration(labelText: question.label),
          items: question.options
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(option, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (value) => setState(() => _choices[question.id] = value),
        );
      case FormInputType.choices:
        return AppField(
          label: question.label,
          labelHeight: _fieldLabelHeight,
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final option in question.options)
                  FilterChip(
                    label: Text(option),
                    selected: _multipleChoices[question.id]!.contains(option),
                    onSelected: _saving
                        ? null
                        : (selected) => setState(() {
                            final values = _multipleChoices[question.id]!;
                            if (selected) {
                              values.add(option);
                            } else {
                              values.remove(option);
                            }
                          }),
                  ),
              ],
            ),
          ),
        );
      case FormInputType.checkbox:
        return InkWell(
          onTap: _saving
              ? null
              : () => setState(
                  () => _checks[question.id] = !(_checks[question.id] ?? false),
                ),
          child: Row(
            children: [
              Checkbox(
                value: _checks[question.id] ?? false,
                onChanged: _saving
                    ? null
                    : (value) =>
                          setState(() => _checks[question.id] = value ?? false),
              ),
              Expanded(child: Text(question.label)),
            ],
          ),
        );
      case FormInputType.repeatable:
        return _buildRepeatableQuestion(question);
    }
  }

  Widget _buildRepeatableQuestion(FormQuestion question) {
    final entries = _repeatableEntries[question.id]!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(question.label, style: theme.textTheme.titleSmall),
            ),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _addRepeatableEntry(question),
              icon: const Icon(Icons.add),
              label: Text('Add ${question.entryLabel}'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var index = 0; index < entries.length; index++) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${question.entryLabel[0].toUpperCase()}'
                        '${question.entryLabel.substring(1)} ${index + 1}',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    if (entries.length > 1)
                      IconButton(
                        onPressed: _saving
                            ? null
                            : () => _removeRepeatableEntry(question, index),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove entry',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fieldWidth = constraints.maxWidth < 620
                        ? constraints.maxWidth
                        : (constraints.maxWidth - AppSpacing.md) / 2;
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        for (final field in question.entryFields)
                          SizedBox(
                            width: fieldWidth,
                            child: _buildRepeatableField(
                              question,
                              field,
                              entries[index][field.id]!,
                              index,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (index < entries.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildRepeatableField(
    FormQuestion question,
    FormEntryField field,
    TextEditingController controller,
    int index,
  ) {
    if (field.type == FormInputType.date) {
      final date = _parseDate(controller.text);
      return PickerField(
        key: ValueKey('${question.id}_${index}_${field.id}'),
        label: field.label,
        labelHeight: _fieldLabelHeight,
        icon: Icons.calendar_today_outlined,
        displayValue: date == null ? 'Not set' : formatDate(date),
        height: 50,
        onTap: _saving
            ? () {}
            : () => _pickRepeatableDate(question, index, field),
        onClear: date == null || _saving
            ? null
            : () => setState(() => controller.clear()),
        enabled: !_saving,
      );
    }

    if (field.type == FormInputType.choice) {
      return AppField(
        label: field.label,
        labelHeight: _fieldLabelHeight,
        child: Wrap(
          spacing: AppSpacing.md,
          children: [
            for (final option in field.options)
              InkWell(
                onTap: _saving
                    ? null
                    : () => setState(() => controller.text = option),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      key: ValueKey(
                        '${question.id}_${index}_${field.id}_$option',
                      ),
                      value: controller.text == option,
                      onChanged: _saving
                          ? null
                          : (selected) => setState(
                              () => controller.text = selected == true
                                  ? option
                                  : '',
                            ),
                    ),
                    Text(option),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return AppField(
      label: field.label,
      labelHeight: _fieldLabelHeight,
      child: TextField(
        key: ValueKey('${question.id}_${index}_${field.id}'),
        controller: controller,
        enabled: !_saving,
        decoration: InputDecoration(
          hintText: 'Enter ${field.label.toLowerCase()}',
        ),
      ),
    );
  }

  bool _isGenderQuestion(String label, String id) =>
      id == 'sex' || label.toLowerCase().contains('gender');
}
