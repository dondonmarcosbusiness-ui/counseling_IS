import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int schemaVersion = 6;

Future<void> applyAll(Database db) async {
  await applyV1(db);
  await applyV2(db);
  await applyV3(db);
  await applyV4(db);
  await applyV5(db);
  await applyV6(db);
}

Future<void> applyV1(Database db) async {
  await db.execute('''
    CREATE TABLE admins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      full_name TEXT NOT NULL,
      created_at TEXT NOT NULL,
      last_login_at TEXT,
      is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
    )
  ''');

  await db.execute('''
    CREATE TABLE clients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      reference_no TEXT NOT NULL UNIQUE,
      full_name TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      date_of_birth TEXT,
      intake_notes TEXT,
      status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','archived')),
      registered_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_clients_name ON clients(full_name)');
  await db.execute('CREATE INDEX idx_clients_status ON clients(status)');

  await db.execute('''
    CREATE TABLE appointments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
      starts_at TEXT NOT NULL,
      ends_at TEXT NOT NULL,
      purpose TEXT,
      status TEXT NOT NULL DEFAULT 'scheduled'
        CHECK (status IN ('scheduled','completed','missed','cancelled')),
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      CHECK (ends_at > starts_at)
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_appts_starts_at ON appointments(starts_at)',
  );
  await db.execute('CREATE INDEX idx_appts_client ON appointments(client_id)');

  await db.execute('''
    CREATE TABLE counseling_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
      appointment_id INTEGER REFERENCES appointments(id) ON DELETE SET NULL,
      session_date TEXT NOT NULL,
      notes TEXT NOT NULL,
      follow_up_actions TEXT,
      next_recommended_date TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_sessions_client ON counseling_sessions(client_id)',
  );
  await db.execute(
    'CREATE INDEX idx_sessions_date ON counseling_sessions(session_date)',
  );

  await db.execute('''
    CREATE TABLE case_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      case_ref TEXT NOT NULL UNIQUE,
      client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
      opened_at TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open','in_progress','closed')),
      summary TEXT,
      follow_up_date TEXT,
      closed_at TEXT,
      closure_notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_cases_client ON case_records(client_id)');
  await db.execute('CREATE INDEX idx_cases_status ON case_records(status)');

  await db.execute('''
    CREATE TABLE audit_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      admin_id INTEGER REFERENCES admins(id) ON DELETE SET NULL,
      action TEXT NOT NULL,
      entity_type TEXT,
      entity_id INTEGER,
      detail TEXT,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_audit_created ON audit_logs(created_at)');
}

Future<void> applyV2(Database db) async {
  await db.execute('''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
}

Future<void> applyV3(Database db) async {
  await db.execute('''
    CREATE TABLE form_submissions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      form_id TEXT NOT NULL,
      client_id INTEGER REFERENCES clients(id) ON DELETE SET NULL,
      form_data TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_form_submissions_form ON form_submissions(form_id)',
  );
  await db.execute(
    'CREATE INDEX idx_form_submissions_client ON form_submissions(client_id)',
  );
  await db.execute(
    'CREATE INDEX idx_form_submissions_updated ON form_submissions(updated_at)',
  );
}

Future<void> applyV4(Database db) async {
  final columns = await db.rawQuery('PRAGMA table_info(clients)');
  final existingColumns = columns.map((column) => column['name']).toSet();
  const addedColumns = {
    'first_name': 'TEXT',
    'middle_name': 'TEXT',
    'last_name': 'TEXT',
    'suffix': 'TEXT',
  };

  for (final entry in addedColumns.entries) {
    if (!existingColumns.contains(entry.key)) {
      await db.execute(
        'ALTER TABLE clients ADD COLUMN ${entry.key} ${entry.value}',
      );
    }
  }
}

Future<void> applyV5(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS interventions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
      case_id INTEGER REFERENCES case_records(id) ON DELETE SET NULL,
      title TEXT NOT NULL,
      intervention_type TEXT NOT NULL,
      description TEXT,
      goal TEXT,
      status TEXT NOT NULL DEFAULT 'planned'
        CHECK (status IN ('planned','in_progress','completed','cancelled')),
      start_date TEXT NOT NULL,
      target_date TEXT,
      completed_at TEXT,
      outcome TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_interventions_client '
    'ON interventions(client_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_interventions_case '
    'ON interventions(case_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_interventions_status '
    'ON interventions(status)',
  );

  await db.execute('''
    CREATE TABLE IF NOT EXISTS case_timeline_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      case_id INTEGER NOT NULL REFERENCES case_records(id) ON DELETE CASCADE,
      occurred_at TEXT NOT NULL,
      event_type TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      admin_id INTEGER REFERENCES admins(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_case_timeline_case_date '
    'ON case_timeline_events(case_id, occurred_at DESC)',
  );
}

Future<void> applyV6(Database db) async {
  final columns = await db.rawQuery('PRAGMA table_info(interventions)');
  if (!columns.any((column) => column['name'] == 'custom_type')) {
    await db.execute('ALTER TABLE interventions ADD COLUMN custom_type TEXT');
  }
  await db.execute('''
    CREATE TABLE IF NOT EXISTS intervention_participants (
      intervention_id INTEGER NOT NULL
        REFERENCES interventions(id) ON DELETE CASCADE,
      client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
      PRIMARY KEY (intervention_id, client_id)
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_intervention_participants_client '
    'ON intervention_participants(client_id)',
  );
  await db.execute('''
    INSERT OR IGNORE INTO intervention_participants (intervention_id, client_id)
    SELECT id, client_id FROM interventions
  ''');
}

Future<void> upgradeSchema(Database db, int oldVersion, int newVersion) async {
  var version = oldVersion;
  if (version < 1) {
    await applyV1(db);
    version = 1;
  }
  if (version < 2) {
    await applyV2(db);
    version = 2;
  }
  if (version < 3) {
    await applyV3(db);
    version = 3;
  }
  if (version < 4) {
    await applyV4(db);
    version = 4;
  }
  if (version < 5) {
    await applyV5(db);
    version = 5;
  }
  if (version < 6) {
    await applyV6(db);
  }
}
