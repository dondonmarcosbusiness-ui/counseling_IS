import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/security/password_hasher.dart';
import 'package:counseling_is/core/security/session_manager.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:counseling_is/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late AuthRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = AuthRepository(db, hasher: PasswordHasher(logRounds: 4));
  });

  tearDown(() async => db.close());

  AuthController makeController({
    int maxFailedAttempts = 5,
    Duration throttleDelay = const Duration(milliseconds: 100),
    Duration idleTimeout = const Duration(days: 1),
  }) {
    return AuthController(
      repo,
      maxFailedAttempts: maxFailedAttempts,
      throttleDelay: throttleDelay,
      session: SessionManager(onLock: () {}, idleTimeout: idleTimeout),
    );
  }

  test('init reports needsSetup on empty database', () async {
    final auth = makeController();
    await auth.init();
    expect(auth.status, AuthStatus.needsSetup);
    auth.dispose();
  });

  test('setup creates admin and signs in', () async {
    final auth = makeController();
    await auth.init();
    final error = await auth.setup(
      username: 'admin',
      fullName: 'Site Administrator',
      password: 'Password123',
      confirmPassword: 'Password123',
    );
    expect(error, isNull);
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.admin?.username, 'admin');
    expect(await repo.hasAdmin(), isTrue);
    auth.dispose();
  });

  test('setup rejects weak password and creates nothing', () async {
    final auth = makeController();
    await auth.init();
    final error = await auth.setup(
      username: 'admin',
      fullName: 'Site Administrator',
      password: 'short',
      confirmPassword: 'short',
    );
    expect(error, isNotNull);
    expect(auth.status, AuthStatus.needsSetup);
    expect(await repo.hasAdmin(), isFalse);
    auth.dispose();
  });

  test('setup rejects mismatched passwords', () async {
    final auth = makeController();
    await auth.init();
    final error = await auth.setup(
      username: 'admin',
      fullName: 'Site Administrator',
      password: 'Password123',
      confirmPassword: 'Password124',
    );
    expect(error, 'Passwords do not match');
    expect(await repo.hasAdmin(), isFalse);
    auth.dispose();
  });

  test('duplicate username is rejected with friendly error', () async {
    await repo.createAdmin(
      username: 'admin',
      fullName: 'First Admin',
      password: 'Password123',
    );
    await expectLater(
      repo.createAdmin(
        username: 'admin',
        fullName: 'Second Admin',
        password: 'Password123',
      ),
      throwsA(isA<DuplicateException>()),
    );
  });

  test('supports multiple administrator accounts with audit history', () async {
    final first = await repo.createAdmin(
      username: 'admin',
      fullName: 'First Admin',
      password: 'Password123',
    );
    final second = await repo.createAdmin(
      username: 'counselor',
      fullName: 'School Counselor',
      password: 'Password456',
    );
    expect(await repo.listAdmins(), hasLength(2));

    await repo.setAdminActive(
      adminId: second.id,
      isActive: false,
      requestingAdminId: first.id,
    );
    expect(
      (await repo.listAdmins()).singleWhere((a) => a.id == second.id).isActive,
      isFalse,
    );
    await expectLater(
      repo.setAdminActive(
        adminId: first.id,
        isActive: false,
        requestingAdminId: second.id,
      ),
      throwsA(isA<ValidationException>()),
    );

    final audit = await db.query(
      'audit_logs',
      where: 'entity_type = ?',
      whereArgs: ['admin_account'],
    );
    expect(audit.map((row) => row['action']), contains('created'));
    expect(audit.map((row) => row['action']), contains('deactivated'));
  });

  test('an administrator cannot deactivate their own account', () async {
    final admin = await repo.createAdmin(
      username: 'admin',
      fullName: 'Site Administrator',
      password: 'Password123',
    );
    await expectLater(
      repo.setAdminActive(
        adminId: admin.id,
        isActive: false,
        requestingAdminId: admin.id,
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(await repo.hasAdmin(), isTrue);
  });

  test('login succeeds with correct credentials', () async {
    await repo.createAdmin(
      username: 'admin',
      fullName: 'Site Administrator',
      password: 'Password123',
    );
    final auth = makeController();
    await auth.init();
    expect(auth.status, AuthStatus.unauthenticated);

    final error = await auth.login('admin', 'Password123');
    expect(error, isNull);
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.admin?.username, 'admin');
    auth.dispose();
  });

  test('login fails with wrong password or unknown user', () async {
    await repo.createAdmin(
      username: 'admin',
      fullName: 'Site Administrator',
      password: 'Password123',
    );
    final auth = makeController(maxFailedAttempts: 5);
    await auth.init();

    final badPassword = await auth.login('admin', 'WrongPass123');
    expect(badPassword, contains('Invalid username or password'));
    expect(auth.status, AuthStatus.unauthenticated);

    final badUser = await auth.login('ghost', 'Password123');
    expect(badUser, contains('Invalid username or password'));
    auth.dispose();
  });

  test('throttles after repeated failed attempts, then recovers', () async {
    await repo.createAdmin(
      username: 'admin',
      fullName: 'Site Administrator',
      password: 'Password123',
    );
    final auth = makeController(
      maxFailedAttempts: 2,
      throttleDelay: const Duration(milliseconds: 200),
    );
    await auth.init();

    await auth.login('admin', 'bad1');
    await auth.login('admin', 'bad2');
    final throttled = await auth.login('admin', 'bad3');
    expect(throttled, contains('Too many failed attempts'));

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final ok = await auth.login('admin', 'Password123');
    expect(ok, isNull);
    expect(auth.status, AuthStatus.authenticated);
    auth.dispose();
  });

  test('auto-locks after idle timeout and unlocks with password', () async {
    final auth = makeController(idleTimeout: const Duration(milliseconds: 250));
    await auth.init();
    await auth.setup(
      username: 'admin',
      fullName: 'Site Administrator',
      password: 'Password123',
      confirmPassword: 'Password123',
    );
    expect(auth.status, AuthStatus.authenticated);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(auth.status, AuthStatus.locked);

    final wrongError = await auth.unlock('WrongPass123');
    expect(wrongError, isNotNull);
    expect(auth.status, AuthStatus.locked);

    final rightError = await auth.unlock('Password123');
    expect(rightError, isNull);
    expect(auth.status, AuthStatus.authenticated);
    auth.dispose();
  });

  test('manual lock locks and logout returns to unauthenticated', () async {
    final auth = makeController();
    await auth.init();
    await auth.setup(
      username: 'admin',
      fullName: 'Site Administrator',
      password: 'Password123',
      confirmPassword: 'Password123',
    );

    auth.session.lock();
    expect(auth.status, AuthStatus.locked);

    auth.logout();
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.admin, isNull);
    auth.dispose();
  });

  test(
    'changePassword validates current password and applies new one',
    () async {
      final auth = makeController();
      await auth.init();
      await auth.setup(
        username: 'admin',
        fullName: 'Site Administrator',
        password: 'Password123',
        confirmPassword: 'Password123',
      );

      final wrongCurrent = await auth.changePassword(
        currentPassword: 'WrongPass123',
        newPassword: 'NewPassword456',
        confirmPassword: 'NewPassword456',
      );
      expect(wrongCurrent, isNotNull);

      final weakNew = await auth.changePassword(
        currentPassword: 'Password123',
        newPassword: 'weak',
        confirmPassword: 'weak',
      );
      expect(weakNew, isNotNull);

      final success = await auth.changePassword(
        currentPassword: 'Password123',
        newPassword: 'NewPassword456',
        confirmPassword: 'NewPassword456',
      );
      expect(success, isNull);

      expect(await repo.verifyCredentials('admin', 'Password123'), isNull);
      expect(
        await repo.verifyCredentials('admin', 'NewPassword456'),
        isNotNull,
      );
      auth.dispose();
    },
  );
}
