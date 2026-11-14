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
    return DashboardStats(
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
