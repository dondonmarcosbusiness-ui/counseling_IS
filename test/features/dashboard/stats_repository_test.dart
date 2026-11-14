import 'package:counseling_is/core/time/time.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/dashboard/data/stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late StatsRepository stats;
  late ClientRepository clients;

  setUp(() async {
    db = await openTestDatabase();
    stats = StatsRepository(db);
    clients = ClientRepository(db);
  });

  tearDown(() async => db.close());

  test('all zeros on an empty database', () async {
    final s = await stats.fetch(now: DateTime(2026, 6, 15, 10));
    expect(s.activeClients, 0);
    expect(s.todaysAppointments, 0);
    expect(s.upcomingAppointments, 0);
    expect(s.completedSessions, 0);
    expect(s.todaysSessions, 0);
    expect(s.activeInterventions, 0);
    expect(s.isEmpty, isTrue);
  });

  test('counts active clients and ignores archived', () async {
    await clients.create(const CreateClientInput(fullName: 'Active One'));
    final b = await clients.create(const CreateClientInput(fullName: 'Two'));
    await clients.create(const CreateClientInput(fullName: 'Three'));
    await clients.archive(b.id!);

    final s = await stats.fetch(now: DateTime(2026, 6, 15, 10));
    expect(s.activeClients, 2);
    expect(s.isEmpty, isFalse);
  });

  test('today vs upcoming vs past vs cancelled appointments', () async {
    final client = await clients.create(
      const CreateClientInput(fullName: 'Client A'),
    );
    Future<void> appt(DateTime start, {String status = 'scheduled'}) {
      return db.insert('appointments', {
        'client_id': client.id,
        'starts_at': dateTimeToDb(start),
        'ends_at': dateTimeToDb(start.add(const Duration(hours: 1))),
        'status': status,
        'created_at': nowUtcIso(),
        'updated_at': nowUtcIso(),
      });
    }

    // Reference now: 2026-06-15 10:00 local.
    await appt(DateTime(2026, 6, 15, 8)); // earlier today (past)
    await appt(DateTime(2026, 6, 15, 14)); // later today (upcoming)
    await appt(DateTime(2026, 6, 16, 10)); // tomorrow (upcoming, not today)
    await appt(DateTime(2026, 6, 14, 10)); // yesterday (neither)
    await appt(
      DateTime(2026, 6, 15, 9),
      status: 'cancelled',
    ); // today but cancelled

    final s = await stats.fetch(now: DateTime(2026, 6, 15, 10));
    expect(
      s.todaysAppointments,
      2,
      reason: '08:00 and 14:00 today, excluding cancelled',
    );
    expect(
      s.upcomingAppointments,
      2,
      reason: '14:00 today and tomorrow 10:00, status scheduled',
    );
    expect(s.todayAppointmentItems, hasLength(2));
    expect(
      s.todayAppointmentItems.map((appointment) => appointment.startsAt.hour),
      [8, 14],
    );
    expect(
      s.todayAppointmentItems.map((appointment) => appointment.clientName),
      everyElement('Client A'),
    );
  });

  test('counts completed sessions', () async {
    final client = await clients.create(
      const CreateClientInput(fullName: 'Client A'),
    );
    for (var i = 0; i < 3; i++) {
      await db.insert('counseling_sessions', {
        'client_id': client.id,
        'session_date': '2026-06-10',
        'notes': 'Note ${i + 1}',
        'created_at': nowUtcIso(),
        'updated_at': nowUtcIso(),
      });
    }

    final s = await stats.fetch(now: DateTime(2026, 6, 15, 10));
    expect(s.completedSessions, 3);
  });

  test('loads client details for today and upcoming appointments', () async {
    final ref = DateTime(2026, 6, 15, 10);
    final client = await clients.create(
      const CreateClientInput(fullName: 'Dashboard Client'),
    );
    final appointmentStart = ref.add(const Duration(hours: 2));
    await db.insert('appointments', {
      'client_id': client.id,
      'starts_at': dateTimeToDb(appointmentStart),
      'ends_at': dateTimeToDb(appointmentStart.add(const Duration(hours: 1))),
      'purpose': 'Intake meeting',
      'status': 'scheduled',
      'created_at': nowUtcIso(),
      'updated_at': nowUtcIso(),
    });

    final result = await stats.fetch(now: ref);

    expect(result.upcomingAppointmentItems, hasLength(1));
    expect(
      result.upcomingAppointmentItems.single.clientName,
      'Dashboard Client',
    );
    expect(result.upcomingAppointmentItems.single.purpose, 'Intake meeting');
    expect(result.todayAppointmentItems, hasLength(1));
    expect(result.todayAppointmentItems.single.clientName, 'Dashboard Client');
    await db.insert('counseling_sessions', {
      'client_id': client.id,
      'session_date': '2026-06-15',
      'notes': 'Private counseling notes',
      'created_at': nowUtcIso(),
      'updated_at': nowUtcIso(),
    });
    final withSession = await stats.fetch(now: ref);
    expect(withSession.todaySessionItems, hasLength(1));
    expect(withSession.todaySessionItems.single.clientName, 'Dashboard Client');
    expect(
      withSession.todaySessionItems.single.sessionDate,
      DateTime(2026, 6, 15),
    );
  });

  test('no SQL errors when related tables are empty', () async {
    await clients.create(const CreateClientInput(fullName: 'Solo Client'));
    final s = await stats.fetch(now: DateTime(2026, 6, 15, 10));
    expect(s.activeClients, 1);
    expect(s.todaysAppointments, 0);
    expect(s.completedSessions, 0);
  });

  test('counts active interventions and sessions', () async {
    final ref = DateTime(2026, 6, 15, 10);
    final client = await clients.create(
      const CreateClientInput(fullName: 'Dashboard Client'),
    );
    for (final status in ['planned', 'in_progress', 'completed']) {
      await db.insert('interventions', {
        'client_id': client.id,
        'title': 'Support plan',
        'intervention_type': 'Guidance',
        'status': status,
        'start_date': '2026-06-01',
        'created_at': nowUtcIso(),
        'updated_at': nowUtcIso(),
      });
    }
    await db.insert('counseling_sessions', {
      'client_id': client.id,
      'session_date': '2026-06-15',
      'notes': 'Private session notes',
      'created_at': nowUtcIso(),
      'updated_at': nowUtcIso(),
    });

    final result = await stats.fetch(now: ref);

    expect(result.activeInterventions, 2);
    expect(result.completedSessions, 1);
    expect(result.todaysSessions, 1);
    expect(result.todaySessionItems, hasLength(1));
    expect(result.todaySessionItems.single.clientName, 'Dashboard Client');
  });
}
