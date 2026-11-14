import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_data_table.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/list_states.dart';
import 'package:counseling_is/core/widgets/status_chip.dart';
import 'package:counseling_is/features/cases/data/case_repository.dart';
import 'package:counseling_is/features/cases/domain/case_record.dart';
import 'package:counseling_is/features/cases/presentation/case_form_dialog.dart';
import 'package:counseling_is/features/cases/presentation/case_timeline_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  CaseStatus? _statusFilter;
  late Future<List<CaseRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isFiltered => _query.trim().isNotEmpty || _statusFilter != null;

  Future<List<CaseRecord>> _load() {
    final text = _query.trim();
    return context.read<CaseRepository>().list(
      CaseQuery(status: _statusFilter, searchText: text.isEmpty ? null : text),
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _open(CaseRecord record) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => CaseFormDialog(caseRecord: record),
    );
    if (saved == true) _refresh();
  }

  Future<void> _new() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const CaseFormDialog(),
    );
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Case Management',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track open cases, follow-ups and closures.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search case reference or student',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() {
                      _query = value;
                      _future = _load();
                    }),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 150,
                child: AppDropdownButton<CaseStatus?>(
                  value: _statusFilter,
                  isExpanded: true,
                  menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
                  hint: const Text('Any status'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any status'),
                    ),
                    for (final status in CaseStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _statusFilter = value;
                    _future = _load();
                  }),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: _new,
                icon: const Icon(Icons.add),
                label: const Text('New case'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<CaseRecord>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return LoadErrorState(onRetry: _refresh);
                }
                final cases = snapshot.data!;
                if (cases.isEmpty) {
                  return EmptyListState(
                    icon: Icons.folder_open_outlined,
                    title: _isFiltered ? 'No matching cases' : 'No cases yet',
                    message: _isFiltered
                        ? 'Try adjusting your search or status filter.'
                        : 'Open a case to track a student over time, with '
                              'follow-ups and closure notes.',
                    actionLabel: _isFiltered ? null : 'New case',
                    onAction: _isFiltered ? null : _new,
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: AppDataTable(
                    columns: const [
                      DataColumn(label: Text('Case reference')),
                      DataColumn(label: Text('Student')),
                      DataColumn(label: Text('Opened')),
                      DataColumn(label: Text('Follow-up')),
                      DataColumn(label: Text('Closed')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final record in cases)
                        DataRow(
                          key: ValueKey(record.id),
                          cells: [
                            DataCell(Text(record.caseRef)),
                            DataCell(
                              Text(
                                record.clientName ??
                                    'Student #${record.clientId}',
                              ),
                              onTap: () => _open(record),
                            ),
                            DataCell(Text(formatDate(record.openedAt))),
                            DataCell(
                              Text(
                                record.followUpDate == null
                                    ? '—'
                                    : formatDate(record.followUpDate!),
                              ),
                            ),
                            DataCell(
                              Text(
                                record.closedAt == null
                                    ? '—'
                                    : formatDate(record.closedAt!),
                              ),
                            ),
                            DataCell(
                              StatusChip(
                                label: record.status.label,
                                color: _statusColor(record.status),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => showDialog<void>(
                                      context: context,
                                      builder: (_) => CaseTimelineDialog(
                                        caseRecord: record,
                                      ),
                                    ),
                                    style: _caseActionButtonStyle,
                                    icon: const Icon(
                                      Icons.show_chart,
                                      size: 20,
                                    ),
                                    tooltip: 'Case history',
                                  ),
                                  IconButton(
                                    onPressed: () => showDialog<void>(
                                      context: context,
                                      builder: (_) => CaseTimelineDialog(
                                        caseRecord: record,
                                        showDisciplinaryOnly: true,
                                      ),
                                    ),
                                    style: _caseActionButtonStyle,
                                    icon: const Icon(Icons.gavel, size: 20),
                                    tooltip: 'Disciplinary timeline',
                                  ),
                                  IconButton(
                                    onPressed: () => _open(record),
                                    style: _caseActionButtonStyle,
                                    icon: const Icon(Icons.edit, size: 20),
                                    tooltip: 'Edit case',
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
          ),
        ],
      ),
    );
  }
}

final ButtonStyle _caseActionButtonStyle = IconButton.styleFrom(
  foregroundColor: AppColors.navy,
  visualDensity: VisualDensity.compact,
  minimumSize: const Size(36, 36),
  padding: const EdgeInsets.all(6),
);

Color _statusColor(CaseStatus status) {
  return switch (status) {
    CaseStatus.open => const Color(0xFF1565C0),
    CaseStatus.inProgress => const Color(0xFF6A1B9A),
    CaseStatus.closed => const Color(0xFF2E7D32),
  };
}
