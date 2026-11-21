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
    this.gradeSection,
    this.learnerNo,
    this.sex,
    this.religion,
    this.address,
    this.memberTags,
    this.hobbies,
    this.emergencyName,
    this.emergencyContactNo,
    this.emergencyAddress,
    this.emergencyJob,
    this.emergencyRelationship,
    this.fatherName,
    this.fatherAge,
    this.fatherJob,
    this.fatherWorkplace,
    this.fatherEducation,
    this.motherName,
    this.motherAge,
    this.motherJob,
    this.motherWorkplace,
    this.motherEducation,
    this.guardianName,
    this.guardianAge,
    this.guardianJob,
    this.guardianWorkplace,
    this.guardianRelationship,
    this.livingWith,
    this.familyIncome,
    this.parentsStatus,
    this.parentsStatusDetail,
    this.screenNoAppetite,
    this.screenCriesOften,
    this.screenAbuse,
    this.screenSelfBlame,
    this.screenSuicidalThoughts,
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
  final String? gradeSection;
  final String? learnerNo;
  final String? sex;
  final String? religion;
  final String? address;
  final String? memberTags;
  final String? hobbies;
  final String? emergencyName;
  final String? emergencyContactNo;
  final String? emergencyAddress;
  final String? emergencyJob;
  final String? emergencyRelationship;
  final String? fatherName;
  final String? fatherAge;
  final String? fatherJob;
  final String? fatherWorkplace;
  final String? fatherEducation;
  final String? motherName;
  final String? motherAge;
  final String? motherJob;
  final String? motherWorkplace;
  final String? motherEducation;
  final String? guardianName;
  final String? guardianAge;
  final String? guardianJob;
  final String? guardianWorkplace;
  final String? guardianRelationship;
  final String? livingWith;
  final String? familyIncome;
  final String? parentsStatus;
  final String? parentsStatusDetail;
  final String? screenNoAppetite;
  final String? screenCriesOften;
  final String? screenAbuse;
  final String? screenSelfBlame;
  final String? screenSuicidalThoughts;
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
        'grade_section': _emptyToNull(input.gradeSection),
        'learner_no': _emptyToNull(input.learnerNo),
        'sex': _emptyToNull(input.sex),
        'religion': _emptyToNull(input.religion),
        'address': _emptyToNull(input.address),
        'member_tags': _emptyToNull(input.memberTags),
        'hobbies': _emptyToNull(input.hobbies),
        'emergency_name': _emptyToNull(input.emergencyName),
        'emergency_contact_no': _emptyToNull(input.emergencyContactNo),
        'emergency_address': _emptyToNull(input.emergencyAddress),
        'emergency_job': _emptyToNull(input.emergencyJob),
        'emergency_relationship': _emptyToNull(input.emergencyRelationship),
        'father_name': _emptyToNull(input.fatherName),
        'father_age': _emptyToNull(input.fatherAge),
        'father_job': _emptyToNull(input.fatherJob),
        'father_workplace': _emptyToNull(input.fatherWorkplace),
        'father_education': _emptyToNull(input.fatherEducation),
        'mother_name': _emptyToNull(input.motherName),
        'mother_age': _emptyToNull(input.motherAge),
        'mother_job': _emptyToNull(input.motherJob),
        'mother_workplace': _emptyToNull(input.motherWorkplace),
        'mother_education': _emptyToNull(input.motherEducation),
        'guardian_name': _emptyToNull(input.guardianName),
        'guardian_age': _emptyToNull(input.guardianAge),
        'guardian_job': _emptyToNull(input.guardianJob),
        'guardian_workplace': _emptyToNull(input.guardianWorkplace),
        'guardian_relationship': _emptyToNull(input.guardianRelationship),
        'living_with': _emptyToNull(input.livingWith),
        'family_income': _emptyToNull(input.familyIncome),
        'parents_status': _emptyToNull(input.parentsStatus),
        'parents_status_detail': _emptyToNull(input.parentsStatusDetail),
        'screen_no_appetite': _emptyToNull(input.screenNoAppetite),
        'screen_cries_often': _emptyToNull(input.screenCriesOften),
        'screen_abuse': _emptyToNull(input.screenAbuse),
        'screen_self_blame': _emptyToNull(input.screenSelfBlame),
        'screen_suicidal_thoughts': _emptyToNull(input.screenSuicidalThoughts),
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
          'grade_section': _emptyToNull(client.gradeSection),
          'learner_no': _emptyToNull(client.learnerNo),
          'sex': _emptyToNull(client.sex),
          'religion': _emptyToNull(client.religion),
          'address': _emptyToNull(client.address),
          'member_tags': _emptyToNull(client.memberTags),
          'hobbies': _emptyToNull(client.hobbies),
          'emergency_name': _emptyToNull(client.emergencyName),
          'emergency_contact_no': _emptyToNull(client.emergencyContactNo),
          'emergency_address': _emptyToNull(client.emergencyAddress),
          'emergency_job': _emptyToNull(client.emergencyJob),
          'emergency_relationship': _emptyToNull(client.emergencyRelationship),
          'father_name': _emptyToNull(client.fatherName),
          'father_age': _emptyToNull(client.fatherAge),
          'father_job': _emptyToNull(client.fatherJob),
          'father_workplace': _emptyToNull(client.fatherWorkplace),
          'father_education': _emptyToNull(client.fatherEducation),
          'mother_name': _emptyToNull(client.motherName),
          'mother_age': _emptyToNull(client.motherAge),
          'mother_job': _emptyToNull(client.motherJob),
          'mother_workplace': _emptyToNull(client.motherWorkplace),
          'mother_education': _emptyToNull(client.motherEducation),
          'guardian_name': _emptyToNull(client.guardianName),
          'guardian_age': _emptyToNull(client.guardianAge),
          'guardian_job': _emptyToNull(client.guardianJob),
          'guardian_workplace': _emptyToNull(client.guardianWorkplace),
          'guardian_relationship': _emptyToNull(client.guardianRelationship),
          'living_with': _emptyToNull(client.livingWith),
          'family_income': _emptyToNull(client.familyIncome),
          'parents_status': _emptyToNull(client.parentsStatus),
          'parents_status_detail': _emptyToNull(client.parentsStatusDetail),
          'screen_no_appetite': _emptyToNull(client.screenNoAppetite),
          'screen_cries_often': _emptyToNull(client.screenCriesOften),
          'screen_abuse': _emptyToNull(client.screenAbuse),
          'screen_self_blame': _emptyToNull(client.screenSelfBlame),
          'screen_suicidal_thoughts': _emptyToNull(
            client.screenSuicidalThoughts,
          ),
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
