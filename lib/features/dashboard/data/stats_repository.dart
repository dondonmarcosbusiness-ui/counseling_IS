import 'package:counseling_is/core/time/time.dart';
import 'package:counseling_is/features/appointments/domain/appointment.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DashboardStats {
  const DashboardStats({
    required this.activeClients,
    required this.todaysAppointments,
    required this.upcomingAppointments,
    required this.completedSessions,
    required this.todaysSessions,
    required this.activeInterventions,
    required this.todayAppointmentItems,
    required this.todaySessionItems,
    required this.upcomingAppointmentItems,
    this.pendingSessions = 0,
    this.pendingAppointmentItems = const [],
    this.needsFollowUp = 0,
    this.followUpItems = const [],
  });

  final int activeClients;
  final int todaysAppointments;
  final int upcomingAppointments;
  final int completedSessions;
  final int todaysSessions;
  final int activeInterventions;
  final List<Appointment> todayAppointmentItems;
  final List<DashboardSessionItem> todaySessionItems;
  final List<Appointment> upcomingAppointmentItems;

  /// Scheduled sessions whose time has already passed without being marked
  /// completed, missed or cancelled.
  final int pendingSessions;
  final List<Appointment> pendingAppointmentItems;

  /// Students whose latest session recommended a follow-up that is due (or
  /// overdue) and who have no appointment scheduled yet.
  final int needsFollowUp;
  final List<DashboardFollowUpItem> followUpItems;

  bool get isEmpty =>
      activeClients == 0 &&
      todaysAppointments == 0 &&
      upcomingAppointments == 0 &&
      completedSessions == 0 &&
      todaysSessions == 0 &&
      activeInterventions == 0;
}

class StatsRepository {
  StatsRepository(this._db);

  final Database _db;

