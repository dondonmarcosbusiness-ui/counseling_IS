import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_data_table.dart';
import 'package:counseling_is/core/widgets/list_states.dart';
import 'package:counseling_is/features/sessions/data/session_repository.dart';
import 'package:counseling_is/features/sessions/domain/session_record.dart';
import 'package:counseling_is/features/sessions/presentation/session_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Lists counseling sessions. Confidential notes are intentionally never
/// rendered here — only inside the session form dialog.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  late Future<List<SessionRecord>> _future;

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

  bool get _isFiltered => _query.trim().isNotEmpty;

  Future<List<SessionRecord>> _load() {
    final text = _query.trim();
    return context.read<SessionRepository>().list(
      SessionQuery(searchText: text.isEmpty ? null : text),
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _open(SessionRecord session) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => SessionFormDialog(session: session),
    );
    if (saved == true) _refresh();
  }

  Future<void> _new() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const SessionFormDialog(),
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
                      'Counseling Sessions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Record session outcomes and follow-up actions.',
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
                      hintText: 'Search student name',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() {
                      _query = value;
                      _future = _load();
                    }),
                  ),
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
                label: const Text('New session'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<SessionRecord>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return LoadErrorState(onRetry: _refresh);
                }
                final sessions = snapshot.data!;
                if (sessions.isEmpty) {
                  return EmptyListState(
                    icon: Icons.history_edu_outlined,
                    title: _isFiltered
                        ? 'No matching sessions'
                        : 'No sessions yet',
                    message: _isFiltered
                        ? 'Try adjusting your search.'
                        : 'After meeting a student, create a session to '
                              'record notes and follow-up actions.',
                    actionLabel: _isFiltered ? null : 'New session',
                    onAction: _isFiltered ? null : _new,
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: AppDataTable(
                    columns: const [
                      DataColumn(label: Text('Student')),
                      DataColumn(label: Text('Session date')),
                      DataColumn(label: Text('Next recommended date')),
                      DataColumn(label: Text('Notes')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final session in sessions)
                        DataRow(
                          key: ValueKey(session.id),
                          cells: [
                            DataCell(
                              Text(
                                session.clientName ??
                                    'Student #${session.clientId}',
                              ),
                              onTap: () => _open(session),
                            ),
                            DataCell(Text(formatDate(session.sessionDate))),
                            DataCell(
                              Text(
                                session.nextRecommendedDate == null
                                    ? '—'
                                    : formatDate(session.nextRecommendedDate!),
                              ),
                            ),
                            DataCell(
                              Tooltip(
                                message: 'Session notes are hidden in lists',
                                child: Icon(
                                  Icons.lock_outline,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                onPressed: () => _open(session),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'View and edit session',
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
