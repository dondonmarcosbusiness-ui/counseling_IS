import 'package:counseling_is/core/audit/audit_logger.dart';
import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/time.dart';
import 'package:counseling_is/features/interventions/domain/intervention.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CreateInterventionInput {
  const CreateInterventionInput({
    required this.clientId,
    this.caseId,
    this.participantIds,
    required this.title,
    required this.type,
    this.customType,
    this.description,
    this.goal,
    required this.startDate,
    this.targetDate,
  });

  final int clientId;
  final int? caseId;
  final List<int>? participantIds;
  final String title;
  final String type;
  final String? customType;
  final String? description;
  final String? goal;
  final DateTime startDate;
  final DateTime? targetDate;
}

class InterventionQuery {
  const InterventionQuery({this.searchText, this.status});

  final String? searchText;
  final InterventionStatus? status;
}

class InterventionRepository {
  InterventionRepository(this._db, {AuditLogger? auditLogger})
    : _audit = auditLogger ?? AuditLogger(_db);

  final Database _db;
  final AuditLogger _audit;

  Future<Intervention> create(CreateInterventionInput input) async {
    final title = _requireText(input.title, 'Intervention title');
    final type = _requireText(input.type, 'Intervention type');
    final customType = _validatedCustomType(type, input.customType);
    final participantIds = _normalizeParticipants(
      input.participantIds ?? [input.clientId],
    );
    _validateDates(input.startDate, input.targetDate);
    return _db.transaction((txn) async {
      await _requireClient(txn, input.clientId);
      await _requireParticipants(txn, participantIds);
      await _requireCase(txn, input.caseId, input.clientId);
      final now = DateTime.now().toUtc();
      final id = await txn.insert('interventions', {
        'client_id': input.clientId,
        'case_id': input.caseId,
        'title': title,
        'intervention_type': type,
        'custom_type': customType,
        'description': _emptyToNull(input.description),
        'goal': _emptyToNull(input.goal),
        'status': InterventionStatus.planned.dbValue,
        'start_date': dateToDb(input.startDate),
        'target_date': input.targetDate == null
            ? null
            : dateToDb(input.targetDate!),
        'created_at': dateTimeToDb(now),
        'updated_at': dateTimeToDb(now),
      });
      await _setParticipants(txn, id, participantIds);
      await _audit.record(
        action: 'created',
        entityType: 'intervention',
        entityId: id,
        executor: txn,
      );
      return _getByIdIn(txn, id);
    });
  }

  Future<Intervention> update(Intervention intervention) async {
    final id = intervention.id;
    if (id == null) throw ValidationException('Intervention id is required');
    _validateDates(intervention.startDate, intervention.targetDate);
    final title = _requireText(intervention.title, 'Intervention title');
    final type = _requireText(intervention.type, 'Intervention type');
    final customType = _validatedCustomType(type, intervention.customType);
    final participantIds = _normalizeParticipants(
      intervention.participantIds.isEmpty
          ? [intervention.clientId]
          : intervention.participantIds,
    );
    return _db.transaction((txn) async {
      await _requireClient(txn, intervention.clientId);
      await _requireParticipants(txn, participantIds);
      await _requireCase(txn, intervention.caseId, intervention.clientId);
      final previous = await _getByIdIn(txn, id);
      final now = DateTime.now().toUtc();
      final completedAt = switch (intervention.status) {
        InterventionStatus.completed => previous.completedAt ?? DateTime.now(),
        _ => null,
      };
      final changed = await txn.update(
        'interventions',
        {
          'client_id': intervention.clientId,
          'case_id': intervention.caseId,
          'title': title,
          'intervention_type': type,
          'custom_type': customType,
          'description': _emptyToNull(intervention.description),
          'goal': _emptyToNull(intervention.goal),
          'status': intervention.status.dbValue,
          'start_date': dateToDb(intervention.startDate),
          'target_date': intervention.targetDate == null
              ? null
              : dateToDb(intervention.targetDate!),
          'completed_at': completedAt == null ? null : dateToDb(completedAt),
          'outcome': _emptyToNull(intervention.outcome),
          'updated_at': dateTimeToDb(now),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw NotFoundException('Intervention not found');
      await _setParticipants(txn, id, participantIds);
      await _audit.record(
        action: 'updated',
        entityType: 'intervention',
        entityId: id,
        executor: txn,
      );
      return _getByIdIn(txn, id);
    });
  }

  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      final changed = await txn.delete(
        'interventions',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw NotFoundException('Intervention not found');
      await _audit.record(
        action: 'deleted',
        entityType: 'intervention',
        entityId: id,
        executor: txn,
      );
    });
  }

