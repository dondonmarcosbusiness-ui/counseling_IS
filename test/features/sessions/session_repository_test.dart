import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/features/appointments/data/appointment_repository.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/sessions/data/session_repository.dart';
import 'package:counseling_is/features/sessions/domain/session_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late ClientRepository clients;
  late AppointmentRepository appointments;
  late SessionRepository repo;
  late Client client;
  late Client otherClient;

  setUp(() async {
    db = await openTestDatabase();
    clients = ClientRepository(db);
    appointments = AppointmentRepository(db);
    repo = SessionRepository(db);
    client = await clients.create(const CreateClientInput(fullName: 'Ana Cruz'));
    otherClient =
        await clients.create(const CreateClientInput(fullName: 'Ben Santos'));
  });

  tearDown(() async {
    await db.close();
  });

  test('create stores session and getById round-trips date-only fields',
      () async {
    final created = await repo.create(CreateSessionInput(
      clientId: client.id!,
      sessionDate: DateTime(2026, 3, 5),
      notes: 'Initial intake session. Discussed concerns.',
      followUpActions: 'Provide coping worksheets',
      nextRecommendedDate: DateTime(2026, 3, 19),
    ));

    expect(created.id, isNotNull);
    expect(created.clientName, 'Ana Cruz');
    expect(created.appointmentId, isNull);

    final fetched = await repo.getById(created.id!);
    expect(fetched.sessionDate, DateTime(2026, 3, 5));
    expect(fetched.nextRecommendedDate, DateTime(2026, 3, 19));
    expect(fetched.notes, 'Initial intake session. Discussed concerns.');
    expect(fetched.followUpActions, 'Provide coping worksheets');
  });

  test('create rejects blank notes', () async {
    await expectLater(
      repo.create(CreateSessionInput(
        clientId: client.id!,
        sessionDate: DateTime(2026, 3, 5),
        notes: '   ',
      )),
      throwsA(isA<ValidationException>()),
    );
  });

  test('create rejects next recommended date before session date', () async {
    await expectLater(
      repo.create(CreateSessionInput(
        clientId: client.id!,
        sessionDate: DateTime(2026, 3, 5),
        notes: 'Valid notes',
        nextRecommendedDate: DateTime(2026, 3, 4),
      )),
      throwsA(isA<ValidationException>()),
    );
  });

  test('create rejects missing client and unknown appointment', () async {
    await expectLater(
      repo.create(CreateSessionInput(
        clientId: 99999,
        sessionDate: DateTime(2026, 3, 5),
        notes: 'Valid notes',
      )),
      throwsA(isA<NotFoundException>()),
    );
    await expectLater(
      repo.create(CreateSessionInput(
        clientId: client.id!,
        appointmentId: 99999,
        sessionDate: DateTime(2026, 3, 5),
        notes: 'Valid notes',
      )),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('session can link to an appointment of the same client', () async {
    final appointment = await appointments.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: DateTime(2026, 3, 5, 10),
      endsAt: DateTime(2026, 3, 5, 11),
    ));

    final created = await repo.create(CreateSessionInput(
      clientId: client.id!,
      appointmentId: appointment.id,
      sessionDate: DateTime(2026, 3, 5),
      notes: 'Held as scheduled.',
    ));
    expect(created.appointmentId, appointment.id);
  });

  test('session cannot link to another client appointment', () async {
    final appointment = await appointments.create(CreateAppointmentInput(
      clientId: otherClient.id!,
      startsAt: DateTime(2026, 3, 5, 10),
      endsAt: DateTime(2026, 3, 5, 11),
    ));

    await expectLater(
      repo.create(CreateSessionInput(
        clientId: client.id!,
        appointmentId: appointment.id,
        sessionDate: DateTime(2026, 3, 5),
        notes: 'Wrong link.',
      )),
      throwsA(isA<ValidationException>()),
    );
  });

  test('deleting an appointment clears the session link', () async {
    final appointment = await appointments.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: DateTime(2026, 3, 5, 10),
      endsAt: DateTime(2026, 3, 5, 11),
    ));
    final session = await repo.create(CreateSessionInput(
      clientId: client.id!,
      appointmentId: appointment.id,
      sessionDate: DateTime(2026, 3, 5),
      notes: 'Held as scheduled.',
    ));

    await db.delete(
      'appointments',
      where: 'id = ?',
      whereArgs: [appointment.id],
    );

    final fetched = await repo.getById(session.id!);
    expect(fetched.appointmentId, isNull);
    expect(fetched.notes, 'Held as scheduled.');
  });

  test('foreign key prevents deleting a client with sessions', () async {
    await repo.create(CreateSessionInput(
      clientId: client.id!,
      sessionDate: DateTime(2026, 3, 5),
      notes: 'History exists.',
    ));

    expect(
      () => db.delete('clients', where: 'id = ?', whereArgs: [client.id]),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('update modifies fields and validates again', () async {
    final created = await repo.create(CreateSessionInput(
      clientId: client.id!,
      sessionDate: DateTime(2026, 3, 5),
      notes: 'Original notes',
    ));

    final updated = await repo.update(SessionRecord(
      id: created.id,
      clientId: created.clientId,
      sessionDate: created.sessionDate,
      notes: 'Updated notes with plan.',
      followUpActions: 'Journal daily',
      createdAt: created.createdAt,
      updatedAt: created.updatedAt,
    ));
    expect(updated.notes, 'Updated notes with plan.');

    final refetched = await repo.getById(created.id!);
    expect(refetched.notes, 'Updated notes with plan.');
    expect(refetched.followUpActions, 'Journal daily');

    await expectLater(
      repo.update(SessionRecord(
        id: created.id,
        clientId: created.clientId,
        sessionDate: created.sessionDate,
        notes: '   ',
        createdAt: created.createdAt,
        updatedAt: created.updatedAt,
      )),
      throwsA(isA<ValidationException>()),
    );
  });

  test('update throws NotFoundException for missing id', () async {
    await expectLater(
      repo.update(SessionRecord(
        id: 99999,
        clientId: client.id!,
        sessionDate: DateTime(2026, 3, 5),
        notes: 'Valid notes',
        createdAt: DateTime(2026, 3, 5),
        updatedAt: DateTime(2026, 3, 5),
      )),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('list searches by client and orders newest first', () async {
    await repo.create(CreateSessionInput(
      clientId: client.id!,
      sessionDate: DateTime(2026, 3, 5),
      notes: 'First meeting',
    ));
    await repo.create(CreateSessionInput(
      clientId: otherClient.id!,
      sessionDate: DateTime(2026, 3, 12),
      notes: 'Other client meeting',
    ));

    final all = await repo.list(const SessionQuery());
    expect(all, hasLength(2));
    expect(all.first.sessionDate, DateTime(2026, 3, 12));

    final byName = await repo.list(const SessionQuery(searchText: 'ana'));
    expect(byName, hasLength(1));
    expect(byName.single.clientName, 'Ana Cruz');

    final byClient = await repo.list(SessionQuery(clientId: otherClient.id));
    expect(byClient, hasLength(1));
    expect(byClient.single.notes, 'Other client meeting');
  });
}
