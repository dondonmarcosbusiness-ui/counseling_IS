import 'package:counseling_is/core/audit/audit_logger.dart';
import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/time.dart';
import 'package:counseling_is/features/sessions/domain/session_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CreateSessionInput {
  const CreateSessionInput({
    required this.clientId,
    this.appointmentId,
    required this.sessionDate,
    required this.notes,
    this.followUpActions,
    this.nextRecommendedDate,
  });

  final int clientId;
  final int? appointmentId;
  final DateTime sessionDate;
  final String notes;
  final String? followUpActions;
  final DateTime? nextRecommendedDate;
}

class SessionQuery {
  const SessionQuery({this.searchText, this.clientId});

  final String? searchText;
  final int? clientId;
}

class SessionRepository {
  SessionRepository(this._db, {AuditLogger? auditLogger})
    : _audit = auditLogger ?? AuditLogger(_db);

  final Database _db;
  final AuditLogger _audit;

  Future<SessionRecord> create(CreateSessionInput input) async {
    final notes = _requireText(input.notes, 'Session notes');
    _validateDates(input.sessionDate, input.nextRecommendedDate);
    return _db.transaction((txn) async {
      await _requireClient(txn, input.clientId);
      if (input.appointmentId != null) {
        await _requireOwnAppointment(
          txn,
          appointmentId: input.appointmentId!,
          clientId: input.clientId,
        );
      }
      final now = DateTime.now().toUtc();
      final id = await txn.insert('counseling_sessions', {
        'client_id': input.clientId,
        'appointment_id': input.appointmentId,
        'session_date': dateToDb(input.sessionDate),
        'notes': notes,
        'follow_up_actions': _emptyToNull(input.followUpActions),
        'next_recommended_date': input.nextRecommendedDate == null
            ? null
            : dateToDb(input.nextRecommendedDate!),
        'created_at': dateTimeToDb(now),
        'updated_at': dateTimeToDb(now),
      });
      await _audit.record(
        action: 'created',
        entityType: 'counseling_session',
        entityId: id,
        executor: txn,
      );
      return _getByIdIn(txn, id);
    });
  }

  Future<SessionRecord> update(SessionRecord session) async {
    if (session.id == null) {
      throw ValidationException('Session id is required for update');
    }
    final notes = _requireText(session.notes, 'Session notes');
    _validateDates(session.sessionDate, session.nextRecommendedDate);
    return _db.transaction((txn) async {
      await _requireClient(txn, session.clientId);
      if (session.appointmentId != null) {
        await _requireOwnAppointment(
          txn,
          appointmentId: session.appointmentId!,
          clientId: session.clientId,
        );
      }
      final now = DateTime.now().toUtc();
      await txn.update(
        'counseling_sessions',
        {
          'client_id': session.clientId,
          'appointment_id': session.appointmentId,
          'session_date': dateToDb(session.sessionDate),
          'notes': notes,
          'follow_up_actions': _emptyToNull(session.followUpActions),
          'next_recommended_date': session.nextRecommendedDate == null
              ? null
              : dateToDb(session.nextRecommendedDate!),
          'updated_at': dateTimeToDb(now),
        },
        where: 'id = ?',
        whereArgs: [session.id],
      );
      await _audit.record(
        action: 'updated',
        entityType: 'counseling_session',
        entityId: session.id,
        executor: txn,
      );
      return _getByIdIn(txn, session.id!);
    });
  }

  Future<SessionRecord> getById(int id) => _getByIdIn(_db, id);

  Future<List<SessionRecord>> list(SessionQuery query) async {
    final where = <String>[];
    final args = <Object?>[];

    final clientId = query.clientId;
    if (clientId != null) {
      where.add('s.client_id = ?');
      args.add(clientId);
    }

    final text = _emptyToNull(query.searchText);
    if (text != null) {
      final like = '%${_escapeLike(text)}%';
      where.add(
        "(c.full_name LIKE ? ESCAPE '\\' OR s.notes LIKE ? ESCAPE '\\')",
      );
      args.addAll([like, like]);
    }

    final rows = await _db.rawQuery(
      'SELECT s.*, c.full_name AS client_name '
      'FROM counseling_sessions s '
      'JOIN clients c ON c.id = s.client_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY s.session_date DESC, s.id DESC',
      args,
    );
    return rows.map(SessionRecord.fromMap).toList();
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

  Future<void> _requireOwnAppointment(
    DatabaseExecutor txn, {
    required int appointmentId,
    required int clientId,
  }) async {
    final rows = await txn.query(
      'appointments',
      columns: ['client_id'],
      where: 'id = ?',
      whereArgs: [appointmentId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw NotFoundException('Selected appointment no longer exists');
    }
    if (rows.single['client_id'] != clientId) {
      throw ValidationException(
        'Selected appointment belongs to a different student',
      );
    }
  }

  Future<SessionRecord> _getByIdIn(DatabaseExecutor txn, int id) async {
    final rows = await txn.rawQuery(
      'SELECT s.*, c.full_name AS client_name '
      'FROM counseling_sessions s '
      'JOIN clients c ON c.id = s.client_id '
      'WHERE s.id = ?',
      [id],
    );
    if (rows.isEmpty) throw NotFoundException('Session not found');
    return SessionRecord.fromMap(rows.single);
  }

  void _validateDates(DateTime sessionDate, DateTime? nextRecommended) {
    if (sessionDate.year < 2000 || sessionDate.year > 2100) {
      throw ValidationException('Session date must be between 2000 and 2100');
    }
    if (nextRecommended != null && nextRecommended.isBefore(sessionDate)) {
      throw ValidationException(
        'Next recommended date cannot be before the session date',
      );
    }
  }

  String _requireText(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ValidationException('$label is required');
    return trimmed;
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
