import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/widgets/app_data_table.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/confirm_dialog.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/core/widgets/list_states.dart';
import 'package:counseling_is/core/widgets/status_chip.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/clients/presentation/client_detail_dialog.dart';
import 'package:counseling_is/features/clients/presentation/client_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  ClientStatus? _statusFilter;
  final Set<int> _selectedClientIds = {};
  String? _batchError;
  late Future<List<Client>> _future;

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

  bool get _isFiltered => _query.isNotEmpty || _statusFilter != null;

  Future<List<Client>> _load() {
    final text = _query.trim();
    return context.read<ClientRepository>().search(
      ClientQuery(
        searchText: text.isEmpty ? null : text,
        status: _statusFilter,
      ),
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _newClient() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const ClientFormDialog(),
    );
    if (saved == true) _refresh();
  }

  Future<void> _editClient(Client client) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ClientFormDialog(client: client),
    );
    if (saved == true) _refresh();
  }

  Future<void> _openDetail(Client client) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ClientDetailDialog(client: client),
    );
    if (changed == true) _refresh();
  }

  void _toggleClientSelection(int? clientId, bool? selected) {
    if (clientId == null) return;
    setState(() {
      if (selected == true) {
        _selectedClientIds.add(clientId);
      } else {
        _selectedClientIds.remove(clientId);
      }
      _batchError = null;
    });
  }

  Future<void> _setSelectedStatus(
    List<Client> selectedClients,
    ClientStatus status,
  ) async {
    final clientsToUpdate = selectedClients
        .where((client) => client.id != null && client.status != status)
        .toList();
    if (clientsToUpdate.isEmpty) return;

    final action = status == ClientStatus.archived ? 'archive' : 'restore';
    final actionLabel = action[0].toUpperCase() + action.substring(1);
    final confirmed = await showConfirmDialog(
      context,
      title: '$actionLabel selected students?',
      message:
          'This will $action ${clientsToUpdate.length} selected '
          'student${clientsToUpdate.length == 1 ? '' : 's'}.',
      confirmLabel: actionLabel,
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<ClientRepository>().setStatusForMany(
        clientsToUpdate.map((client) => client.id!),
        status,
      );
      if (!mounted) return;
      setState(() {
        _selectedClientIds.clear();
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
        () => _batchError = 'The selected students could not be updated.',
      );
      _refresh();
    }
  }

  Future<void> _deleteSelectedClients(List<Client> selectedClients) async {
    final clientsToDelete = selectedClients
        .where((client) => client.id != null)
        .toList();
    if (clientsToDelete.isEmpty) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete selected students?',
      message:
          'This will permanently delete ${clientsToDelete.length} '
          'selected student${clientsToDelete.length == 1 ? '' : 's'}. '
            'Students with linked records cannot be deleted; archive them '
            'instead.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<ClientRepository>().deleteMany(
        clientsToDelete.map((client) => client.id!),
      );
      if (!mounted) return;
      setState(() {
        _selectedClientIds.clear();
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
        () => _batchError = 'The selected students could not be deleted.',
      );
      _refresh();
    }
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
                      'Students',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search, view and manage student records.',
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
                      hintText: 'Search name, reference, phone, email',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() {
                      _query = value;
                      _selectedClientIds.clear();
                      _batchError = null;
                      _future = _load();
                    }),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 150,
                child: AppDropdownButton<ClientStatus?>(
                  value: _statusFilter,
                  isExpanded: true,
                  menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
                  hint: const Text('All statuses'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All statuses')),
                    DropdownMenuItem(
                      value: ClientStatus.active,
                      child: Text('Active'),
                    ),
                    DropdownMenuItem(
                      value: ClientStatus.archived,
                      child: Text('Archived'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _statusFilter = value;
                    _selectedClientIds.clear();
                    _batchError = null;
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
                onPressed: _newClient,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('New student'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_batchError != null) ...[
            ErrorBanner(message: _batchError!),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_selectedClientIds.isNotEmpty)
            FutureBuilder<List<Client>>(
              future: _future,
              builder: (context, snapshot) {
                final selectedClients = (snapshot.data ?? const <Client>[])
                    .where(
                      (client) =>
                          client.id != null &&
                          _selectedClientIds.contains(client.id),
                    )
                    .toList();
                final activeCount = selectedClients
                    .where((client) => !client.isArchived)
                    .length;
                final archivedCount = selectedClients
                    .where((client) => client.isArchived)
                    .length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Text('${_selectedClientIds.length} selected'),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _deleteSelectedClients(selectedClients),
                        icon: const Icon(Icons.delete_outline),
                        label: Text('Delete (${selectedClients.length})'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (activeCount > 0)
                        OutlinedButton.icon(
                          onPressed: () => _setSelectedStatus(
                            selectedClients,
                            ClientStatus.archived,
                          ),
                          icon: const Icon(Icons.archive_outlined),
                          label: Text('Archive ($activeCount)'),
                        ),
                      if (archivedCount > 0)
                        OutlinedButton.icon(
                          onPressed: () => _setSelectedStatus(
                            selectedClients,
                            ClientStatus.active,
                          ),
                          icon: const Icon(Icons.unarchive_outlined),
                          label: Text('Restore ($archivedCount)'),
                        ),
                      TextButton(
                        onPressed: () => setState(() {
                          _selectedClientIds.clear();
                          _batchError = null;
                        }),
                        child: const Text('Clear selection'),
                      ),
                    ],
                  ),
                );
              },
            ),
          Expanded(
            child: FutureBuilder<List<Client>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return LoadErrorState(onRetry: _refresh);
                }
                final clients = snapshot.data!;
                if (clients.isEmpty) {
                  return EmptyListState(
                    icon: Icons.people_outline,
                    title: _isFiltered
                        ? 'No matching students'
                        : 'No students yet',
                    message: _isFiltered
                        ? 'Try adjusting your search or status filter.'
                        : 'Register your first student to get started.',
                    actionLabel: _isFiltered ? null : 'New student',
                    onAction: _isFiltered ? null : _newClient,
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: AppDataTable(
                    showCheckboxColumn: true,
                    columns: const [
                      DataColumn(label: Text('Reference')),
                      DataColumn(label: Text('Student name')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final client in clients)
                        DataRow(
                          key: ValueKey(client.id),
                          selected: _selectedClientIds.contains(client.id),
                          onSelectChanged: (selected) =>
                              _toggleClientSelection(client.id, selected),
                          cells: [
                            DataCell(Text(client.referenceNo)),
                            DataCell(
                              Text(client.fullName),
                              onTap: () => _openDetail(client),
                            ),
                            DataCell(Text(client.phone ?? '—')),
                            DataCell(Text(client.email ?? '—')),
                            DataCell(
                              StatusChip(
                                label: client.isArchived
                                    ? 'Archived'
                                    : 'Active',
                                color: client.isArchived
                                    ? Theme.of(context).colorScheme.tertiary
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            DataCell(
                              IconButton(
                                onPressed: () => _editClient(client),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit student',
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
