import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_data_table.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/confirm_dialog.dart';
import 'package:counseling_is/core/widgets/list_states.dart';
import 'package:counseling_is/core/widgets/status_chip.dart';
import 'package:counseling_is/features/interventions/data/intervention_repository.dart';
import 'package:counseling_is/features/interventions/domain/intervention.dart';
import 'package:counseling_is/features/interventions/presentation/intervention_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InterventionsScreen extends StatefulWidget {
  const InterventionsScreen({super.key});

  @override
  State<InterventionsScreen> createState() => _InterventionsScreenState();
}

class _InterventionsScreenState extends State<InterventionsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  InterventionStatus? _status;
  late Future<List<Intervention>> _future;
  int? _sortColumnIndex;
  bool _sortAscending = true;

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

  Future<List<Intervention>> _load() => context
      .read<InterventionRepository>()
      .list(InterventionQuery(searchText: _query, status: _status));

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

  Future<void> _edit([Intervention? intervention]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => InterventionFormDialog(intervention: intervention),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(Intervention intervention) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete intervention?',
      message: 'This will permanently delete this intervention record.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<InterventionRepository>().delete(intervention.id!);
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The intervention could not be deleted.'),
          ),
        );
      }
      return;
    }
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Intervention Management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Plan learner support, track progress and record outcomes.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search title, type or student',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {
                    _query = value;
                    _future = _load();
                  }),
                ),
              ),
              SizedBox(
                width: 160,
                child: AppDropdownButton<InterventionStatus?>(
                  value: _status,
                  isExpanded: true,
                  hint: const Text('Any status'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any status'),
                    ),
                    for (final status in InterventionStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _status = value;
                    _future = _load();
                  }),
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('New intervention'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<Intervention>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return LoadErrorState(onRetry: _refresh);
                }
                final records = snapshot.data!;
                if (records.isEmpty) {
                  return EmptyListState(
                    icon: Icons.volunteer_activism_outlined,
                    title: _query.isEmpty
                        ? 'No interventions yet'
                        : 'No matching interventions',
                    message: _query.isEmpty
                        ? 'Create a support plan and track its progress.'
                        : 'Try a different search or status filter.',
                    actionLabel: _query.isEmpty ? 'New intervention' : null,
                    onAction: _query.isEmpty ? () => _edit() : null,
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: AppDataTable(
                    columns: const [
                      DataColumn(label: Text('Intervention')),
                      DataColumn(label: Text('Learner')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Start')),
                      DataColumn(label: Text('Target')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final record in records)
                        DataRow(
                          key: ValueKey(record.id),
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 190,
                                child: Text(
                                  record.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              onTap: () => _edit(record),
                            ),
                            DataCell(
                              Text(
                                record.participantLabel ??
                                    record.clientName ??
                                    '—',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DataCell(
                              Text(
                                record.customType == null
                                    ? record.type
                                    : '${record.type}: ${record.customType}',
                              ),
                            ),
                            DataCell(Text(formatDate(record.startDate))),
                            DataCell(
                              Text(
                                record.targetDate == null
                                    ? '—'
                                    : formatDate(record.targetDate!),
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
                                    onPressed: () => _edit(record),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit intervention',
                                  ),
                                  IconButton(
                                    onPressed: () => _delete(record),
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete intervention',
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

Color _statusColor(InterventionStatus status) => switch (status) {
  InterventionStatus.planned => const Color(0xFF1565C0),
  InterventionStatus.inProgress => const Color(0xFF6A1B9A),
  InterventionStatus.completed => const Color(0xFF2E7D32),
  InterventionStatus.cancelled => const Color(0xFF616161),
};
