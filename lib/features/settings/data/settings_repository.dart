import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Small key-value store in SQLite for user preferences.
class SettingsRepository {
  SettingsRepository(this._db);

  static const idleTimeoutKey = 'idle_timeout_minutes';
  static const idleTimeoutDefault = 15;
  static const idleTimeoutMin = 1;
  static const idleTimeoutMax = 120;

  static const _referralEmailPrefix = 'referral_email_';

  final Database _db;

  /// Saved e-mail addresses for referral recipients, keyed by recipient id.
  Future<Map<String, String>> getReferralEmails() async {
    final rows = await _db.query(
      'settings',
      where: 'key LIKE ?',
      whereArgs: ['$_referralEmailPrefix%'],
    );
    return {
      for (final row in rows)
        (row['key'] as String).substring(_referralEmailPrefix.length):
            row['value'] as String,
    };
  }

  Future<void> setReferralEmail(String recipientId, String email) async {
    final key = '$_referralEmailPrefix$recipientId';
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await _db.insert(
      'settings',
      {'key': key, 'value': trimmed},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getIdleTimeoutMinutes() async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [idleTimeoutKey],
      limit: 1,
    );
    if (rows.isEmpty) return idleTimeoutDefault;
    final parsed = int.tryParse(rows.single['value'] as String);
    if (parsed == null) return idleTimeoutDefault;
    return parsed.clamp(idleTimeoutMin, idleTimeoutMax);
  }

  Future<void> setIdleTimeoutMinutes(int minutes) async {
    if (minutes < idleTimeoutMin || minutes > idleTimeoutMax) {
      throw ValidationException(
        'Auto-lock must be between $idleTimeoutMin and '
        '$idleTimeoutMax minutes',
      );
    }
    await _db.insert(
      'settings',
      {'key': idleTimeoutKey, 'value': '$minutes'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