  Future<List<Intervention>> list(InterventionQuery query) async {
    final where = <String>[];
    final args = <Object?>[];
    if (query.status != null) {
      where.add('i.status = ?');
      args.add(query.status!.dbValue);
    }
    final text = query.searchText?.trim();
    if (text != null && text.isNotEmpty) {
      final escaped = text
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      final like = '%$escaped%';
      where.add(
        "(i.title LIKE ? ESCAPE '\\' OR c.full_name LIKE ? ESCAPE '\\' "
        "OR i.intervention_type LIKE ? ESCAPE '\\' "
        "OR i.custom_type LIKE ? ESCAPE '\\' "
        "OR pc.full_name LIKE ? ESCAPE '\\')",
      );
      args.addAll([like, like, like, like, like]);
    }
    final rows = await _db.rawQuery(
      'SELECT i.*, c.full_name AS client_name, cr.case_ref, '
      'group_concat(ip.client_id) AS participant_ids, '
      "group_concat(pc.full_name, ', ') AS participant_label "
      'FROM interventions i '
      'JOIN clients c ON c.id = i.client_id '
      'LEFT JOIN case_records cr ON cr.id = i.case_id '
      'LEFT JOIN intervention_participants ip ON ip.intervention_id = i.id '
      'LEFT JOIN clients pc ON pc.id = ip.client_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'GROUP BY i.id '
      'ORDER BY i.start_date DESC, i.id DESC',
      args,
    );
    return rows.map(Intervention.fromMap).toList();
  }

  Future<Intervention> _getByIdIn(DatabaseExecutor executor, int id) async {
    final rows = await executor.rawQuery(
      'SELECT i.*, c.full_name AS client_name, cr.case_ref, '
      'group_concat(ip.client_id) AS participant_ids, '
      "group_concat(pc.full_name, ', ') AS participant_label "
      'FROM interventions i '
      'JOIN clients c ON c.id = i.client_id '
      'LEFT JOIN case_records cr ON cr.id = i.case_id '
      'LEFT JOIN intervention_participants ip ON ip.intervention_id = i.id '
      'LEFT JOIN clients pc ON pc.id = ip.client_id '
      'WHERE i.id = ?',
      [id],
    );
    if (rows.isEmpty) throw NotFoundException('Intervention not found');
    return Intervention.fromMap(rows.single);
  }

  Future<void> _requireParticipants(
    DatabaseExecutor executor,
    List<int> participantIds,
  ) async {
    for (final clientId in participantIds) {
      await _requireClient(executor, clientId);
    }
  }

  Future<void> _setParticipants(
    DatabaseExecutor executor,
    int interventionId,
    List<int> participantIds,
  ) async {
    await executor.delete(
      'intervention_participants',
      where: 'intervention_id = ?',
      whereArgs: [interventionId],
    );
    for (final clientId in participantIds) {
      await executor.insert('intervention_participants', {
        'intervention_id': interventionId,
        'client_id': clientId,
      });
    }
  }

  List<int> _normalizeParticipants(List<int> ids) {
    final normalized = ids.toSet().toList();
    if (normalized.isEmpty) {
      throw ValidationException('Select at least one learner');
    }
    return normalized;
  }

  String? _validatedCustomType(String type, String? customType) {
    if (type != 'Other') return null;
    return _requireText(customType ?? '', 'Specify intervention type');
  }

  Future<void> _requireClient(DatabaseExecutor executor, int clientId) async {
    final rows = await executor.query(
      'clients',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    if (rows.isEmpty) throw NotFoundException('Selected student not found');
  }

  Future<void> _requireCase(
    DatabaseExecutor executor,
    int? caseId,
    int clientId,
  ) async {
    if (caseId == null) return;
    final rows = await executor.query(
      'case_records',
      columns: ['client_id'],
      where: 'id = ?',
      whereArgs: [caseId],
      limit: 1,
    );
    if (rows.isEmpty) throw NotFoundException('Selected case not found');
    if (rows.single['client_id'] != clientId) {
      throw ValidationException('Selected case belongs to a different student');
    }
  }

  void _validateDates(DateTime startDate, DateTime? targetDate) {
    if (startDate.year < 2000 || startDate.year > 2100) {
      throw ValidationException('Start date must be between 2000 and 2100');
    }
    if (targetDate != null && targetDate.isBefore(startDate)) {
      throw ValidationException(
        'Target date cannot be before the intervention start date',
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
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
