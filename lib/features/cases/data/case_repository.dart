import 'package:counseling_is/core/audit/audit_logger.dart';
import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/time.dart';
import 'package:counseling_is/features/cases/domain/case_record.dart';
import 'package:counseling_is/features/cases/domain/case_timeline_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CreateCaseInput {
  const CreateCaseInput({
    required this.clientId,
    required this.openedAt,
    this.summary,
    this.followUpDate,
  });

  final int clientId;
  final DateTime openedAt;
  final String? summary;
  final DateTime? followUpDate;
}

class CaseQuery {
  const CaseQuery({this.status, this.searchText, this.clientId});

  final CaseStatus? status;
  final String? searchText;
  final int? clientId;
}

class CaseRepository {
  CaseRepository(this._db, {AuditLogger? auditLogger})
    : _audit = auditLogger ?? AuditLogger(_db);

  final Database _db;
  final AuditLogger _audit;

  Future<CaseRecord> create(CreateCaseInput input) async {
    _validateDates(input.openedAt, input.followUpDate);
    return _db.transaction((txn) async {
      await _requireClient(txn, input.clientId);
      final caseRef = await _generateCaseRef(txn);
      final now = DateTime.now().toUtc();
      final id = await txn.insert('case_records', {
        'case_ref': caseRef,
        'client_id': input.clientId,
        'opened_at': dateToDb(input.openedAt),
        'status': CaseStatus.open.dbValue,
        'summary': _emptyToNull(input.summary),
        'follow_up_date': input.followUpDate == null
            ? null
            : dateToDb(input.followUpDate!),
        'created_at': dateTimeToDb(now),
        'updated_at': dateTimeToDb(now),
      });
      await _insertTimelineEvent(
        txn,
        caseId: id,
        occurredAt: now,
        eventType: 'case_opened',
        title: 'Case opened',
      );
      await _audit.record(
        action: 'created',
        entityType: 'case',
        entityId: id,
        executor: txn,
      );
      return _getByIdIn(txn, id);
    });
  }

  Future<CaseRecord> update(CaseRecord caseRecord) async {
    if (caseRecord.id == null) {
      throw ValidationException('Case id is required for update');
    }
    _validateDates(caseRecord.openedAt, caseRecord.followUpDate);
    return _db.transaction((txn) async {
      await _requireClient(txn, caseRecord.clientId);
      final previous = await _getByIdIn(txn, caseRecord.id!);

      final closing = caseRecord.status == CaseStatus.closed;
      final String? closedAt;
      String? closureNotes = _emptyToNull(caseRecord.closureNotes);
      if (closing) {
        closedAt = previous.closedAt == null
            ? dateToDb(DateTime.now())
            : dateToDb(previous.closedAt!);
      } else {
        closedAt = null;
        closureNotes = null;
      }

      final now = DateTime.now().toUtc();
      await txn.update(
        'case_records',
        {
          'client_id': caseRecord.clientId,
          'opened_at': dateToDb(caseRecord.openedAt),
          'status': caseRecord.status.dbValue,
          'summary': _emptyToNull(caseRecord.summary),
          'follow_up_date': caseRecord.followUpDate == null
              ? null
              : dateToDb(caseRecord.followUpDate!),
          'closed_at': closedAt,
          'closure_notes': closureNotes,
          'updated_at': dateTimeToDb(now),
        },
        where: 'id = ?',
        whereArgs: [caseRecord.id],
      );
      final changedFields = <String>[];
      if (previous.clientId != caseRecord.clientId) {
        changedFields.add('linked learner');
      }
      if (previous.openedAt != caseRecord.openedAt) {
        changedFields.add('opening date');
      }
      if (previous.status != caseRecord.status) {
        changedFields.add('status');
      }
      if (previous.followUpDate != caseRecord.followUpDate) {
        changedFields.add('follow-up date');
      }
      if (previous.summary != caseRecord.summary) {
        changedFields.add('case summary');
      }
      if (previous.closureNotes != caseRecord.closureNotes) {
        changedFields.add('closure notes');
      }
      if (changedFields.isNotEmpty) {
        await _insertTimelineEvent(
          txn,
          caseId: caseRecord.id!,
          occurredAt: now,
          eventType: 'case_updated',
          title: 'Case updated',
          description: 'Updated: ${changedFields.join(', ')}.',
        );
        await _audit.record(
          action: 'updated',
          entityType: 'case',
          entityId: caseRecord.id,
          executor: txn,
        );
      }
      return _getByIdIn(txn, caseRecord.id!);
    });
  }

