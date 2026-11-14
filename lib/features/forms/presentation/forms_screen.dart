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
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/forms/data/form_pdf_exporter.dart';
import 'package:counseling_is/features/forms/data/form_submission_repository.dart';
import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:counseling_is/features/forms/domain/form_submission.dart';
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

  void _toggleSubmissionSelection(int? submissionId, bool? selected) {
    if (submissionId == null) return;
    setState(() {
      if (selected == true) {
        _selectedSubmissionIds.add(submissionId);
      } else {
        _selectedSubmissionIds.remove(submissionId);
      }
      _batchError = null;
    });
  }

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

    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete selected forms?',
      message:
          'This will permanently delete ${selected.length} selected '
          'form${selected.length == 1 ? '' : 's'}.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<FormSubmissionRepository>().deleteMany(
        selected.map((submission) => submission.id!),
      );
      if (!mounted) return;
      setState(() {
        _selectedSubmissionIds.clear();
        _batchError = null;
        _future = _load();
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _batchError = error.message);
      _refresh();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _batchError = 'The selected form records could not be deleted.',
      );
      _refresh();
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

  Future<void> _deleteSubmission(FormSubmission submission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete saved form?'),
        content: const Text('This form record will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<FormSubmissionRepository>().delete(submission.id!);
      _refresh();
    } on AppException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('The form record could not be deleted.');
    }
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
                      columns: const [
                        DataColumn(label: Text('Form')),
                        DataColumn(label: Text('Form number')),
                        DataColumn(label: Text('Linked student')),
                        DataColumn(label: Text('Last saved')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final submission in submissions)
                          DataRow(
                            key: ValueKey(submission.id),
                            selected: _selectedSubmissionIds.contains(
                              submission.id,
                            ),
                            onSelectChanged: (selected) =>
                                _toggleSubmissionSelection(
                                  submission.id,
                                  selected,
                                ),
                            cells: [
                              DataCell(
                                Text(
                                  counselingFormById(submission.formId)
                                          ?.title ??
                                      submission.formId,
                                ),
                                onTap:
                                    counselingFormById(submission.formId) ==
                                        null
                                    ? null
                                    : () => _editSubmission(submission),
                              ),
                              DataCell(
                                Text(
                                  counselingFormById(submission.formId)
                                          ?.documentNo ??
                                      'Form',
                                ),
                              ),
                              DataCell(
                                Text(
                                  submission.clientName ?? 'No linked student',
                                ),
                              ),
                              DataCell(
                                Text(formatDateTime(submission.updatedAt)),
                              ),
                              DataCell(
                                IconButton(
                                  tooltip: 'Delete form',
                                  icon: const Icon(Icons.delete_outline),
                                  style: IconButton.styleFrom(
                                    foregroundColor: colors.error,
                                  ),
                                  onPressed: () =>
                                      _deleteSubmission(submission),
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

class CounselingFormPage extends StatefulWidget {
  const CounselingFormPage({
    super.key,
    required this.form,
    this.submission,
    this.clientsFuture,
    this.embedded = false,
    this.onSaved,
  });

  final CounselingForm form;
  final FormSubmission? submission;
  final Future<List<Client>>? clientsFuture;
  final bool embedded;
  final VoidCallback? onSaved;

  @override
  State<CounselingFormPage> createState() => _CounselingFormPageState();
}

class _CounselingFormPageState extends State<CounselingFormPage> {
  static const _fieldLabelHeight = 40.0;

  final _pdfExporter = FormPdfExporter();
  final _textControllers = <String, TextEditingController>{};
  final _dates = <String, DateTime?>{};
  final _choices = <String, String?>{};
  final _multipleChoices = <String, Set<String>>{};
  final _repeatableEntries =
      <String, List<Map<String, TextEditingController>>>{};
  final _checks = <String, bool>{};
  List<Client> _clients = [];
  int? _clientId;
  bool _clientsLoading = true;
  bool _saving = false;
  bool _exporting = false;
  String? _error;

  bool get _isEdit => widget.submission != null;

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
    _clientId = submission?.clientId;
    for (final section in widget.form.sections) {
      for (final question in section.questions) {
        var value = submission?.data[question.id];
        final nameGroup = question.nameGroup;
        if (value == null &&
            nameGroup != null &&
            submission?.data[nameGroup] is String) {
          value = _legacyNameParts(
            submission!.data[nameGroup] as String,
          )[question.namePart]!;
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
    }
    _loadClients();
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
          _applyClientToBlankFields(linkedClient);
        }
        setState(() {
          _clients = clients;
          _clientsLoading = false;
        });
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
      if (client != null) _applyClientToBlankFields(client);
    });
  }

  void _applyClientToBlankFields(Client client) {
    const identityNameGroups = {'student_name', 'learner_name', 'client_name'};
    final nameParts = _legacyNameParts(client.fullName);

    for (final section in widget.form.sections) {
      for (final question in section.questions) {
        final controller = _textControllers[question.id];
        if (controller != null && controller.text.trim().isEmpty) {
          if (question.nameGroup != null &&
              identityNameGroups.contains(question.nameGroup)) {
            controller.text = nameParts[question.namePart] ?? '';
          } else if (question.id == 'contact_number' &&
              client.phone?.trim().isNotEmpty == true) {
            controller.text = client.phone!;
          } else if (question.id == 'age' && client.dateOfBirth != null) {
            controller.text = _clientAge(client.dateOfBirth!).toString();
          }
        }

        if (question.type == FormInputType.date &&
            question.id == 'date_of_birth' &&
            _dates[question.id] == null) {
          _dates[question.id] = client.dateOfBirth;
        }
      }
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

  Future<void> _exportForPrinting() async {
    if (_exporting || _clientsLoading) return;
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF document', extensions: ['pdf']),
      ],
      suggestedName:
          '${widget.form.id}-${DateTime.now().toIso8601String().split('T').first}.pdf',
    );
    if (location == null || !mounted) return;
    setState(() {
      _exporting = true;
      _error = null;
    });

    try {
      final result = await _pdfExporter.export(
        form: widget.form,
        data: _collectData(),
      );
      await File(location.path).writeAsBytes(result.bytes, flush: true);

      var printMessage = 'The PDF was saved and is ready to print.';
      Object? printError;
      try {
        final printed = await Printing.layoutPdf(
          name: '${widget.form.title}.pdf',
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
                  _buildDocumentHeading(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildClientField(),
                  const SizedBox(height: AppSpacing.lg),
                  for (final section in widget.form.sections) ...[
                    _buildSection(section),
                    const SizedBox(height: AppSpacing.lg),
                  ],
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
                IconButton(
                  onPressed: _saving || _exporting ? null : _exportForPrinting,
                  icon: _exporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined),
                  tooltip: 'Preview and print PDF',
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
                  label: Text(_isEdit ? 'Save changes' : 'Save form'),
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
          IconButton(
            onPressed: _saving || _exporting ? null : _exportForPrinting,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            tooltip: 'Preview and print PDF',
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
              label: Text(_isEdit ? 'Save changes' : 'Save form'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: SingleChildScrollView(child: formDocument),
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
            labelText: 'Linked student (optional)',
            helperText: 'Link this record to an existing student.',
            suffixIcon: _clientId == null
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
          onChanged: _saving ? null : _linkClient,
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
