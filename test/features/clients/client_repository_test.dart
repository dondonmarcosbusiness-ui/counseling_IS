import 'dart:io';

import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late ClientRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = ClientRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create assigns sequential reference numbers', () async {
    final first = await repo.create(
      const CreateClientInput(fullName: 'Ana Cruz'),
    );
    final second = await repo.create(
      const CreateClientInput(fullName: 'Ben Santos'),
    );

    final year = DateTime.now().year;
    expect(first.referenceNo, 'CLI-$year-0001');
    expect(second.referenceNo, 'CLI-$year-0002');
    expect(first.status, ClientStatus.active);
    expect(first.id, isNotNull);
  });

  test('create rejects blank full name', () async {
    await expectLater(
      repo.create(const CreateClientInput(fullName: '   ')),
      throwsA(isA<ValidationException>()),
    );
  });

  test('create rejects invalid email', () async {
    await expectLater(
      repo.create(
        const CreateClientInput(fullName: 'Ana', email: 'not-an-email'),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('stores every field of the information sheet', () async {
    final created = await repo.create(
      const CreateClientInput(
        fullName: 'Maria Clara Santos',
        firstName: 'Maria Clara',
        middleName: 'Reyes',
        lastName: 'Santos',
        gradeSection: 'Grade 9 - Sampaguita',
        learnerNo: '123456789012',
        sex: 'Female',
        religion: 'Roman Catholic',
        address: 'Purok 3, Carranglan, Nueva Ecija',
        memberTags: '4Ps, IP',
        hobbies: 'Reading, basketball',
        emergencyName: 'Juan Santos',
        emergencyContactNo: '09171234567',
        emergencyAddress: 'Purok 3, Carranglan, Nueva Ecija',
        emergencyJob: 'Farmer',
        emergencyRelationship: 'Father',
        fatherName: 'Juan Dela Santos',
        fatherAge: '45',
        fatherJob: 'Farmer',
        fatherWorkplace: 'Carranglan',
        fatherEducation: 'High School Graduate',
        motherName: 'Rosa Reyes',
        motherAge: '42',
        motherJob: 'Vendor',
        motherWorkplace: 'Carranglan market',
        motherEducation: 'College Graduate',
        guardianName: 'Benita Cruz',
        guardianAge: '67',
        guardianJob: 'None',
        guardianWorkplace: 'Home',
        guardianRelationship: 'Grandmother',
        livingWith: 'Relatives',
        familyIncome: '₱10,001 – ₱20,000',
        parentsStatus: 'Married but separated',
        parentsStatusDetail: 'Father lives in another town',
        screenNoAppetite: 'No',
        screenCriesOften: 'Yes',
        screenAbuse: 'No',
        screenSelfBlame: 'Yes',
        screenSuicidalThoughts: 'No',
      ),
    );

    final fetched = await repo.getById(created.id!);
    expect(fetched.gradeSection, 'Grade 9 - Sampaguita');
    expect(fetched.learnerNo, '123456789012');
    expect(fetched.sex, 'Female');
    expect(fetched.religion, 'Roman Catholic');
    expect(fetched.address, 'Purok 3, Carranglan, Nueva Ecija');
    expect(fetched.memberTags, '4Ps, IP');
    expect(fetched.memberTagList, ['4Ps', 'IP']);
    expect(fetched.hobbies, 'Reading, basketball');
    expect(fetched.emergencyName, 'Juan Santos');
    expect(fetched.emergencyContactNo, '09171234567');
    expect(fetched.emergencyRelationship, 'Father');
    expect(fetched.fatherName, 'Juan Dela Santos');
    expect(fetched.fatherEducation, 'High School Graduate');
    expect(fetched.motherName, 'Rosa Reyes');
    expect(fetched.motherEducation, 'College Graduate');
    expect(fetched.guardianRelationship, 'Grandmother');
    expect(fetched.livingWith, 'Relatives');
    expect(fetched.familyIncome, '₱10,001 – ₱20,000');
    expect(fetched.parentsStatus, 'Married but separated');
    expect(fetched.parentsStatusDetail, 'Father lives in another town');
    expect(fetched.screenCriesOften, 'Yes');
    expect(fetched.screenSuicidalThoughts, 'No');
  });

  test('update clears information sheet fields that were emptied', () async {
    final created = await repo.create(
      const CreateClientInput(
        fullName: 'Temp Student',
        gradeSection: 'Grade 10',
        screenCriesOften: 'Yes',
      ),
    );

    final updated = await repo.update(
      Client(
        id: created.id,
        referenceNo: created.referenceNo,
        fullName: created.fullName,
        gradeSection: null,
        screenCriesOften: null,
        status: created.status,
        registeredAt: created.registeredAt,
        updatedAt: created.updatedAt,
      ),
    );

    expect(updated.gradeSection, isNull);
    expect(updated.screenCriesOften, isNull);
    final fetched = await repo.getById(created.id!);
    expect(fetched.gradeSection, isNull);
    expect(fetched.screenCriesOften, isNull);
  });

  test('getById returns the created client', () async {
    final created = await repo.create(
      const CreateClientInput(fullName: 'Carla Reyes'),
    );
    final fetched = await repo.getById(created.id!);

    expect(fetched.referenceNo, created.referenceNo);
    expect(fetched.fullName, 'Carla Reyes');
    expect(fetched.registeredAt, created.registeredAt);
    expect(
      DateTime.now().difference(fetched.registeredAt).inMinutes,
      lessThan(5),
      reason: 'registeredAt should be a fresh timestamp',
    );
  });

  test('getById throws for missing id', () async {
    await expectLater(repo.getById(9999), throwsA(isA<NotFoundException>()));
  });

  test('update modifies fields and bumps updated_at', () async {
    final created = await repo.create(
      const CreateClientInput(fullName: 'Dan Old'),
    );
    final updated = await repo.update(
      created.copyWith(fullName: 'Dan Updated', phone: '555-0100'),
    );

    expect(updated.fullName, 'Dan Updated');
    expect(updated.phone, '555-0100');
    expect(
      updated.updatedAt.difference(created.registeredAt).inMilliseconds,
      greaterThanOrEqualTo(0),
    );

    final refetched = await repo.getById(created.id!);
    expect(refetched.fullName, 'Dan Updated');
  });

  test('archive and restore change status', () async {
    final created = await repo.create(
      const CreateClientInput(fullName: 'Eve Archer'),
    );
    await repo.archive(created.id!);

    var fetched = await repo.getById(created.id!);
    expect(fetched.status, ClientStatus.archived);
    expect(fetched.isArchived, isTrue);

    await repo.restore(created.id!);
    fetched = await repo.getById(created.id!);
    expect(fetched.status, ClientStatus.active);
  });

  test('deleteMany removes unlinked clients', () async {
    final first = await repo.create(const CreateClientInput(fullName: 'First'));
    final second = await repo.create(
      const CreateClientInput(fullName: 'Second'),
    );

    await repo.deleteMany([first.id!, second.id!, first.id!]);

    expect(await repo.count(), 0);
  });

  test(
    'deleteMany rejects linked clients without deleting any clients',
    () async {
      final linked = await repo.create(
        const CreateClientInput(fullName: 'Linked client'),
      );
      final unlinked = await repo.create(
        const CreateClientInput(fullName: 'Unlinked client'),
      );
      final now = DateTime.now().toUtc().toIso8601String();
      final year = DateTime.now().toUtc().year;
      await db.insert('case_records', {
        'case_ref': 'CASE-$year-0001',
        'client_id': linked.id,
        'opened_at': now,
        'status': 'open',
        'created_at': now,
        'updated_at': now,
      });

      await expectLater(
        repo.deleteMany([linked.id!, unlinked.id!]),
        throwsA(
          isA<ConflictException>().having(
            (error) => error.message,
            'message',
            contains('Archive them instead'),
          ),
        ),
      );
      expect(await repo.count(), 2);
    },
  );

  test('deleteMany protects group intervention participants', () async {
    final lead = await repo.create(const CreateClientInput(fullName: 'Lead'));
    final participant = await repo.create(
      const CreateClientInput(fullName: 'Participant'),
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final interventionId = await db.insert('interventions', {
      'client_id': lead.id,
      'title': 'Group session',
      'intervention_type': 'Group counseling',
      'status': 'planned',
      'start_date': '2026-02-01',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('intervention_participants', {
      'intervention_id': interventionId,
      'client_id': lead.id,
    });
    await db.insert('intervention_participants', {
      'intervention_id': interventionId,
      'client_id': participant.id,
    });

    await expectLater(
      repo.deleteMany([participant.id!]),
      throwsA(isA<ConflictException>()),
    );
    expect(await repo.count(), 2);
  });

  test('search by name is case-insensitive and matches reference', () async {
    await repo.create(const CreateClientInput(fullName: 'Grace Lee'));
    await repo.create(const CreateClientInput(fullName: 'Henry Tan'));

    final byName = await repo.search(const ClientQuery(searchText: 'grace'));
    expect(byName, hasLength(1));
    expect(byName.single.fullName, 'Grace Lee');

    final year = DateTime.now().year;
    final byRef = await repo.search(ClientQuery(searchText: 'CLI-$year-000'));
    expect(byRef, hasLength(2));
  });

  test('search by status filters archived records', () async {
    final a = await repo.create(
      const CreateClientInput(fullName: 'Active One'),
    );
    final b = await repo.create(
      const CreateClientInput(fullName: 'Archived Two'),
    );
    await repo.archive(b.id!);

    final active = await repo.search(
      const ClientQuery(status: ClientStatus.active),
    );
    final archived = await repo.search(
      const ClientQuery(status: ClientStatus.archived),
    );

    expect(active.map((c) => c.id), contains(a.id));
    expect(active.map((c) => c.id), isNot(contains(b.id)));
    expect(archived.map((c) => c.id), [b.id]);
  });

  test('search text does not treat LIKE wildcards as wildcards', () async {
    await repo.create(const CreateClientInput(fullName: 'Percent Guy'));
    final rows = await repo.search(const ClientQuery(searchText: '%'));
    expect(rows, isEmpty);
  });

  test('count returns totals by status', () async {
    final a = await repo.create(const CreateClientInput(fullName: 'One'));
    await repo.create(const CreateClientInput(fullName: 'Two'));
    await repo.archive(a.id!);

    expect(await repo.count(), 2);
    expect(await repo.count(status: ClientStatus.active), 1);
    expect(await repo.count(status: ClientStatus.archived), 1);
  });

  test('foreign key prevents deleting a referenced client', () async {
    final client = await repo.create(
      const CreateClientInput(fullName: 'Linked Client'),
    );
    final year = DateTime.now().toUtc().year;
    await db.insert('case_records', {
      'case_ref': 'CASE-$year-0001',
      'client_id': client.id,
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'open',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    expect(
      () => db.delete('clients', where: 'id = ?', whereArgs: [client.id]),
      throwsA(isA<DatabaseException>()),
    );

    final count = await repo.count();
    expect(count, 1);
  });

  test('database persists data after close and reopen', () async {
    final dir = await Directory.systemTemp.createTemp('counseling_test_');
    final path = '${dir.path}/persist.db';
    try {
      final db1 = await openTestDatabase(path: path);
      await ClientRepository(db1)
          .create(const CreateClientInput(fullName: 'Persisted Person'));
      await db1.close();

      final db2 = await openTestDatabase(path: path);
      final rows = await db2.query('clients');
      expect(rows, hasLength(1));
      expect(rows.first['full_name'], 'Persisted Person');
      await db2.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
