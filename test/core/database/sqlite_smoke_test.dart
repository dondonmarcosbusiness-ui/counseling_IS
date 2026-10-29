import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Phase 2 smoke test: prove that sqflite_common_ffi can open a real SQLite
/// database on this desktop, enforce foreign keys, run a transaction, and
/// persist data across reopen. This is the critical gate before Phase 3.
void main() {
  sqfliteFfiInit();

  test('ffi init and open in-memory database', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    expect(db.isOpen, isTrue);
    await db.close();
  });

  test('foreign keys are OFF by default and can be enabled', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final before = await db.rawQuery('PRAGMA foreign_keys');
    // SQLite defaults foreign_keys to OFF (0).
    expect(before.first.values.first, 0);

    await db.execute('PRAGMA foreign_keys = ON');
    final after = await db.rawQuery('PRAGMA foreign_keys');
    expect(after.first.values.first, 1);
    await db.close();
  });

  test('schema with FK restrict, transaction rollback, and persistence', () async {
    final path = 'test_persistence.db';
    await databaseFactoryFfi.deleteDatabase(path);

    Future<Database> open() => databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE clients (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  reference_no TEXT NOT NULL UNIQUE,
                  full_name TEXT NOT NULL
                )
              ''');
              await db.execute('''
                CREATE TABLE appointments (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  client_id INTEGER NOT NULL
                    REFERENCES clients(id) ON DELETE RESTRICT
                )
              ''');
            },
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          ),
        );

    var db = await open();

    // Insert a client.
    final clientId = await db.insert('clients', {
      'reference_no': 'CLI-2026-0001',
      'full_name': 'Fictional Client',
    });
    expect(clientId, 1);

    // Duplicate reference_no must fail (UNIQUE constraint).
    expect(
      () => db.insert('clients', {
        'reference_no': 'CLI-2026-0001',
        'full_name': 'Another Name',
      }),
      throwsA(isA<DatabaseException>()),
    );

    // Transaction rollback: insert appointment then force an error.
    // The whole transaction must roll back, leaving 0 appointments.
    await expectLater(
      db.transaction((txn) async {
        await txn.insert('appointments', {'client_id': clientId});
        // Violates NOT NULL -> whole transaction should roll back.
        await txn.insert('appointments', {'client_id': null});
      }),
      throwsA(isA<DatabaseException>()),
    );

    final apptCount =
        await db.rawQuery('SELECT COUNT(*) AS c FROM appointments');
    expect(apptCount.first['c'], 0,
        reason: 'transaction should have rolled back');

    // Insert a valid appointment that survives, so FK RESTRICT has a child row.
    await db.insert('appointments', {'client_id': clientId});

    await db.close();

    // Reopen to prove data persisted to disk (not just in-memory).
    db = await open();
    final rows = await db.query('clients');
    expect(rows, hasLength(1));
    expect(rows.first['reference_no'], 'CLI-2026-0001');

    // FK RESTRICT: deleting a referenced client must fail.
    expect(
      () => db.delete('clients', where: 'id = ?', whereArgs: [clientId]),
      throwsA(isA<DatabaseException>()),
    );

    await db.close();
    await databaseFactoryFfi.deleteDatabase(path);
  });
}
