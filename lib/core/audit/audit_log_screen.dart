import 'package:counseling_is/core/audit/audit_log_repository.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_data_table.dart';
import 'package:counseling_is/core/widgets/list_states.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  late Future<List<AuditLogEntry>> _future;
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

  Future<List<AuditLogEntry>> _load() =>
      context.read<AuditLogRepository>().list(searchText: _query);

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

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Audit Log', style: textStyle.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Recent account and record changes. Confidential form contents '
            'and counseling notes are not shown here.',
            style: textStyle.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search activity or account',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {
                    _query = value;
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
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<AuditLogEntry>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return LoadErrorState(onRetry: _refresh);
                }
                final entries = snapshot.data!;
                if (entries.isEmpty) {
                  return EmptyListState(
                    icon: Icons.fact_check_outlined,
                    title: _query.isEmpty
                        ? 'No activity recorded yet'
                        : 'No matching activity',
                    message: _query.isEmpty
                        ? 'Account and record changes will appear here.'
                        : 'Try a different search term.',
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: AppDataTable(
                    columns: const [
                      DataColumn(label: Text('When')),
                      DataColumn(label: Text('Account')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('Record')),
                      DataColumn(label: Text('Detail')),
                    ],
                    rows: [
                      for (final entry in entries)
                        DataRow(
                          key: ValueKey(entry.id),
                          cells: [
                            DataCell(Text(formatDateTime(entry.createdAt))),
                            DataCell(
                              Text(entry.adminName ?? 'Inactive account'),
                            ),
                            DataCell(Text(_humanize(entry.action))),
                            DataCell(
                              Text(
                                entry.entityId == null
                                    ? _humanize(entry.entityType)
                                    : '${_humanize(entry.entityType)} '
                                          '#${entry.entityId}',
                              ),
                            ),
                            DataCell(Text(entry.detail ?? '—')),
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

String _humanize(String value) => value
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