  Future<DashboardStats> fetch({DateTime? now}) async {
    final ref = now ?? DateTime.now();
    final localDayStart = DateTime(ref.year, ref.month, ref.day);
    final localDayEnd = localDayStart.add(const Duration(days: 1));
    final nowIso = dateTimeToDb(ref);
    final dayStartIso = dateTimeToDb(localDayStart);
    final dayEndIso = dateTimeToDb(localDayEnd);

    final activeClients = await _count(
      'SELECT COUNT(*) AS c FROM clients WHERE status = ?',
      ['active'],
    );

    final todaysAppointments = await _count(
      'SELECT COUNT(*) AS c FROM appointments '
      'WHERE starts_at >= ? AND starts_at < ? '
      "AND status != 'cancelled'",
      [dayStartIso, dayEndIso],
    );

    final upcomingAppointments = await _count(
      'SELECT COUNT(*) AS c FROM appointments '
      "WHERE starts_at >= ? AND status = 'scheduled'",
      [nowIso],
    );

    final completedSessions = await _count(
      'SELECT COUNT(*) AS c FROM counseling_sessions',
    );

    final todaysSessions = await _count(
      'SELECT COUNT(*) AS c FROM counseling_sessions '
      'WHERE session_date >= ? AND session_date < ?',
      [dateToDb(localDayStart), dateToDb(localDayEnd)],
    );

    final activeInterventions = await _count(
      'SELECT COUNT(*) AS c FROM interventions '
      "WHERE status IN ('planned', 'in_progress')",
    );

    final appointmentRows = await _db.rawQuery(
      'SELECT a.*, c.full_name AS client_name '
      'FROM appointments a '
      'JOIN clients c ON c.id = a.client_id '
      "WHERE a.starts_at >= ? AND a.status = 'scheduled' "
      'ORDER BY a.starts_at ASC LIMIT 5',
      [nowIso],
    );
    final todayAppointmentRows = await _db.rawQuery(
      'SELECT a.*, c.full_name AS client_name '
      'FROM appointments a '
      'JOIN clients c ON c.id = a.client_id '
      'WHERE a.starts_at >= ? AND a.starts_at < ? '
      "AND a.status != 'cancelled' "
      'ORDER BY a.starts_at ASC',
      [dayStartIso, dayEndIso],
    );
    final todaySessionRows = await _db.rawQuery(
      'SELECT s.session_date, c.full_name AS client_name '
      'FROM counseling_sessions s '
      'JOIN clients c ON c.id = s.client_id '
      'WHERE s.session_date >= ? AND s.session_date < ? '
      'ORDER BY s.session_date ASC, s.id ASC',
      [dateToDb(localDayStart), dateToDb(localDayEnd)],
    );
    final pendingCount = await _count(
      'SELECT COUNT(*) AS c FROM appointments '
      "WHERE starts_at < ? AND status = 'scheduled'",
      [nowIso],
    );
    final pendingRows = await _db.rawQuery(
      'SELECT a.*, c.full_name AS client_name '
      'FROM appointments a '
      'JOIN clients c ON c.id = a.client_id '
      "WHERE a.starts_at < ? AND a.status = 'scheduled' "
      'ORDER BY a.starts_at DESC LIMIT 5',
      [nowIso],
    );

    // A follow-up is due when the student's most recent session recommends a
    // next date that is today, overdue or within the coming week, and no
    // appointment has been scheduled for that student yet.
    final followUpCutoff = dateToDb(localDayStart.add(const Duration(days: 7)));
    final followUpRows = await _db.rawQuery(
      'SELECT s.client_id AS client_id, s.next_recommended_date AS due_date, '
      'c.full_name AS client_name '
      'FROM counseling_sessions s '
      'JOIN clients c ON c.id = s.client_id '
      'WHERE s.next_recommended_date IS NOT NULL '
      'AND s.next_recommended_date <= ? '
      "AND c.status = 'active' "
      'AND s.id = ('
      'SELECT s2.id FROM counseling_sessions s2 '
      'WHERE s2.client_id = s.client_id '
      'ORDER BY s2.session_date DESC, s2.id DESC LIMIT 1) '
      'AND NOT EXISTS ('
      'SELECT 1 FROM appointments a '
      "WHERE a.client_id = s.client_id AND a.status = 'scheduled' "
      'AND a.starts_at >= ?) '
      'ORDER BY s.next_recommended_date ASC',
      [followUpCutoff, dayStartIso],
    );

    return DashboardStats(
      pendingSessions: pendingCount,
      pendingAppointmentItems: pendingRows.map(Appointment.fromMap).toList(),
      needsFollowUp: followUpRows.length,
      followUpItems: followUpRows
          .take(5)
          .map(DashboardFollowUpItem.fromMap)
          .toList(),
      activeClients: activeClients,
      todaysAppointments: todaysAppointments,
      upcomingAppointments: upcomingAppointments,
      completedSessions: completedSessions,
      todaysSessions: todaysSessions,
      activeInterventions: activeInterventions,
      todayAppointmentItems: todayAppointmentRows
          .map(Appointment.fromMap)
          .toList(),
      todaySessionItems: todaySessionRows
          .map(DashboardSessionItem.fromMap)
          .toList(),
      upcomingAppointmentItems: appointmentRows
          .map(Appointment.fromMap)
          .toList(),
    );
  }

  Future<int> _count(String sql, [List<Object?> args = const []]) async {
    final rows = await _db.rawQuery(sql, args);
    return (rows.first['c'] as int?) ?? 0;
  }
}

class DashboardFollowUpItem {
  const DashboardFollowUpItem({
    required this.clientName,
    required this.dueDate,
  });

  final String clientName;
  final DateTime dueDate;

  static DashboardFollowUpItem fromMap(Map<String, Object?> map) =>
      DashboardFollowUpItem(
        clientName: map['client_name'] as String,
        dueDate: parseDbDate(map['due_date'] as String)!,
      );
}

class DashboardSessionItem {
  const DashboardSessionItem({
    required this.clientName,
    required this.sessionDate,
  });

  final String clientName;
  final DateTime sessionDate;

  static DashboardSessionItem fromMap(Map<String, Object?> map) =>
      DashboardSessionItem(
        clientName: map['client_name'] as String,
        sessionDate: parseDbDate(map['session_date'] as String)!,
      );
}
