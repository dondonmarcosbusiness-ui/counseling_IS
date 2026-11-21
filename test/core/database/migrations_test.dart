import 'dart:io';

import 'package:counseling_is/core/database/database_factory.dart';
import 'package:counseling_is/core/database/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(initSqliteFfi);

  test(
    'opening an existing v1 database upgrades to current version keeping data',
    () async {
      final dir = Directory.systemTemp.createTempSync('migrate_test');
      final path = '${dir.path}/app.db';
      addTearDown(() => dir.deleteSync(recursive: true));

      // Create a v1 database with one client, then close it.
      var db = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) => applyV1(db),
          singleInstance: false,
        ),
      );
      await db.insert('clients', {
        'reference_no': 'CLI-2026-0001',
        'full_name': 'Ana Cruz',
        'registered_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
      await db.close();

      // Reopen at the current version: the upgrade path must run.
      db = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onCreate: (db, version) => applyAll(db),
          onUpgrade: upgradeSchema,
          singleInstance: false,
        ),
      );

      final clients = await db.query('clients');
      expect(clients, hasLength(1));
      expect(clients.single['full_name'], 'Ana Cruz');
      expect(clients.single['first_name'], isNull);
      expect(clients.single['middle_name'], isNull);
      expect(clients.single['last_name'], isNull);
      expect(clients.single['suffix'], isNull);
      expect(clients.single['grade_section'], isNull);
      expect(clients.single['learner_no'], isNull);
      expect(clients.single['sex'], isNull);
      expect(clients.single['emergency_name'], isNull);
      expect(clients.single['father_name'], isNull);
      expect(clients.single['living_with'], isNull);
      expect(clients.single['screen_suicidal_thoughts'], isNull);

      final clientColumns = await db.rawQuery('PRAGMA table_info(clients)');
      final columnNames = clientColumns.map((column) => column['name']).toSet();
      expect(
        columnNames,
        containsAll([
          'grade_section',
          'learner_no',
          'sex',
          'religion',
          'address',
          'member_tags',
          'hobbies',
          'emergency_name',
          'emergency_contact_no',
          'emergency_address',
          'emergency_job',
          'emergency_relationship',
          'father_name',
          'father_age',
          'father_job',
          'father_workplace',
          'father_education',
          'mother_name',
          'mother_age',
          'mother_job',
          'mother_workplace',
          'mother_education',
          'guardian_name',
          'guardian_age',
          'guardian_job',
          'guardian_workplace',
          'guardian_relationship',
          'living_with',
          'family_income',
          'parents_status',
          'parents_status_detail',
          'screen_no_appetite',
          'screen_cries_often',
          'screen_abuse',
          'screen_self_blame',
          'screen_suicidal_thoughts',
        ]),
      );

      final settings = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'settings'",
      );
      expect(settings, hasLength(1));

      final submissions = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'form_submissions'",
      );
      expect(submissions, hasLength(1));

      final versionRow = await db.rawQuery('PRAGMA user_version');
      expect(versionRow.single.values.first, schemaVersion);

      await db.close();
    },
  );

  test('v4 migration resumes when some columns already exist', () async {
    final dir = Directory.systemTemp.createTempSync('migrate_partial_test');
    final path = '${dir.path}/app.db';
    addTearDown(() => dir.deleteSync(recursive: true));

    var db = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await applyV1(db);
          await applyV2(db);
          await applyV3(db);
        },
        singleInstance: false,
      ),
    );
    await db.insert('clients', {
      'reference_no': 'CLI-2026-0002',
      'full_name': 'Maya Santos',
      'registered_at': '2026-01-02T00:00:00.000Z',
      'updated_at': '2026-01-02T00:00:00.000Z',
    });
    await db.execute('ALTER TABLE clients ADD COLUMN first_name TEXT');
    await db.execute('ALTER TABLE clients ADD COLUMN middle_name TEXT');
    await db.execute('ALTER TABLE clients ADD COLUMN last_name TEXT');
    await db.execute('ALTER TABLE clients ADD COLUMN suffix TEXT');
    await db.close();

    db = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onUpgrade: upgradeSchema,
        singleInstance: false,
      ),
    );

    final clients = await db.query('clients');
    expect(clients, hasLength(1));
    expect(clients.single['full_name'], 'Maya Santos');
    expect(clients.single['first_name'], isNull);
    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.single.values.single, schemaVersion);
    await db.close();
  });

  test('v5 migration resumes when its tables already exist', () async {
    final dir = Directory.systemTemp.createTempSync('migrate_v5_partial_test');
    final path = '${dir.path}/app.db';
    addTearDown(() => dir.deleteSync(recursive: true));

    var db = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await applyV1(db);
          await applyV2(db);
          await applyV3(db);
          await applyV4(db);
        },
        singleInstance: false,
      ),
    );
    await applyV5(db);
    final clientId = await db.insert('clients', {
      'reference_no': 'CLI-2026-0099',
      'full_name': 'Legacy participant',
      'registered_at': '2026-01-02T00:00:00.000Z',
      'updated_at': '2026-01-02T00:00:00.000Z',
    });
    final interventionId = await db.insert('interventions', {
      'client_id': clientId,
      'title': 'Legacy support',
      'intervention_type': 'Academic support',
      'status': 'planned',
      'start_date': '2026-01-02',
      'created_at': '2026-01-02T00:00:00.000Z',
      'updated_at': '2026-01-02T00:00:00.000Z',
    });
    await db.execute('DROP INDEX idx_interventions_status');
    await db.close();

    db = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onUpgrade: upgradeSchema,
        singleInstance: false,
      ),
    );

    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.single.values.single, schemaVersion);
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('interventions', 'case_timeline_events', "
      "'intervention_participants')",
    );
    expect(tables, hasLength(3));
    final participants = await db.query(
      'intervention_participants',
      where: 'intervention_id = ?',
      whereArgs: [interventionId],
    );
    expect(participants.single['client_id'], clientId);
    final columns = await db.rawQuery('PRAGMA table_info(interventions)');
    expect(columns.any((column) => column['name'] == 'custom_type'), isTrue);
    final index = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name = 'idx_interventions_status'",
    );
    expect(index, hasLength(1));
    await db.close();
  });

  test('v7 migration adds writable information sheet columns', () async {
    final dir = Directory.systemTemp.createTempSync('migrate_v7_test');
    final path = '${dir.path}/app.db';
    addTearDown(() => dir.deleteSync(recursive: true));

    var db = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) async {
          await applyV1(db);
          await applyV2(db);
          await applyV3(db);
          await applyV4(db);
          await applyV5(db);
          await applyV6(db);
        },
        singleInstance: false,
      ),
    );
    final clientId = await db.insert('clients', {
      'reference_no': 'CLI-2026-0100',
      'full_name': 'Legacy Student',
      'registered_at': '2026-01-03T00:00:00.000Z',
      'updated_at': '2026-01-03T00:00:00.000Z',
    });
    await db.close();

    db = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onUpgrade: upgradeSchema,
        singleInstance: false,
      ),
    );

    await db.update(
      'clients',
      {
        'grade_section': 'Grade 9 - Sampaguita',
        'learner_no': '123456789012',
        'sex': 'Female',
        'address': 'Purok 3, Carranglan',
        'member_tags': '4Ps, IP',
        'screen_suicidal_thoughts': 'No',
      },
      where: 'id = ?',
      whereArgs: [clientId],
    );
    final row = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [clientId],
    );
    expect(row.single['grade_section'], 'Grade 9 - Sampaguita');
    expect(row.single['learner_no'], '123456789012');
    expect(row.single['screen_suicidal_thoughts'], 'No');
    expect(row.single['father_name'], isNull);

    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.single.values.single, schemaVersion);
    await db.close();
  });

  test('v8 migration adds the batch_id grouping column', () async {
    final dir = Directory.systemTemp.createTempSync('migrate_v8_test');
    final path = '${dir.path}/app.db';
    addTearDown(() => dir.deleteSync(recursive: true));

    // A v7 database with one saved form record.
    var db = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, version) async {
          await applyV1(db);
          await applyV2(db);
          await applyV3(db);
          await applyV4(db);
          await applyV5(db);
          await applyV6(db);
          await applyV7(db);
        },
        singleInstance: false,
      ),
    );
    final clientId = await db.insert('clients', {
      'reference_no': 'CLI-2026-0200',
      'full_name': 'Batch Student',
      'registered_at': '2026-02-01T00:00:00.000Z',
      'updated_at': '2026-02-01T00:00:00.000Z',
    });
    final submissionId = await db.insert('form_submissions', {
      'form_id': 'referral',
      'client_id': clientId,
      'form_data': '{"other_reason":"Before upgrade"}',
      'created_at': '2026-02-01T00:00:00.000Z',
      'updated_at': '2026-02-01T00:00:00.000Z',
    });
    await db.close();

    // Reopen at the current version: v8 must add batch_id.
    db = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onUpgrade: upgradeSchema,
        singleInstance: false,
      ),
    );

    final columns = await db.rawQuery('PRAGMA table_info(form_submissions)');
    expect(columns.map((column) => column['name']), contains('batch_id'));

    final index = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name = 'idx_form_submissions_batch'",
    );
    expect(index, hasLength(1));

    // Existing rows survive with a null batch; new rows accept the column.
    final row = await db.query(
      'form_submissions',
      where: 'id = ?',
      whereArgs: [submissionId],
    );
    expect(row.single['form_data'], '{"other_reason":"Before upgrade"}');
    expect(row.single['batch_id'], isNull);

    await db.update(
      'form_submissions',
      {'batch_id': 'batch-20260201'},
      where: 'id = ?',
      whereArgs: [submissionId],
    );
    final updated = await db.query(
      'form_submissions',
      where: 'id = ?',
      whereArgs: [submissionId],
    );
    expect(updated.single['batch_id'], 'batch-20260201');

    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.single.values.single, schemaVersion);
    await db.close();
  });

  test('applyAll creates every table on a fresh database', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) => applyAll(db),
        singleInstance: false,
      ),
    );

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).toSet();
    expect(
      names,
      containsAll([
        'admins',
        'clients',
        'appointments',
        'counseling_sessions',
        'case_records',
        'audit_logs',
        'settings',
        'form_submissions',
        'interventions',
        'intervention_participants',
        'case_timeline_events',
      ]),
    );

    await db.close();
  });
}
