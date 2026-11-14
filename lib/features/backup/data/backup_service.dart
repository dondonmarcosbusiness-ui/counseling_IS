import 'dart:io';

import 'package:counseling_is/core/database/migrations.dart';
import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class BackupInfo {
  const BackupInfo({
    required this.schemaVersion,
    required this.clients,
    required this.appointments,
    required this.sessions,
    required this.cases,
  });

  final int schemaVersion;
  final int clients;
  final int appointments;
  final int sessions;
  final int cases;
}

/// Creates consistent database backups (`VACUUM INTO`) and restores them
/// by replacing the live database file.
class BackupService {
  BackupService(this._db, this._dbPath);

  static const _versionOneTables = [
    'admins',
    'clients',
    'appointments',
    'counseling_sessions',
    'case_records',
    'audit_logs',
  ];

  final Database _db;
  final String _dbPath;

  /// Writes a consistent copy of the open database to [destinationPath]
  /// (the app keeps running; the target file must not already exist).
  Future<String> createBackup(String destinationPath) async {
    if (_samePath(destinationPath, _dbPath)) {
      throw ValidationException(
        'Choose a location outside the application data folder',
      );
    }
    if (File(destinationPath).existsSync()) {
      throw ValidationException(
        'A file already exists at the selected location',
      );
    }
    final parent = File(destinationPath).parent;
    if (!parent.existsSync()) {
      throw ValidationException('The selected folder does not exist');
    }

    await _db.execute('VACUUM INTO ?', [destinationPath]);
    if (!File(destinationPath).existsSync()) {
      throw AppException('The backup file could not be created');
    }
    return destinationPath;
  }

  /// Checks that [path] is a readable, compatible counseling database.
  /// Throws [ValidationException] with a user-facing reason if not.
  Future<BackupInfo> validateBackup(String path) async {
    if (_samePath(path, _dbPath)) {
      throw ValidationException(
        'The selected file is the current application database',
      );
    }
    final file = File(path);
    if (!file.existsSync()) {
      throw ValidationException('The selected file does not exist');
    }

    Database? probe;
    try {
      probe = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(singleInstance: false),
      );

      final integrity = await probe.rawQuery('PRAGMA integrity_check');
      if ((integrity.first.values.first as String?) != 'ok') {
        throw ValidationException(
          'The selected file failed its integrity check',
        );
      }

      final versionRow = await probe.rawQuery('PRAGMA user_version');
      final userVersion = (versionRow.first.values.first as int?) ?? 0;
      if (userVersion < 1 || userVersion > schemaVersion) {
        throw ValidationException(
          'The selected file was created by a different or unsupported '
          'version of this application',
        );
      }

      final masters = await probe.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tables = masters.map((row) => row['name'] as String).toSet();
      for (final table in _requiredTables(userVersion)) {
        if (!tables.contains(table)) {
          throw ValidationException(
            'The selected file does not contain counseling data',
          );
        }
      }

      return BackupInfo(
        schemaVersion: userVersion,
        clients: await _count(probe, 'clients'),
        appointments: await _count(probe, 'appointments'),
        sessions: await _count(probe, 'counseling_sessions'),
        cases: await _count(probe, 'case_records'),
      );
    } on ValidationException {
      rethrow;
    } catch (_) {
      throw ValidationException(
        'The selected file is not a valid database backup',
      );
    } finally {
      await probe?.close();
    }
  }

  List<String> _requiredTables(int version) => [
    ..._versionOneTables,
    if (version >= 2) 'settings',
    if (version >= 3) 'form_submissions',
    if (version >= 5) ...['interventions', 'case_timeline_events'],
    if (version >= 6) 'intervention_participants',
  ];

  /// Replaces the live database with [backupPath] after validation.
  /// The caller must reopen the database (or restart the app) afterwards.
  Future<void> restoreFrom(String backupPath) async {
    final info = await validateBackup(backupPath);

    await _db.close();

    final tmp = File('$_dbPath.restore-tmp');
    if (tmp.existsSync()) tmp.deleteSync();
    await File(backupPath).copy(tmp.path);

    final live = File(_dbPath);
    if (live.existsSync()) live.deleteSync();
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final sidecar = File('$_dbPath$suffix');
      if (sidecar.existsSync()) sidecar.deleteSync();
    }
    await tmp.rename(_dbPath);

    if (!File(_dbPath).existsSync()) {
      throw AppException('Restore failed: the database file is missing');
    }
    // info is only used by callers for display; keep the reference explicit.
    assert(info.schemaVersion >= 1);
  }

  Future<int> _count(Database db, String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return (rows.first['c'] as int?) ?? 0;
  }

  bool _samePath(String a, String b) {
    final left = a.toLowerCase().replaceAll('/', r'\');
    final right = b.toLowerCase().replaceAll('/', r'\');
    return left == right;
  }
}
