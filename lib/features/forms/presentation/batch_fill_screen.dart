import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_data_table.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/confirm_dialog.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/core/widgets/list_states.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/forms/data/form_submission_repository.dart';
import 'package:counseling_is/features/forms/domain/composite_form.dart';
import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:counseling_is/features/forms/domain/form_submission.dart';
import 'package:counseling_is/features/forms/presentation/forms_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BatchFillScreen extends StatefulWidget {
  const BatchFillScreen({super.key});

  @override
  State<BatchFillScreen> createState() => _BatchFillScreenState();
}

enum _BatchView { setup, saved }

/// The confidential child-protection intake keeps its own workflow and is
/// not offered in the batch picker.
final _selectableForms = [
  for (final form in counselingFormCatalog)
    if (form.id != 'child_protection_intake') form,
];

class _BatchFillScreenState extends State<BatchFillScreen> {
  List<Client> _clients = [];
  bool _clientsLoading = true;
  Future<List<FormBatchSummary>> _batchesFuture = Future.value(const []);
  final _selectedFormIds = <String>{};
  var _existing = <String, FormSubmission>{};
  var _existingLoading = false;
  var _existingFailed = false;
  int? _clientId;
  String? _clientName;
  _BatchView _view = _BatchView.setup;
  BatchFormSpec? _activeBatch;
  String? _notice;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _batchesFuture = _loadBatches();
  }

  Future<List<FormBatchSummary>> _loadBatches() =>
      context.read<FormSubmissionRepository>().listBatches();

  Future<void> _loadClients() async {
    try {
      final clients = await context.read<ClientRepository>().search(
        const ClientQuery(),
      );
      if (mounted) {
        setState(() {
          _clients = clients;
          _clientsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _clientsLoading = false);
    }
  }

  void _refreshBatches() {
    setState(() {
      _batchesFuture = _loadBatches();
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectStudent(int? clientId) {
    setState(() {
      _clientId = clientId;
      _clientName = _clients
          .where((client) => client.id == clientId)
          .firstOrNull
          ?.fullName;
      _existing = const {};
      _existingLoading = clientId != null;
      _existingFailed = false;
      _notice = null;
    });
    if (clientId == null) return;
    _loadExisting(clientId)
        .then((existing) {
          if (!mounted || _clientId != clientId) return;
          setState(() {
            _existing = existing;
            _existingLoading = false;
          });
        })
        .catchError((_) {
          if (!mounted || _clientId != clientId) return;
          setState(() {
            _existingLoading = false;
            _existingFailed = true;
          });
        });
  }

  /// Latest saved record per selectable form, so the picker can promise
  /// "will update" instead of creating duplicates.
  Future<Map<String, FormSubmission>> _loadExisting(int clientId) async {
    final repository = context.read<FormSubmissionRepository>();
    final existing = <String, FormSubmission>{};
    for (final form in _selectableForms) {
      final record = await repository.latestForClient(clientId, form.id);
      if (record != null) existing[form.id] = record;
    }
    return existing;
  }

  void _toggleForm(String formId, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedFormIds.add(formId);
      } else {
        _selectedFormIds.remove(formId);
      }
      _notice = null;
    });
  }

  void _openNewBatch() {
    final clientId = _clientId;
    if (clientId == null || _selectedFormIds.isEmpty) return;
    if (_existingLoading || _existingFailed) return;
    final composite = buildCompositeForm([
      for (final form in _selectableForms)
        if (_selectedFormIds.contains(form.id)) form,
    ]);
    setState(() {
      _view = _BatchView.setup;
      _notice = null;
      _activeBatch = BatchFormSpec(
        composite: composite,
        clientId: clientId,
        existingByForm: Map.of(_existing),
      );
    });
  }

  Future<void> _openSavedBatch(FormBatchSummary summary) async {
    try {
      final records = await context
          .read<FormSubmissionRepository>()
          .batchSubmissions(summary.batchId);
      if (!mounted) return;
      if (records.isEmpty) {
        _refreshBatches();
        _showMessage('That batch has no saved forms left.');
        return;
      }
      final byForm = {for (final record in records) record.formId: record};
      final sources = [
        for (final form in _selectableForms)
          if (byForm.containsKey(form.id)) form,
      ];
      if (sources.isEmpty) {
        _refreshBatches();
        _showMessage('That batch has no fillable forms left.');
        return;
      }
      setState(() {
        _view = _BatchView.saved;
        _clientId = summary.clientId;
        _clientName = summary.clientName;
        _selectedFormIds
          ..clear()
          ..addAll(byForm.keys);
        _notice = null;
        _activeBatch = BatchFormSpec(
          composite: buildCompositeForm(sources),
          clientId: summary.clientId,
          batchId: summary.batchId,
          existingByForm: byForm,
        );
      });
    } on AppException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('The batch could not be opened.');
    }
  }

  void _closeBatch() {
    setState(() {
      _activeBatch = null;
      _batchesFuture = _loadBatches();
    });
  }

  Future<void> _deleteBatch(FormBatchSummary summary) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete batch?',
      message:
          'The ${summary.formCount} saved form '
          'record${summary.formCount == 1 ? '' : 's'} stay in Saved forms '
          'and stay linked to the student — only the batch grouping is '
          'removed.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<FormSubmissionRepository>().unlinkBatch(
        summary.batchId,
      );
      if (mounted) _refreshBatches();
    } on AppException catch (error) {
      if (mounted) {
        _showMessage(error.message);
        _refreshBatches();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('The batch could not be deleted.');
        _refreshBatches();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activeBatch = _activeBatch;

    if (activeBatch != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMergedHeader(theme, colors, activeBatch),
              const SizedBox(height: AppSpacing.sm),
              CounselingFormPage(
                key: ValueKey(activeBatch),
                form: activeBatch.composite.form,
                batch: activeBatch,
                embedded: true,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, colors),
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
                child: SegmentedButton<_BatchView>(
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
                      value: _BatchView.setup,
                      label: Text('New batch'),
                      icon: Icon(Icons.playlist_add_outlined),
                    ),
                    ButtonSegment(
                      value: _BatchView.saved,
                      label: Text('Saved batches'),
                      icon: Icon(Icons.folder_open_outlined),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (selection) {
                    final view = selection.first;
                    setState(() {
                      _view = view;
                      _notice = null;
                    });
                    if (view == _BatchView.saved) _refreshBatches();
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_notice != null) ...[
              ErrorBanner(message: _notice!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_view == _BatchView.setup) _buildSetup(theme, colors),
            if (_view == _BatchView.saved) _buildSavedBatches(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: .84)],
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
            child: const Icon(Icons.layers_outlined, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batch fill forms',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Fill several forms for one student on a single page.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergedHeader(
    ThemeData theme,
    ColorScheme colors,
    BatchFormSpec spec,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Change selection',
            onPressed: _closeBatch,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batch for ${_clientName ?? 'selected student'}',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${spec.composite.sourceForms.length} form'
                  '${spec.composite.sourceForms.length == 1 ? '' : 's'} '
                  'merged in one page',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetup(ThemeData theme, ColorScheme colors) {
    final canOpen =
        _clientId != null &&
        _selectedFormIds.isNotEmpty &&
        !_existingLoading &&
        !_existingFailed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, color: colors.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Select student', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_clientsLoading)
                const LinearProgressIndicator()
              else
                AppDropdownFormField<int>(
                  initialValue: _clientId,
                  isExpanded: true,
                  menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
                  decoration: InputDecoration(
                    labelText: 'Student',
                    hintText: _clients.isEmpty
                        ? 'No students registered yet'
                        : 'Select a student',
                    helperText: _clients.isEmpty
                        ? 'Register a student first, then come back here.'
                        : 'The whole batch is saved against this student.',
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
                  onChanged: _selectStudent,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
          ),
          // The list tiles need their own Material so their ink effects are
          // not hidden by this container's background color.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Choose forms',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (_selectedFormIds.isNotEmpty)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            child: Text(
                              '${_selectedFormIds.length} selected',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (
                  var index = 0;
                  index < _selectableForms.length;
                  index++
                ) ...[
                  if (index > 0) const Divider(height: 1),
                  _buildFormTile(theme, colors, _selectableForms[index]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                _clientId == null
                    ? 'Select a student to continue.'
                    : _existingFailed
                    ? 'Could not check the saved forms for this student. '
                          'Try selecting them again.'
                    : _selectedFormIds.isEmpty
                    ? 'Choose at least one form.'
                    : '${_selectedFormIds.length} form'
                          '${_selectedFormIds.length == 1 ? '' : 's'} '
                          'will open in one page.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _existingFailed
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: canOpen ? _openNewBatch : null,
              icon: const Icon(Icons.layers_outlined),
              label: const Text('Open merged form'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormTile(
    ThemeData theme,
    ColorScheme colors,
    CounselingForm form,
  ) {
    final record = _clientId == null ? null : _existing[form.id];
    String? status;
    if (_clientId != null && !_existingLoading && !_existingFailed) {
      status = record == null
          ? 'No record yet for this student'
          : 'Will update the record saved ${formatDateTime(record.updatedAt)}';
    }
    return CheckboxListTile(
      value: _selectedFormIds.contains(form.id),
      onChanged: _clientId == null
          ? null
          : (value) => _toggleForm(form.id, value),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        '${form.documentNo} · ${form.title}',
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: status == null
          ? null
          : Text(
              status,
              style: theme.textTheme.bodySmall?.copyWith(
                color: record == null
                    ? colors.onSurfaceVariant
                    : colors.primary,
              ),
            ),
    );
  }

  Widget _buildSavedBatches(ThemeData theme) {
    return FutureBuilder<List<FormBatchSummary>>(
      future: _batchesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return LoadErrorState(onRetry: _refreshBatches);
        }
        final batches = snapshot.data ?? const <FormBatchSummary>[];
        if (batches.isEmpty) {
          return EmptyListState(
            icon: Icons.layers_outlined,
            title: 'No saved batches yet',
            message:
                'Open the New batch tab, pick a student and choose the '
                'forms to fill on one page.',
          );
        }
        return Card(
          clipBehavior: Clip.antiAlias,
          child: AppDataTable(
            columns: const [
              DataColumn(label: Text('Student')),
              DataColumn(label: Text('Forms')),
              DataColumn(label: Text('Last saved')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final batch in batches)
                DataRow(
                  key: ValueKey(batch.batchId),
                  cells: [
                    DataCell(Text(batch.clientName ?? 'Unknown student')),
                    DataCell(
                      Text(
                        '${batch.formCount} form'
                        '${batch.formCount == 1 ? '' : 's'}',
                      ),
                    ),
                    DataCell(Text(formatDateTime(batch.lastSavedAt))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Open batch',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openSavedBatch(batch),
                          ),
                          IconButton(
                            tooltip: 'Delete batch',
                            icon: const Icon(Icons.delete_outline),
                            style: IconButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                            ),
                            onPressed: () => _deleteBatch(batch),
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
    );
  }
}
