import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/time/time.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum ReportType {
  clients('Students'),
  appointments('Appointments'),
  sessions('Counseling sessions'),
  depedDraft('DepEd services report (draft)');

  const ReportType(this.label);

  final String label;
}

class ReportRequest {
  const ReportRequest({
    this.type = ReportType.clients,
    this.from,
    this.to,
    this.status,
  });

  final ReportType type;

  /// Inclusive local calendar-date bounds; null means unbounded.
  final DateTime? from;
  final DateTime? to;

  /// Status filter as a database value (`active`/`archived`,
  /// `scheduled`/…, `open`/…); null means any status.
  final String? status;
}

class ReportTable {
  const ReportTable({
    required this.columns,
    required this.rows,
    required this.total,
    this.breakdown,
  });

  final List<String> columns;
  final List<List<String>> rows;
  final int total;

  /// Optional status → count summary (same filter applied).
  final Map<String, int>? breakdown;
}

class ReportRepository {
  ReportRepository(this._db);

  final Database _db;

  Future<ReportTable> run(ReportRequest request) async {
    final from = request.from;
    final to = request.to;
    if (from != null && to != null && from.isAfter(to)) {
      throw ValidationException('Start date must be on or before end date');
    }

    return switch (request.type) {
      ReportType.clients => _clients(request),
      ReportType.appointments => _appointments(request),
      ReportType.sessions => _sessions(request),
      ReportType.depedDraft => _depedDraft(request),
    };
  }

  Future<ReportTable> _depedDraft(ReportRequest request) async {
    final indicators = <(String, String, String)>[
      ('Learners registered', 'clients', 'registered_at'),
      ('Appointments scheduled', 'appointments', 'starts_at'),
      ('Counseling sessions documented', 'counseling_sessions', 'session_date'),
      ('Interventions started', 'interventions', 'start_date'),
      ('Child-protection intakes received', 'form_submissions', 'created_at'),
    ];
    final rows = <List<String>>[];
    for (final (label, table, column) in indicators) {
      final where = <String>[];
      final args = <Object?>[];
      _applyDateRange(
        where: where,
        args: args,
        column: column,
        from: request.from,
        to: request.to,
        dateTimeColumn:
            table == 'clients' ||
            table == 'appointments' ||
            table == 'form_submissions',
      );
      if (table == 'form_submissions') {
        where.add('form_id = ?');
        args.add('child_protection_intake');
      }
      final result = await _db.rawQuery(
        'SELECT COUNT(*) AS c FROM $table ${_whereClause(where)}',
        args,
      );
      rows.add([label, '${result.single['c'] as int}']);
    }
    return ReportTable(
      columns: const ['Indicator', 'Count'],
      rows: rows,
      total: rows.length,
    );
  }

  Future<ReportTable> _clients(ReportRequest request) async {
    final where = <String>[];
    final args = <Object?>[];
    _applyDateRange(
      where: where,
      args: args,
      column: 'registered_at',
      from: request.from,
      to: request.to,
      dateTimeColumn: true,
    );
    final status = request.status;
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }

