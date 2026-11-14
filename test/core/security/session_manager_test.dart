import 'package:counseling_is/core/security/session_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('locks after idle timeout', () async {
    var locked = false;
    final session = SessionManager(
      onLock: () => locked = true,
      idleTimeout: const Duration(milliseconds: 300),
    );

    session.unlock();
    expect(session.isLocked, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(session.isLocked, isTrue);
    expect(locked, isTrue);
    session.dispose();
  });

  test('activity before the timeout postpones locking', () async {
    var locked = false;
    final session = SessionManager(
      onLock: () => locked = true,
      idleTimeout: const Duration(milliseconds: 400),
    );

    session.unlock();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    session.noteActivity();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(session.isLocked, isFalse,
        reason: 'activity at 250ms should reset the 400ms timer');
    expect(locked, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(session.isLocked, isTrue,
        reason: 'should lock 400ms after last activity');
    session.dispose();
  });

  test('noteActivity while locked does not unlock', () async {
    final session = SessionManager(
      onLock: () {},
      idleTimeout: const Duration(milliseconds: 200),
    );
    session.unlock();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(session.isLocked, isTrue);

    session.noteActivity();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(session.isLocked, isTrue,
        reason: 'activity must not unlock a locked session');
    session.dispose();
  });

  test('lock is idempotent (onLock fires once per transition)', () async {
    var lockCalls = 0;
    final session = SessionManager(
      onLock: () => lockCalls++,
      idleTimeout: const Duration(days: 1),
    );
    session.unlock();
    session.lock();
    session.lock();
    expect(lockCalls, 1);
    session.dispose();
  });
}
