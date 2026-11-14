import 'dart:io';

import 'package:counseling_is/core/database/migrations.dart';
import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/features/backup/data/backup_service.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Directory dir;
  late String dbPath;
  late Database db;
  late BackupService service;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('backup_test');
    dbPath = '${dir.path}/app.db';
    db = await openTestDatabase(path: dbPath);
    await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Ana Cruz'));
    service = BackupService(db, dbPath);
  });

  tearDown(() async {
    if (db.isOpen) await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('createBackup writes a consistent openable copy', () async {
    final dest = '${dir.path}/copy.db';

    final result = await service.createBackup(dest);

    expect(result, dest);
    expect(File(dest).existsSync(), isTrue);

    final copy = await databaseFactoryFfiNoIsolate.openDatabase(
      dest,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final clients = await copy.query('clients');
    expect(clients, hasLength(1));
    expect(clients.single['full_name'], 'Ana Cruz');

    final settings = await copy.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'settings'",
    );
    expect(settings, hasLength(1));
    await copy.close();
  });

  test('createBackup rejects an existing destination file', () async {
    final dest = '${dir.path}/exists.db';
    File(dest).writeAsStringSync('not a backup');

    await expectLater(
      service.createBackup(dest),
      throwsA(isA<ValidationException>()),
    );
  });

  test('createBackup rejects overwriting the live database', () async {
    await expectLater(
      service.createBackup(dbPath),
      throwsA(isA<ValidationException>()),
    );
  });

  test(
    'validateBackup accepts a good backup and reports its contents',
    () async {
      final dest = '${dir.path}/copy.db';
      await service.createBackup(dest);

      final info = await service.validateBackup(dest);

      expect(info.schemaVersion, schemaVersion);
      expect(info.clients, 1);
      expect(info.appointments, 0);
    },
  );

  test('validateBackup accepts an older schema that can be upgraded', () async {
    final legacyPath = '${dir.path}\\legacy-v4.db';
    final legacy = await databaseFactoryFfiNoIsolate.openDatabase(
      legacyPath,
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
    await legacy.close();

    final info = await service.validateBackup(legacyPath);

    expect(info.schemaVersion, 4);
  });

  test('validateBackup rejects the live database path', () async {
    await expectLater(
      service.validateBackup(dbPath),
      throwsA(isA<ValidationException>()),
    );
  });

  test('validateBackup rejects a foreign database', () async {
    final foreign = '${dir.path}/foreign.db';
    final foreignDb = await databaseFactoryFfiNoIsolate.openDatabase(
      foreign,
      options: OpenDatabaseOptions(singleInstance: false),
    );

    await expectLater(
      service.validateBackup(foreign),
      throwsA(isA<ValidationException>()),
    );
    await foreignDb.close();
  });

  test('validateBackup rejects a file that is not a database', () async {
    final junk = '${dir.path}/junk.db';
    File(junk).writeAsStringSync('this is not a database');

    await expectLater(
      service.validateBackup(junk),
      throwsA(isA<ValidationException>()),
    );
  });

  test(
    'restoreFrom replaces the live database with the backup state',
    () async {
      final dest = '${dir.path}/copy.db';
      await service.createBackup(dest);

      // Diverge from the backup: the live database gains a second client.
      await ClientRepository(db)
          .create(const CreateClientInput(fullName: 'Ben Reyes'));
      expect(await ClientRepository(db).count(), 2);

      await service.restoreFrom(dest);
      expect(db.isOpen, isFalse);

      final reopened = await openTestDatabase(path: dbPath);
      final names = await reopened
          .query('clients', columns: ['full_name'])
          .then((rows) => rows.map((row) => row['full_name']).toList());
      expect(names, ['Ana Cruz']);
      await reopened.close();
    },
  );
}
