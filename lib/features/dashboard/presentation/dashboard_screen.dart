import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/features/appointments/domain/appointment.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:counseling_is/features/dashboard/data/stats_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardStats> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<StatsRepository>().fetch();
  }

  void _refresh() {
    setState(() {
      _future = context.read<StatsRepository>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardStats>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorView(onRetry: _refresh);
        }
        final stats = snapshot.data!;
        return _DashboardBody(stats: stats, onRefresh: _refresh);
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.stats, required this.onRefresh});

  final DashboardStats stats;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = '${_weekday(now)} · ${_monthDay(now)}';
    final adminName = context.watch<AuthController?>()?.admin?.fullName;

    return LayoutBuilder(
      builder: (context, _) {
        final metrics = [
          _DashboardMetric(
            label: 'Registered students',
            value: stats.activeClients,
            icon: Icons.people_alt_outlined,
            route: '/clients',
          ),
          _DashboardMetric(
            label: 'Active interventions',
            value: stats.activeInterventions,
            icon: Icons.volunteer_activism_outlined,
            route: '/interventions',
          ),
          _DashboardMetric(
            label: 'Awaiting counseling',
            value: stats.upcomingAppointments,
            icon: Icons.favorite_border,
            route: '/appointments',
          ),
          _DashboardMetric(
            label: 'Counseling sessions',
            value: stats.completedSessions,
            icon: Icons.history_edu_outlined,
            route: '/sessions',
          ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dashboard · $dateLabel',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _WelcomeBanner(adminName: adminName),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 700
                      ? 4
                      : constraints.maxWidth >= 500
                      ? 3
                      : 2;
                  final itemWidth =
                      (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                      columns;
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final metric in metrics)
                        SizedBox(
                          width: itemWidth,
                          child: _StatCard(metric: metric),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _GuidanceQueue(stats: stats, dateLabel: _monthDay(now)),
              const SizedBox(height: AppSpacing.md),
              _DashboardDetailCard(
                title: 'Upcoming sessions (${stats.upcomingAppointments})',
                icon: Icons.event_note_outlined,
                emptyMessage: 'No upcoming sessions.',
                onViewAll: () => context.go('/appointments'),
                children: [
                  for (final appointment in stats.upcomingAppointmentItems)
                    _AppointmentTile(appointment: appointment, showDate: true),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _DashboardDetailCard(
                title: 'Pending sessions (${stats.pendingSessions})',
                icon: Icons.pending_actions_outlined,
                emptyMessage: 'No pending sessions.',
                onViewAll: () => context.go('/appointments'),
                children: [
                  for (final appointment in stats.pendingAppointmentItems)
                    _AppointmentTile(
                      appointment: appointment,
                      showDate: true,
                      note: 'Date has passed — mark completed, missed or '
                          'cancelled',
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _DashboardDetailCard(
                title: 'Needs follow-up (${stats.needsFollowUp})',
                icon: Icons.notification_important_outlined,
                emptyMessage: 'No students need a follow-up right now.',
                onViewAll: () => context.go('/appointments'),
                children: [
                  for (final item in stats.followUpItems)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(
                        item.clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item.dueDate.isBefore(
                              DateTime(now.year, now.month, now.day),
                            )
                            ? 'Follow-up overdue'
                            : 'Follow-up due soon',
                      ),
                      trailing: Text(
                        formatDate(item.dueDate),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      onTap: () => context.go('/appointments'),
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

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.adminName});

  final String? adminName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        key: const ValueKey('dashboard-welcome-banner'),
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.sidebar, AppColors.navy],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showSeal = constraints.maxWidth >= 440;
                  final sealSize = constraints.maxWidth >= 700 ? 220.0 : 176.0;
                  final textInset = showSeal ? sealSize * .7 : 0.0;
                  return SizedBox(
                    height: showSeal ? 144 : 168,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (showSeal)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Transform.translate(
                              offset: const Offset(12, 0),
                              child: Opacity(
                                opacity: .34,
                                child: Image.asset(
                                  'assets/images/carranglan_national_high_school_logo_transparent.png',
                                  key: const ValueKey('school-seal-logo'),
                                  width: sealSize,
                                  height: sealSize,
                                  fit: BoxFit.contain,
                                  semanticLabel:
                                      'Carranglan National High School seal',
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(right: textInset),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Counseling Information System',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: Colors.white70,
                                          letterSpacing: .5,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    adminName == null ||
                                            adminName!.trim().isEmpty
                                        ? 'Welcome to your dashboard'
                                        : 'Welcome back, $adminName',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Monitor student guidance, sessions, and follow-ups.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuickActionButton(
          label: 'Add student',
          icon: Icons.person_add_alt_1,
          route: '/clients',
        ),
        const SizedBox(width: AppSpacing.xs),
        _QuickActionButton(
          label: 'Add intervention',
          icon: Icons.volunteer_activism,
          route: '/interventions',
        ),
        const SizedBox(width: AppSpacing.xs),
        _QuickActionButton(
          label: 'New counseling',
          icon: Icons.favorite_border,
          route: '/sessions',
        ),
        const SizedBox(width: AppSpacing.xs),
        _QuickActionButton(
          label: 'CP intake',
          icon: Icons.health_and_safety_outlined,
          route: '/forms/child_protection_intake',
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => context.go(route),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        visualDensity: VisualDensity.compact,
        textStyle: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label),
    );
  }
}

class _DashboardMetric {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.route,
  });

  final String label;
  final int value;
  final IconData icon;
  final String route;
}

class _GuidanceQueue extends StatelessWidget {
  const _GuidanceQueue({required this.stats, required this.dateLabel});

  final DashboardStats stats;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final appointmentCard = _DashboardDetailCard(
      title:
          'Appointments & sessions today (${stats.todaysAppointments + stats.todaysSessions})',
      icon: Icons.calendar_today_outlined,
      emptyMessage: 'No scheduled appointments for today.',
      onViewAll: () => context.go('/appointments'),
      children: [
        for (final appointment in stats.todayAppointmentItems)
          _AppointmentTile(appointment: appointment, showDate: false),
        for (final session in stats.todaySessionItems)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_edu_outlined),
            title: Text(session.clientName),
            subtitle: const Text('Counseling session recorded'),
            onTap: () => context.go('/sessions'),
          ),
      ],
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('guidance-queue-header'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.sidebar,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heading = Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Guidance Queue",
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          Text(
                            'Students and families expected in the guidance office · $dateLabel',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final actions = const _QuickActions();

                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: constraints.maxWidth,
                        child: FittedBox(
                          alignment: Alignment.centerRight,
                          fit: BoxFit.scaleDown,
                          child: actions,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 4, child: heading),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 5,
                      child: FittedBox(
                        alignment: Alignment.centerRight,
                        fit: BoxFit.scaleDown,
                        child: actions,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(children: [appointmentCard]),
          ),
        ],
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.appointment,
    required this.showDate,
    this.note,
  });

  final Appointment appointment;
  final bool showDate;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final purpose = appointment.purpose?.trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: Text(
        appointment.clientName ?? 'Student',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        note ??
            (purpose?.isNotEmpty == true
                ? purpose!
                : 'Counseling appointment · ${appointment.status.label}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        showDate
            ? formatDateTime(appointment.startsAt)
            : formatTime(appointment.startsAt),
        textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      onTap: () => context.go('/appointments'),
    );
  }
}

class _DashboardDetailCard extends StatelessWidget {
  const _DashboardDetailCard({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.onViewAll,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final VoidCallback onViewAll;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                TextButton(onPressed: onViewAll, child: const Text('View all')),
              ],
            ),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.sm,
                ),
                child: Text(
                  emptyMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.metric});

  final _DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(metric.route),
        child: SizedBox(
          width: double.infinity,
          height: 104,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        metric.label.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.mint.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(metric.icon, size: 17, color: AppColors.teal),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      '${metric.value}',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 11,
                      color: scheme.outline,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: AppSpacing.md),
          const Text('Could not load dashboard statistics.'),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _weekday(DateTime d) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[d.weekday - 1];
}

String _monthDay(DateTime d) {
  const names = [
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
  return '${names[d.month - 1]} ${d.day}, ${d.year}';
}
