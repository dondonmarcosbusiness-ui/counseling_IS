import 'package:counseling_is/core/audit/audit_logger.dart';
import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/time.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CreateClientInput {
  const CreateClientInput({
    this.fullName,
    this.firstName,
    this.middleName,
    this.lastName,
    this.suffix,
    this.phone,
    this.email,
    this.dateOfBirth,
    this.intakeNotes,
  });

  final String? fullName;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? suffix;
  final String? phone;
  final String? email;
  final DateTime? dateOfBirth;
  final String? intakeNotes;
}

class ClientQuery {
  const ClientQuery({this.searchText, this.status});

  final String? searchText;
  final ClientStatus? status;
}

class ClientRepository {
  ClientRepository(this._db, {AuditLogger? auditLogger})
    : _audit = auditLogger ?? AuditLogger(_db);

  final Database _db;
  final AuditLogger _audit;

  Future<Client> create(CreateClientInput input) async {
    final nameParts = _joinName(
      input.firstName,
      input.middleName,
      input.lastName,
      input.suffix,
    );
    final fullName = _requireText(
      nameParts.isEmpty ? input.fullName ?? '' : nameParts,
      'First name',
    );
    _validateContact(input.email, input.phone);
    return _db.transaction((txn) async {
      final referenceNo = await _generateReferenceNo(txn);
      final now = DateTime.now().toUtc();
      final id = await txn.insert('clients', {
        'reference_no': referenceNo,
        'full_name': fullName,
        'first_name': _emptyToNull(input.firstName),
        'middle_name': _emptyToNull(input.middleName),
        'last_name': _emptyToNull(input.lastName),
        'suffix': _emptyToNull(input.suffix),
        'phone': _emptyToNull(input.phone),
        'email': _emptyToNull(input.email),
        'date_of_birth': input.dateOfBirth == null
            ? null
            : dateToDb(input.dateOfBirth!),
        'intake_notes': _emptyToNull(input.intakeNotes),
        'status': ClientStatus.active.dbValue,
        'registered_at': dateTimeToDb(now),
        'updated_at': dateTimeToDb(now),
      });
      final created = await txn.query(
        'clients',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      await _audit.record(
        action: 'created',
        entityType: 'client',
        entityId: id,
        executor: txn,
      );
      return Client.fromMap(created.single);
    });
  }

  Future<Client> update(Client client) async {
    if (client.id == null) {
      throw ValidationException('Student id is required for update');
    }
    final nameParts = _joinName(
      client.firstName,
      client.middleName,
      client.lastName,
      client.suffix,
    );
    final fullName = _requireText(
      nameParts.isEmpty ? client.fullName : nameParts,
      'First name',
    );
    _validateContact(client.email, client.phone);
    return _db.transaction((txn) async {
      final now = DateTime.now().toUtc();
      final changed = await txn.update(
        'clients',
        {
          'full_name': fullName,
          'first_name': _emptyToNull(client.firstName),
          'middle_name': _emptyToNull(client.middleName),
          'last_name': _emptyToNull(client.lastName),
          'suffix': _emptyToNull(client.suffix),
          'phone': _emptyToNull(client.phone),
          'email': _emptyToNull(client.email),
          'date_of_birth': client.dateOfBirth == null
              ? null
              : dateToDb(client.dateOfBirth!),
          'intake_notes': _emptyToNull(client.intakeNotes),
          'status': client.status.dbValue,
          'updated_at': dateTimeToDb(now),
        },
        where: 'id = ?',
        whereArgs: [client.id],
      );
      if (changed == 0) {
        throw NotFoundException('Student not found');
      }
      final rows = await txn.query(
        'clients',
        where: 'id = ?',
        whereArgs: [client.id],
        limit: 1,
      );
      await _audit.record(
        action: 'updated',
        entityType: 'client',
        entityId: client.id,
        executor: txn,
      );
      return Client.fromMap(rows.single);
    });
  }

  Future<Client> getById(int id) async {
    final rows = await _db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw NotFoundException('Student not found');
    return Client.fromMap(rows.single);
  }

  Future<Client> getByReferenceNo(String referenceNo) async {
    final rows = await _db.query(
      'clients',
      where: 'reference_no = ?',
      whereArgs: [referenceNo],
      limit: 1,
    );
    if (rows.isEmpty) throw NotFoundException('Student not found');
    return Client.fromMap(rows.single);
  }

  Future<List<Client>> search(ClientQuery query) async {
    final where = <String>[];
    final args = <Object?>[];

    final status = query.status;
    if (status != null) {
      where.add('status = ?');
      args.add(status.dbValue);
    }

    final text = _emptyToNull(query.searchText);
    if (text != null) {
      final like = '%${_escapeLike(text)}%';
      where.add(
        '(full_name LIKE ? ESCAPE \'\\\' OR reference_no LIKE ? ESCAPE \'\\\' '
        'OR phone LIKE ? ESCAPE \'\\\' OR email LIKE ? ESCAPE \'\\\')',
      );
      args.addAll([like, like, like, like]);
    }

    final rows = await _db.query(
      'clients',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'full_name COLLATE NOCASE ASC',
    );
    return rows.map(Client.fromMap).toList();
  }

  Future<void> setStatus(int id, ClientStatus status) async {
    await _db.transaction((txn) async {
      final changed = await txn.update(
        'clients',
        {'status': status.dbValue, 'updated_at': nowUtcIso()},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw NotFoundException('Student not found');
      await _audit.record(
        action: status == ClientStatus.archived ? 'archived' : 'restored',
        entityType: 'client',
        entityId: id,
        executor: txn,
      );
    });
  }

  Future<void> setStatusForMany(Iterable<int> ids, ClientStatus status) async {
    final clientIds = ids.toSet().toList();
    if (clientIds.isEmpty) return;
    await _db.transaction((txn) async {
      final placeholders = List.filled(clientIds.length, '?').join(', ');
      final changed = await txn.update(
        'clients',
        {'status': status.dbValue, 'updated_at': nowUtcIso()},
        where: 'id IN ($placeholders)',
        whereArgs: clientIds,
      );
      if (changed != clientIds.length) {
        throw NotFoundException('One or more students could not be found');
      }
      await _audit.record(
        action: status == ClientStatus.archived
            ? 'bulk_archived'
            : 'bulk_restored',
        entityType: 'client',
        detail: '${clientIds.length} records',
        executor: txn,
      );
    });
  }

  Future<void> deleteMany(Iterable<int> ids) async {
    final clientIds = ids.toSet().toList();
    if (clientIds.isEmpty) return;
    await _db.transaction((txn) async {
      final placeholders = List.filled(clientIds.length, '?').join(', ');
      final where = 'client_id IN ($placeholders)';
      final tables = [
        ('appointments', 'appointments'),
        ('counseling_sessions', 'sessions'),
        ('case_records', 'cases'),
      ];
      final linkedRecords = <String>[];
      for (final (table, label) in tables) {
        final result = await txn.rawQuery(
          'SELECT COUNT(*) AS count FROM $table WHERE $where',
          clientIds,
        );
        final count = result.single['count'] as int;
        if (count > 0) linkedRecords.add('$count $label');
      }
      final interventionRows = await txn.rawQuery(
        'SELECT COUNT(DISTINCT i.id) AS count FROM interventions i '
        'LEFT JOIN intervention_participants ip ON ip.intervention_id = i.id '
        'WHERE i.client_id IN ($placeholders) '
        'OR ip.client_id IN ($placeholders)',
        [...clientIds, ...clientIds],
      );
      final interventionCount = interventionRows.single['count'] as int;
      if (interventionCount > 0) {
        linkedRecords.add('$interventionCount interventions');
      }
      if (linkedRecords.isNotEmpty) {
        throw ConflictException(
          'Selected students have linked ${linkedRecords.join(', ')}. '
          'Archive them instead to preserve their history.',
        );
      }
      final changed = await txn.delete(
        'clients',
        where: 'id IN ($placeholders)',
        whereArgs: clientIds,
      );
      if (changed != clientIds.length) {
        throw NotFoundException('One or more students could not be found');
      }
      await _audit.record(
        action: 'deleted',
        entityType: 'client',
        detail: '${clientIds.length} records',
        executor: txn,
      );
    });
  }

  Future<void> archive(int id) => setStatus(id, ClientStatus.archived);

  Future<void> restore(int id) => setStatus(id, ClientStatus.active);

  Future<int> count({ClientStatus? status}) async {
    final result = status == null
        ? await _db.rawQuery('SELECT COUNT(*) AS c FROM clients')
        : await _db.rawQuery(
            'SELECT COUNT(*) AS c FROM clients WHERE status = ?',
            [status.dbValue],
          );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<String> _generateReferenceNo(DatabaseExecutor txn) async {
    final year = DateTime.now().toUtc().year;
    final prefix = 'CLI-$year-';
    final rows = await txn.rawQuery(
      'SELECT reference_no FROM clients '
      'WHERE reference_no LIKE ? '
      'ORDER BY reference_no DESC LIMIT 1',
      ['$prefix%'],
    );
    var next = 1;
    if (rows.isNotEmpty) {
      final last = rows.first['reference_no'] as String;
      final seq = int.tryParse(last.substring(prefix.length));
      if (seq != null) next = seq + 1;
    }
    return '$prefix${next.toString().padLeft(4, '0')}';
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

  String _joinName(
    String? firstName,
    String? middleName,
    String? lastName,
    String? suffix,
  ) => [
    firstName,
    middleName,
    lastName,
    suffix,
  ].map(_emptyToNull).whereType<String>().join(' ');

  void _validateContact(String? email, String? phone) {
    final trimmedEmail = email?.trim();
    if (trimmedEmail != null &&
        trimmedEmail.isNotEmpty &&
        !trimmedEmail.contains('@')) {
      throw ValidationException('Email must contain an @ sign');
    }
  }

  String _escapeLike(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
