import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_factory.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  String? _path;

  Database get db {
    final db = _db;
    if (db == null) {
      throw StateError('AppDatabase has not been opened yet');
    }
    return db;
  }

  /// Filesystem path of the open database (null before [open]).
  String? get path => _path;

  bool get isOpen => _db != null;

  Future<void> open() async {
    if (_db != null) return;
    initSqliteFfi();
    final path = await defaultDatabasePath();
    _db = await openAppDatabase(path);
    _path = path;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _path = null;
  }
}
