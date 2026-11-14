import 'package:counseling_is/core/security/password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hasher = PasswordHasher(logRounds: 4);

  test('hash is not the plaintext and has bcrypt format', () async {
    final hash = await hasher.hash('SecretPass123');
    expect(hash, isNot('SecretPass123'));
    expect(hash, startsWith('\$2'));
    expect(hash, isNot(contains('SecretPass123')));
  });

  test('verify accepts the correct password', () async {
    final hash = await hasher.hash('SecretPass123');
    expect(await hasher.verify('SecretPass123', hash), isTrue);
  });

  test('verify rejects a wrong password', () async {
    final hash = await hasher.hash('SecretPass123');
    expect(await hasher.verify('WrongPass123', hash), isFalse);
  });

  test('same password produces different hashes (unique salts)', () async {
    final h1 = await hasher.hash('SamePassword1');
    final h2 = await hasher.hash('SamePassword1');
    expect(h1, isNot(h2));
    expect(await hasher.verify('SamePassword1', h1), isTrue);
    expect(await hasher.verify('SamePassword1', h2), isTrue);
  });
}
