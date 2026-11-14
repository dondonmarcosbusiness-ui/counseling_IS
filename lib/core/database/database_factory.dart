import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'migrations.dart';

void initSqliteFfi() {
  sqfliteFfiInit();
}

Future<String> defaultDatabasePath() async {
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, 'counseling.db');
}

Future<Database> openAppDatabase(String path) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => applyAll(db),
      onUpgrade: upgradeSchema,
    ),
  );
}
