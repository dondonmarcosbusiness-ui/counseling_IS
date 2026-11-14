import 'dart:convert';

import 'package:counseling_is/core/audit/audit_logger.dart';
import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/time.dart';
import 'package:counseling_is/features/forms/domain/form_submission.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FormSubmissionRepository {
  FormSubmissionRepository(this._db, {AuditLogger? auditLogger})
    : _audit = auditLogger ?? AuditLogger(_db);

  final Database _db;
  final AuditLogger _audit;

  Future<FormSubmission> create({
    required String formId,
    required Map<String, Object?> data,
    int? clientId,
  }) async {
    final normalizedId = formId.trim();
    if (normalizedId.isEmpty) {
      throw ValidationException('Form type is required');
    }
    final now = nowUtcIso();
    final id = await _db.transaction((txn) async {
      final id = await txn.insert('form_submissions', {
        'form_id': normalizedId,
        'client_id': clientId,
        'form_data': jsonEncode(data),
        'created_at': now,
        'updated_at': now,
      });
      await _audit.record(
        action: 'created',
        entityType: 'form_submission',
        entityId: id,
        executor: txn,
      );
      return id;
    });
    return _getById(id);
  }

  Future<FormSubmission> update(FormSubmission submission) async {
    final id = submission.id;
    if (id == null) {
      throw ValidationException('Submission id is required for update');
    }
    await _db.transaction((txn) async {
      final changed = await txn.update(
        'form_submissions',
        {
          'form_id': submission.formId,
          'client_id': submission.clientId,
          'form_data': jsonEncode(submission.data),
          'updated_at': nowUtcIso(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw NotFoundException('Form record not found');
      await _audit.record(
        action: 'updated',
        entityType: 'form_submission',
        entityId: id,
        executor: txn,
      );
    });
    return _getById(id);
  }

  Future<List<FormSubmission>> list({
    String? searchText,
    String? formId,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    final normalizedFormId = formId?.trim();
    if (normalizedFormId != null && normalizedFormId.isNotEmpty) {
      clauses.add('f.form_id = ?');
      args.add(normalizedFormId);
    }
    final text = searchText?.trim();
    if (text != null && text.isNotEmpty) {
      clauses.add(
        '(instr(lower(COALESCE(c.full_name, \'\')), lower(?)) > 0 '
        'OR instr(lower(f.form_id), lower(?)) > 0)',
      );
      args.addAll([text, text]);
    }
    final rows = await _db.rawQuery(
      'SELECT f.*, c.full_name AS client_name '
      'FROM form_submissions f '
      'LEFT JOIN clients c ON c.id = f.client_id '
      '${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'} '
      'ORDER BY f.updated_at DESC, f.id DESC',
      args,
    );
    return rows.map(FormSubmission.fromMap).toList();
  }

  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      final changed = await txn.delete(
        'form_submissions',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw NotFoundException('Form record not found');
      await _audit.record(
        action: 'deleted',
        entityType: 'form_submission',
        entityId: id,
        executor: txn,
      );
    });
  }

  Future<void> deleteMany(Iterable<int> ids) async {
    final submissionIds = ids.toSet().toList();
    if (submissionIds.isEmpty) return;
    await _db.transaction((txn) async {
      final placeholders = List.filled(submissionIds.length, '?').join(', ');
      final changed = await txn.delete(
        'form_submissions',
        where: 'id IN ($placeholders)',
        whereArgs: submissionIds,
      );
      if (changed != submissionIds.length) {
        throw NotFoundException('One or more form records could not be found');
      }
      await _audit.record(
        action: 'bulk_deleted',
        entityType: 'form_submission',
        detail: '${submissionIds.length} records',
        executor: txn,
      );
    });
  }

  Future<FormSubmission> _getById(int id) async {
    final rows = await _db.rawQuery(
      'SELECT f.*, c.full_name AS client_name '
      'FROM form_submissions f '
      'LEFT JOIN clients c ON c.id = f.client_id '
      'WHERE f.id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) throw NotFoundException('Form record not found');
    return FormSubmission.fromMap(rows.single);
  }
}
