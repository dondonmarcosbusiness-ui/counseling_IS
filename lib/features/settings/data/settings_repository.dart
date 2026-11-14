import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Small key-value store in SQLite for user preferences.
class SettingsRepository {
  SettingsRepository(this._db);

  static const idleTimeoutKey = 'idle_timeout_minutes';
  static const idleTimeoutDefault = 15;
  static const idleTimeoutMin = 1;
  static const idleTimeoutMax = 120;

  final Database _db;

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
