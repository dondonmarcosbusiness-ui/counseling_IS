import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';

class PasswordHasher {
  PasswordHasher({this.logRounds = 12});

  final int logRounds;

  Future<String> hash(String password) {
    return Isolate.run(() {
      final salt = BCrypt.gensalt(logRounds: logRounds);
      return BCrypt.hashpw(password, salt);
    });
  }

  Future<bool> verify(String password, String hash) {
    return Isolate.run(() => BCrypt.checkpw(password, hash));
  }
}
