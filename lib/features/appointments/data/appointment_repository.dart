import 'package:counseling_is/core/audit/audit_logger.dart';
import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/time/time.dart';
import 'package:counseling_is/features/appointments/domain/appointment.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CreateAppointmentInput {
  const CreateAppointmentInput({
    required this.clientId,
    required this.startsAt,
    required this.endsAt,
    this.purpose,
    this.notes,
  });

  final int clientId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? purpose;
  final String? notes;
}

class AppointmentQuery {
  const AppointmentQuery({
    this.timeFilter = AppointmentTimeFilter.upcoming,
    this.status,
    this.clientId,
    this.searchText,
  });

  final AppointmentTimeFilter timeFilter;
  final AppointmentStatus? status;
  final int? clientId;
  final String? searchText;
}

class AppointmentRepository {
  AppointmentRepository(this._db, {AuditLogger? auditLogger})
    : _audit = auditLogger ?? AuditLogger(_db);

  final Database _db;
  final AuditLogger _audit;

  Future<Appointment> create(CreateAppointmentInput input) async {
    _validateWindow(input.startsAt, input.endsAt);
    return _db.transaction((txn) async {
      await _requireClient(txn, input.clientId);
      await _ensureNoConflict(
        txn,
        startsAt: input.startsAt,
        endsAt: input.endsAt,
      );
      final now = DateTime.now().toUtc();
      final id = await txn.insert('appointments', {
        'client_id': input.clientId,
        'starts_at': dateTimeToDb(input.startsAt),
        'ends_at': dateTimeToDb(input.endsAt),
        'purpose': _emptyToNull(input.purpose),
        'status': AppointmentStatus.scheduled.dbValue,
        'notes': _emptyToNull(input.notes),
        'created_at': dateTimeToDb(now),
        'updated_at': dateTimeToDb(now),
      });
      await _audit.record(
        action: 'created',
        entityType: 'appointment',
        entityId: id,
        executor: txn,
      );
      return _getByIdIn(txn, id);
    });
  }

  Future<Appointment> update(Appointment appointment) async {
    if (appointment.id == null) {
      throw ValidationException('Appointment id is required for update');
    }
    _validateWindow(appointment.startsAt, appointment.endsAt);
    return _db.transaction((txn) async {
      await _requireClient(txn, appointment.clientId);
      final existing = await _getByIdIn(txn, appointment.id!);
      await _ensureNoConflict(
        txn,
        startsAt: appointment.startsAt,
        endsAt: appointment.endsAt,
        excludeId: existing.id,
      );
      final now = DateTime.now().toUtc();
      await txn.update(
        'appointments',
        {
          'client_id': appointment.clientId,
          'starts_at': dateTimeToDb(appointment.startsAt),
          'ends_at': dateTimeToDb(appointment.endsAt),
          'purpose': _emptyToNull(appointment.purpose),
          'status': appointment.status.dbValue,
          'notes': _emptyToNull(appointment.notes),
          'updated_at': dateTimeToDb(now),
        },
        where: 'id = ?',
        whereArgs: [appointment.id],
      );
      await _audit.record(
        action: 'updated',
        entityType: 'appointment',
        entityId: appointment.id,
        executor: txn,
      );
      return _getByIdIn(txn, appointment.id!);
    });
  }

  Future<Appointment> getById(int id) => _getByIdIn(_db, id);

  Future<List<Appointment>> list(
    AppointmentQuery query, {
    DateTime? now,
  }) async {
    final ref = now ?? DateTime.now();
    final where = <String>[];
    final args = <Object?>[];

    switch (query.timeFilter) {
      case AppointmentTimeFilter.upcoming:
        where.add('a.starts_at >= ?');
        args.add(dateTimeToDb(ref));
      case AppointmentTimeFilter.today:
        final dayStart = DateTime(ref.year, ref.month, ref.day);
        where.add('a.starts_at >= ? AND a.starts_at < ?');
        args.add(dateTimeToDb(dayStart));
        args.add(dateTimeToDb(dayStart.add(const Duration(days: 1))));
      case AppointmentTimeFilter.past:
        where.add('a.starts_at < ?');
        args.add(dateTimeToDb(ref));
      case AppointmentTimeFilter.all:
        break;
    }

    final status = query.status;
    if (status != null) {
      where.add('a.status = ?');
      args.add(status.dbValue);
    }

    final clientId = query.clientId;
    if (clientId != null) {
      where.add('a.client_id = ?');
      args.add(clientId);
    }

    final text = _emptyToNull(query.searchText);
    if (text != null) {
      final like = '%${_escapeLike(text)}%';
      where.add(
        "(c.full_name LIKE ? ESCAPE '\\' OR a.purpose LIKE ? ESCAPE '\\')",
      );
      args.addAll([like, like]);
    }

    final asc =
        query.timeFilter == AppointmentTimeFilter.upcoming ||
        query.timeFilter == AppointmentTimeFilter.today;
    final orderBy = asc ? 'a.starts_at ASC' : 'a.starts_at DESC';

    final rows = await _db.rawQuery(
      'SELECT a.*, c.full_name AS client_name '
      'FROM appointments a '
      'JOIN clients c ON c.id = a.client_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY $orderBy',
      args,
    );
    return rows.map(Appointment.fromMap).toList();
  }

  Future<void> _ensureNoConflict(
    DatabaseExecutor txn, {
    required DateTime startsAt,
    required DateTime endsAt,
    int? excludeId,
  }) async {
    var sql =
        'SELECT a.starts_at, a.ends_at, c.full_name AS client_name '
        'FROM appointments a '
        'JOIN clients c ON c.id = a.client_id '
        "WHERE a.status = 'scheduled' ";
    final args = <Object?>[];
    if (excludeId != null) {
      sql += 'AND a.id != ? ';
      args.add(excludeId);
    }
    sql += 'AND a.starts_at < ? AND a.ends_at > ? LIMIT 1';
    args.add(dateTimeToDb(endsAt));
    args.add(dateTimeToDb(startsAt));

    final rows = await txn.rawQuery(sql, args);
    if (rows.isEmpty) return;
    final row = rows.single;
    final otherClient = row['client_name'] as String? ?? 'another student';
    final otherStart = parseDbDateTime(row['starts_at'] as String?) ?? startsAt;
    throw ConflictException(
      'This time overlaps a scheduled appointment for $otherClient '
      '(${formatDateTime(otherStart)}).',
    );
  }

  Future<void> _requireClient(DatabaseExecutor txn, int clientId) async {
    final rows = await txn.query(
      'clients',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw NotFoundException('Selected student no longer exists');
    }
  }

  Future<Appointment> _getByIdIn(DatabaseExecutor txn, int id) async {
    final rows = await txn.rawQuery(
      'SELECT a.*, c.full_name AS client_name '
      'FROM appointments a '
      'JOIN clients c ON c.id = a.client_id '
      'WHERE a.id = ?',
      [id],
    );
    if (rows.isEmpty) throw NotFoundException('Appointment not found');
    return Appointment.fromMap(rows.single);
  }

  void _validateWindow(DateTime startsAt, DateTime endsAt) {
    if (!endsAt.isAfter(startsAt)) {
      throw ValidationException('End time must be after start time');
    }
    if (startsAt.year < 2000 || startsAt.year > 2100) {
      throw ValidationException(
        'Appointment date must be between 2000 and 2100',
      );
    }
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _escapeLike(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