  Future<void> recordTimelineEvent({
    required int caseId,
    required DateTime occurredAt,
    required String eventType,
    required String title,
    String? description,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedType = eventType.trim();
    if (normalizedTitle.isEmpty || normalizedType.isEmpty) {
      throw ValidationException('Timeline event type and title are required');
    }
    if (occurredAt.year < 2000 || occurredAt.year > 2100) {
      throw ValidationException('Event date must be between 2000 and 2100');
    }
    await _db.transaction((txn) async {
      await _getByIdIn(txn, caseId);
      final id = await _insertTimelineEvent(
        txn,
        caseId: caseId,
        occurredAt: occurredAt,
        eventType: normalizedType,
        title: normalizedTitle,
        description: _emptyToNull(description),
      );
      await _audit.record(
        action: 'created',
        entityType: 'case_timeline_event',
        entityId: id,
        executor: txn,
      );
    });
  }

  Future<void> completeFollowUp(int caseId) async {
    await _db.transaction((txn) async {
      final record = await _getByIdIn(txn, caseId);
      final scheduledDate = record.followUpDate;
      if (scheduledDate == null) {
        throw ValidationException('This case has no scheduled follow-up');
      }

      final now = DateTime.now().toUtc();
      await txn.update(
        'case_records',
        {'follow_up_date': null, 'updated_at': dateTimeToDb(now)},
        where: 'id = ?',
        whereArgs: [caseId],
      );
      final eventId = await _insertTimelineEvent(
        txn,
        caseId: caseId,
        occurredAt: now,
        eventType: 'follow_up_completed',
        title: 'Follow-up completed',
        description: 'Scheduled follow-up date: ${dateToDb(scheduledDate)}.',
      );
      await _audit.record(
        action: 'updated',
        entityType: 'case',
        entityId: caseId,
        executor: txn,
      );
      await _audit.record(
        action: 'created',
        entityType: 'case_timeline_event',
        entityId: eventId,
        executor: txn,
      );
    });
  }

  Future<List<CaseTimelineEvent>> timeline(int caseId) async {
    await _getByIdIn(_db, caseId);
    final rows = await _db.rawQuery(
      'SELECT e.*, a.full_name AS admin_name '
      'FROM case_timeline_events e '
      'LEFT JOIN admins a ON a.id = e.admin_id '
      'WHERE e.case_id = ? '
      'ORDER BY e.occurred_at DESC, e.id DESC',
      [caseId],
    );
    return rows.map(CaseTimelineEvent.fromMap).toList();
  }

  Future<CaseRecord> getById(int id) => _getByIdIn(_db, id);

  Future<List<CaseRecord>> list(CaseQuery query) async {
    final where = <String>[];
    final args = <Object?>[];

    final status = query.status;
    if (status != null) {
      where.add('cs.status = ?');
      args.add(status.dbValue);
    }

    final clientId = query.clientId;
    if (clientId != null) {
      where.add('cs.client_id = ?');
      args.add(clientId);
    }

    final text = _emptyToNull(query.searchText);
    if (text != null) {
      final like = '%${_escapeLike(text)}%';
      where.add(
        "(cs.case_ref LIKE ? ESCAPE '\\' OR c.full_name LIKE ? ESCAPE '\\')",
      );
      args.addAll([like, like]);
    }

    final rows = await _db.rawQuery(
      'SELECT cs.*, c.full_name AS client_name '
      'FROM case_records cs '
      'JOIN clients c ON c.id = cs.client_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY cs.opened_at DESC, cs.case_ref DESC',
      args,
    );
    return rows.map(CaseRecord.fromMap).toList();
  }

  Future<String> _generateCaseRef(DatabaseExecutor txn) async {
    final year = DateTime.now().toUtc().year;
    final prefix = 'CASE-$year-';
    final rows = await txn.rawQuery(
      'SELECT case_ref FROM case_records '
      'WHERE case_ref LIKE ? '
      'ORDER BY case_ref DESC LIMIT 1',
      ['$prefix%'],
    );
    var next = 1;
    if (rows.isNotEmpty) {
      final last = rows.first['case_ref'] as String;
      final seq = int.tryParse(last.substring(prefix.length));
      if (seq != null) next = seq + 1;
    }
    return '$prefix${next.toString().padLeft(4, '0')}';
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

  Future<CaseRecord> _getByIdIn(DatabaseExecutor txn, int id) async {
    final rows = await txn.rawQuery(
      'SELECT cs.*, c.full_name AS client_name '
      'FROM case_records cs '
      'JOIN clients c ON c.id = cs.client_id '
      'WHERE cs.id = ?',
      [id],
    );
    if (rows.isEmpty) throw NotFoundException('Case not found');
    return CaseRecord.fromMap(rows.single);
  }

  Future<int> _insertTimelineEvent(
    DatabaseExecutor txn, {
    required int caseId,
    required DateTime occurredAt,
    required String eventType,
    required String title,
    String? description,
  }) => txn.insert('case_timeline_events', {
    'case_id': caseId,
    'occurred_at': dateTimeToDb(occurredAt),
    'event_type': eventType,
    'title': title,
    'description': description,
    'admin_id': _audit.currentAdminId,
    'created_at': nowUtcIso(),
  });

  void _validateDates(DateTime openedAt, DateTime? followUpDate) {
    if (openedAt.year < 2000 || openedAt.year > 2100) {
      throw ValidationException('Opening date must be between 2000 and 2100');
    }
    if (followUpDate != null && followUpDate.isBefore(openedAt)) {
      throw ValidationException(
        'Follow-up date cannot be before the opening date',
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
