import 'package:counseling_is/core/database/database_factory.dart';
import 'package:counseling_is/core/database/migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openTestDatabase({String? path}) async {
  initSqliteFfi();
  return databaseFactoryFfiNoIsolate.openDatabase(
    path ?? inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => applyAll(db),
      onUpgrade: upgradeSchema,
      singleInstance: false,
    ),
  );
}
