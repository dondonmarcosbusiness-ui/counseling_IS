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

  /// Data of the most recently saved [formId] record linked to [clientId],
  /// used to auto-fill personal information into other forms.
  Future<Map<String, Object?>?> latestDataForClient(
    int clientId,
    String formId,
  ) async {
    final rows = await _db.query(
      'form_submissions',
      columns: ['form_data'],
      where: 'client_id = ? AND form_id = ?',
      whereArgs: [clientId, formId],
      orderBy: 'updated_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final decoded = jsonDecode(rows.first['form_data'] as String);
    return decoded is Map ? Map<String, Object?>.from(decoded) : null;
  }

  /// Most recent record of [formId] linked to [clientId], used to update an
  /// existing record instead of creating a duplicate on a batch save.
  Future<FormSubmission?> latestForClient(int clientId, String formId) async {
    final rows = await _db.rawQuery(
      'SELECT f.*, c.full_name AS client_name '
      'FROM form_submissions f '
      'LEFT JOIN clients c ON c.id = f.client_id '
      'WHERE f.client_id = ? AND f.form_id = ? '
      'ORDER BY f.updated_at DESC, f.id DESC '
      'LIMIT 1',
      [clientId, formId],
    );
    if (rows.isEmpty) return null;
    return FormSubmission.fromMap(rows.single);
  }

  /// Saves [dataByForm] as one batch in a single transaction: each form
  /// keeps its own record, linked to [clientId] and grouped under
  /// [batchId]. A form listed in [existingIdsByForm] is updated in place.
  /// Returns the saved records keyed by form ID.
  Future<Map<String, FormSubmission>> saveBatch({
    required int clientId,
    required String batchId,
    required Map<String, Map<String, Object?>> dataByForm,
    Map<String, int?> existingIdsByForm = const {},
  }) async {
    final normalizedBatch = batchId.trim();
    if (normalizedBatch.isEmpty) {
      throw ValidationException('Batch id is required');
    }
    if (dataByForm.isEmpty) {
      throw ValidationException('No forms to save in this batch');
    }
    final savedIds = <String, int>{};
    await _db.transaction((txn) async {
      final now = nowUtcIso();
      for (final entry in dataByForm.entries) {
        final formId = entry.key.trim();
        if (formId.isEmpty) {
          throw ValidationException('Form type is required');
        }
        final existingId = existingIdsByForm[formId];
        if (existingId == null) {
          final id = await txn.insert('form_submissions', {
            'form_id': formId,
            'client_id': clientId,
            'form_data': jsonEncode(entry.value),
            'batch_id': normalizedBatch,
            'created_at': now,
            'updated_at': now,
          });
          savedIds[formId] = id;
          await _audit.record(
            action: 'created',
            entityType: 'form_submission',
            entityId: id,
            executor: txn,
          );
        } else {
          final changed = await txn.update(
            'form_submissions',
            {
              'client_id': clientId,
              'form_data': jsonEncode(entry.value),
              'batch_id': normalizedBatch,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [existingId],
          );
          if (changed == 0) throw NotFoundException('Form record not found');
          savedIds[formId] = existingId;
          await _audit.record(
            action: 'updated',
            entityType: 'form_submission',
            entityId: existingId,
            executor: txn,
          );
        }
      }
    });

    final saved = <String, FormSubmission>{};
    for (final entry in savedIds.entries) {
      saved[entry.key] = await _getById(entry.value);
    }
    return saved;
  }

  /// Saved batches, newest first, with the student and form IDs they group.
  Future<List<FormBatchSummary>> listBatches() async {
    final rows = await _db.rawQuery(
      'SELECT f.batch_id, f.client_id, c.full_name AS client_name, '
      'COUNT(*) AS form_count, GROUP_CONCAT(f.form_id) AS form_ids, '
      'MAX(f.updated_at) AS last_saved_at '
      'FROM form_submissions f '
      'LEFT JOIN clients c ON c.id = f.client_id '
      'WHERE f.batch_id IS NOT NULL '
      'GROUP BY f.batch_id '
      'ORDER BY last_saved_at DESC, f.batch_id DESC',
    );
    return rows.map(FormBatchSummary.fromRow).toList();
  }

  /// Records of one batch in creation order; the screen orders them by the
  /// form catalog when it rebuilds the merged page.
  Future<List<FormSubmission>> batchSubmissions(String batchId) async {
    final rows = await _db.rawQuery(
      'SELECT f.*, c.full_name AS client_name '
      'FROM form_submissions f '
      'LEFT JOIN clients c ON c.id = f.client_id '
      'WHERE f.batch_id = ? '
      'ORDER BY f.id ASC',
      [batchId],
    );
    return rows.map(FormSubmission.fromMap).toList();
  }

  /// Removes a batch grouping. The records themselves stay saved and stay
  /// linked to their student — only the grouping is dropped.
  Future<void> unlinkBatch(String batchId) async {
    await _db.transaction((txn) async {
      final changed = await txn.update(
        'form_submissions',
        {'batch_id': null},
        where: 'batch_id = ?',
        whereArgs: [batchId],
      );
      if (changed == 0) throw NotFoundException('Batch not found');
      await _audit.record(
        action: 'unlinked',
        entityType: 'form_batch',
        detail: '$changed records',
        executor: txn,
      );
    });
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
