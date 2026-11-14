import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/list_states.dart';
import 'package:counseling_is/features/appointments/data/appointment_repository.dart';
import 'package:counseling_is/features/appointments/domain/appointment.dart';
import 'package:counseling_is/features/appointments/presentation/appointment_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GuidanceCalendarScreen extends StatefulWidget {
  const GuidanceCalendarScreen({super.key});

  @override
  State<GuidanceCalendarScreen> createState() => _GuidanceCalendarScreenState();
}

class _GuidanceCalendarScreenState extends State<GuidanceCalendarScreen> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late DateTime _month;
  late DateTime _selectedDate;
  late Future<List<Appointment>> _future;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _month = DateTime(today.year, today.month);
    _selectedDate = today;
    _future = _load();
  }

  Future<List<Appointment>> _load() async {
    final appointmentRepository = context.read<AppointmentRepository>();
    return appointmentRepository.list(
      const AppointmentQuery(timeFilter: AppointmentTimeFilter.all),
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      if (_selectedDate.year != _month.year ||
          _selectedDate.month != _month.month) {
        _selectedDate = DateTime(_month.year, _month.month, 1);
      }
    });
  }

  Future<void> _newAppointment() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const AppointmentFormDialog(),
    );
    if (saved == true) _refresh();
  }

  Future<void> _openAppointment(Appointment appointment) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AppointmentFormDialog(appointment: appointment),
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
                      'Guidance Calendar',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View and manage scheduled guidance appointments.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: _newAppointment,
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
                return _buildCalendar(snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(List<Appointment> appointments) {
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final gridStart = firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday - 1),
    );
    final today = _dateOnly(DateTime.now());
    final dayAppointments = appointments.where(
      (appointment) => _sameDay(appointment.startsAt, _selectedDate),
    );
    final selectedEvents = <_CalendarEvent>[
      for (final appointment in dayAppointments)
        _CalendarEvent(
          date: appointment.startsAt,
          title: appointment.clientName ?? 'Student #${appointment.clientId}',
          detail:
              '${formatTime(appointment.startsAt)} · '
              '${appointment.purpose ?? 'Guidance appointment'} · '
              '${appointment.status.label}',
          appointment: appointment,
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_months[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: () => _changeMonth(1),
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: () {
                final now = _dateOnly(DateTime.now());
                setState(() {
                  _month = DateTime(now.year, now.month);
                  _selectedDate = now;
                });
              },
              child: const Text('Today'),
            ),
          ],
        ),
        Row(
          children: [
            for (final weekday in _weekdays)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      weekday,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          flex: 7,
          child: LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 42,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: constraints.maxHeight / 6,
              ),
              itemBuilder: (context, index) {
                final date = gridStart.add(Duration(days: index));
                final inMonth = date.month == _month.month;
                final selected = _sameDay(date, _selectedDate);
                final hasAppointment = appointments.any(
                  (entry) => _sameDay(entry.startsAt, date),
                );
                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: Material(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: _sameDay(date, today)
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _selectedDate = date),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            key: ValueKey(
                              'calendar-date-${date.year}-'
                              '${date.month}-${date.day}',
                            ),
                            style: TextStyle(
                              color: inMonth
                                  ? null
                                  : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              fontWeight: selected ? FontWeight.bold : null,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasAppointment)
                                _CalendarDot(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Events · ${formatDate(_selectedDate)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: selectedEvents.isEmpty
              ? const Center(
                  child: Text(
                    'Nothing scheduled for this day.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: selectedEvents.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final event = selectedEvents[index];
                    return ListTile(
                      leading: const Icon(Icons.event_note_outlined),
                      title: Text(event.title),
                      subtitle: Text(event.detail),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openAppointment(event.appointment),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CalendarEvent {
  const _CalendarEvent({
    required this.date,
    required this.title,
    required this.detail,
    required this.appointment,
  });

  final DateTime date;
  final String title;
  final String detail;
  final Appointment appointment;
}

class _CalendarDot extends StatelessWidget {
  const _CalendarDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
