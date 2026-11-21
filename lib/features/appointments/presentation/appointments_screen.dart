import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_data_table.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/list_states.dart';
import 'package:counseling_is/core/widgets/status_chip.dart';
import 'package:counseling_is/features/appointments/data/appointment_repository.dart';
import 'package:counseling_is/features/appointments/domain/appointment.dart';
import 'package:counseling_is/features/appointments/presentation/appointment_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  AppointmentTimeFilter _timeFilter = AppointmentTimeFilter.upcoming;
  AppointmentStatus? _statusFilter;
  late Future<List<Appointment>> _future;
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

  bool get _isFiltered =>
      _query.trim().isNotEmpty ||
      _statusFilter != null ||
      _timeFilter != AppointmentTimeFilter.upcoming;

  Future<List<Appointment>> _load() {
    final text = _query.trim();
    return context.read<AppointmentRepository>().list(
      AppointmentQuery(
        timeFilter: _timeFilter,
        status: _statusFilter,
        searchText: text.isEmpty ? null : text,
      ),
    );
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

  Future<void> _edit(Appointment appointment) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AppointmentFormDialog(appointment: appointment),
    );
    if (saved == true) _refresh();
  }

  Future<void> _new() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const AppointmentFormDialog(),
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
                      'Appointments',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Schedule, reschedule and track appointments.',
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
                      hintText: 'Search student or purpose',
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
                width: 130,
                child: AppDropdownButton<AppointmentTimeFilter>(
                  value: _timeFilter,
                  isExpanded: true,
                  menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
                  items: const [
                    DropdownMenuItem(
                      value: AppointmentTimeFilter.upcoming,
                      child: Text('Upcoming'),
                    ),
                    DropdownMenuItem(
                      value: AppointmentTimeFilter.today,
                      child: Text('Today'),
                    ),
                    DropdownMenuItem(
                      value: AppointmentTimeFilter.past,
                      child: Text('Past'),
                    ),
                    DropdownMenuItem(
                      value: AppointmentTimeFilter.all,
                      child: Text('All time'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _timeFilter = value ?? AppointmentTimeFilter.upcoming;
                    _future = _load();
                  }),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 140,
                child: AppDropdownButton<AppointmentStatus?>(
                  value: _statusFilter,
                  isExpanded: true,
                  menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
                  hint: const Text('Any status'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any status'),
                    ),
                    for (final status in AppointmentStatus.values)
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
                label: const Text('New appointment'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<Appointment>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return LoadErrorState(onRetry: _refresh);
                }
                final appointments = snapshot.data!;
                if (appointments.isEmpty) {
                  return EmptyListState(
                    icon: Icons.event_note_outlined,
                    title: _emptyTitle(),
                    message: _emptyMessage(),
                    actionLabel: _isFiltered ? null : 'New appointment',
                    onAction: _isFiltered ? null : _new,
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: AppDataTable(
                    columns: const [
                      DataColumn(label: Text('Date and time')),
                      DataColumn(label: Text('Student')),
                      DataColumn(label: Text('Purpose')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final appointment in appointments)
                        DataRow(
                          key: ValueKey(appointment.id),
                          cells: [
                            DataCell(
                              Text(
                                '${formatDateTime(appointment.startsAt)} – '
                                '${formatTime(appointment.endsAt)}',
                              ),
                            ),
                            DataCell(
                              Text(
                                appointment.clientName ??
                                    'Student #${appointment.clientId}',
                              ),
                              onTap: () => _edit(appointment),
                            ),
                            DataCell(Text(appointment.purpose ?? '—')),
                            DataCell(
                              StatusChip(
                                label: appointment.status.label,
                                color: _statusColor(appointment.status),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                onPressed: () => _edit(appointment),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit appointment',
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

  String _emptyTitle() {
    if (_isFiltered) return 'No matching appointments';
    return switch (_timeFilter) {
      AppointmentTimeFilter.upcoming => 'No upcoming appointments',
      AppointmentTimeFilter.today => 'No appointments today',
      AppointmentTimeFilter.past => 'No past appointments',
      AppointmentTimeFilter.all => 'No appointments yet',
    };
  }

  String _emptyMessage() {
    if (_isFiltered) {
      return 'Try adjusting your search, time range or status filter.';
    }
    return 'Create an appointment to reserve a time slot for a student.';
  }
}

Color _statusColor(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.scheduled => const Color(0xFF1565C0),
    AppointmentStatus.completed => const Color(0xFF2E7D32),
    AppointmentStatus.missed => const Color(0xFFE65100),
    AppointmentStatus.cancelled => const Color(0xFF616161),
  };
}
