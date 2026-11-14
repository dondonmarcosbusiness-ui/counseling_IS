import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/features/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late SettingsRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('returns the default when nothing is stored', () async {
    expect(await repo.getIdleTimeoutMinutes(),
        SettingsRepository.idleTimeoutDefault);
  });

  test('round-trips a stored value', () async {
    await repo.setIdleTimeoutMinutes(30);
    expect(await repo.getIdleTimeoutMinutes(), 30);

    await repo.setIdleTimeoutMinutes(5);
    expect(await repo.getIdleTimeoutMinutes(), 5);
  });

  test('rejects values outside the allowed range', () async {
    await expectLater(
      repo.setIdleTimeoutMinutes(0),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      repo.setIdleTimeoutMinutes(121),
      throwsA(isA<ValidationException>()),
    );
  });

  test('repairs invalid values stored directly in the table', () async {
    await db.insert(
      'settings',
      {
        'key': SettingsRepository.idleTimeoutKey,
        'value': '999',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    expect(await repo.getIdleTimeoutMinutes(), 120);

    await db.insert(
      'settings',
      {
        'key': SettingsRepository.idleTimeoutKey,
        'value': 'not-a-number',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    expect(await repo.getIdleTimeoutMinutes(),
        SettingsRepository.idleTimeoutDefault);
  });
}