    final rows = await _query(
      'SELECT * FROM clients ${_whereClause(where)} '
      'ORDER BY registered_at DESC',
      args,
    );
    final breakdown = await _breakdown(
      from: 'clients',
      statusColumn: 'status',
      where: where,
      args: args,
    );
    return ReportTable(
      columns: const [
        'Reference',
        'Name',
        'Phone',
        'Email',
        'Registered',
        'Status',
      ],
      rows: rows.map((map) {
        final registered =
            parseDbDateTime(map['registered_at'] as String) ?? DateTime.now();
        return [
          map['reference_no'] as String,
          map['full_name'] as String,
          map['phone'] as String? ?? '—',
          map['email'] as String? ?? '—',
          formatDate(registered),
          _clientStatusLabel(map['status'] as String),
        ];
      }).toList(),
      total: rows.length,
      breakdown: breakdown,
    );
  }

  Future<ReportTable> _appointments(ReportRequest request) async {
    final where = <String>[];
    final args = <Object?>[];
    _applyDateRange(
      where: where,
      args: args,
      column: 'a.starts_at',
      from: request.from,
      to: request.to,
      dateTimeColumn: true,
    );
    final status = request.status;
    if (status != null) {
      where.add('a.status = ?');
      args.add(status);
    }

    final rows = await _query(
      'SELECT a.*, c.full_name AS client_name FROM appointments a '
      'JOIN clients c ON c.id = a.client_id ${_whereClause(where)} '
      'ORDER BY a.starts_at ASC',
      args,
    );
    final breakdown = await _breakdown(
      from: 'appointments a',
      statusColumn: 'a.status',
      where: where,
      args: args,
    );

    return ReportTable(
      columns: const ['Date', 'Time', 'Student', 'Purpose', 'Status'],
      rows: rows.map((map) {
        final start =
            parseDbDateTime(map['starts_at'] as String) ?? DateTime.now();
        final end = parseDbDateTime(map['ends_at'] as String) ?? start;
        return [
          formatDate(start),
          '${formatTime(start)} – ${formatTime(end)}',
          map['client_name'] as String,
          map['purpose'] as String? ?? '—',
          _appointmentStatusLabel(map['status'] as String),
        ];
      }).toList(),
      total: rows.length,
      breakdown: breakdown,
    );
  }

  Future<ReportTable> _sessions(ReportRequest request) async {
    final where = <String>[];
    final args = <Object?>[];
    _applyDateRange(
      where: where,
      args: args,
      column: 's.session_date',
      from: request.from,
      to: request.to,
      dateTimeColumn: false,
    );

    final rows = await _query(
      'SELECT s.*, c.full_name AS client_name FROM counseling_sessions s '
      'JOIN clients c ON c.id = s.client_id ${_whereClause(where)} '
      'ORDER BY s.session_date ASC',
      args,
    );

    // Confidential session notes are deliberately never part of reports.
    return ReportTable(
      columns: const [
        'Date',
        'Student',
        'Next recommended',
        'Linked appointment',
      ],
      rows: rows.map((map) {
        final date =
            parseDbDate(map['session_date'] as String) ?? DateTime.now();
        final next = parseDbDate(map['next_recommended_date'] as String?);
        return [
          formatDate(date),
          map['client_name'] as String,
          next == null ? '—' : formatDate(next),
          map['appointment_id'] == null ? 'No' : 'Yes',
        ];
      }).toList(),
      total: rows.length,
    );
  }

  void _applyDateRange({
    required List<String> where,
    required List<Object?> args,
    required String column,
    required DateTime? from,
    required DateTime? to,
    required bool dateTimeColumn,
  }) {
    if (dateTimeColumn) {
      if (from != null) {
        where.add('$column >= ?');
        args.add(dateTimeToDb(DateTime(from.year, from.month, from.day)));
      }
      if (to != null) {
        where.add('$column < ?');
        args.add(dateTimeToDb(DateTime(to.year, to.month, to.day + 1)));
      }
    } else {
      if (from != null) {
        where.add('$column >= ?');
        args.add(dateToDb(from));
      }
      if (to != null) {
        where.add('$column <= ?');
        args.add(dateToDb(to));
      }
    }
  }

  Future<Map<String, int>?> _breakdown({
    required String from,
    required String statusColumn,
    required List<String> where,
    required List<Object?> args,
  }) async {
    final rows = await _query(
      'SELECT $statusColumn AS status, COUNT(*) AS c '
      'FROM $from ${_whereClause(where)} '
      'GROUP BY $statusColumn',
      args,
    );
    final result = <String, int>{};
    for (final row in rows) {
      final status = row['status'] as String;
      result[status] = (row['c'] as int?) ?? 0;
    }
    return result;
  }

  Future<List<Map<String, Object?>>> _query(String sql, List<Object?> args) =>
      _db.rawQuery(sql, args);

  String _whereClause(List<String> where) =>
      where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

  String _clientStatusLabel(String value) {
    for (final status in ClientStatus.values) {
      if (status.dbValue == value) {
        return status == ClientStatus.active ? 'Active' : 'Archived';
      }
    }
    return value;
  }

  String _appointmentStatusLabel(String value) {
    return switch (value) {
      'scheduled' => 'Scheduled',
      'completed' => 'Completed',
      'missed' => 'Missed',
      'cancelled' => 'Cancelled',
      _ => value,
    };
  }
}
