import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/features/appointments/data/appointment_repository.dart';
import 'package:counseling_is/features/appointments/domain/appointment.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late ClientRepository clients;
  late AppointmentRepository repo;
  late Client client;

  setUp(() async {
    db = await openTestDatabase();
    clients = ClientRepository(db);
    repo = AppointmentRepository(db);
    client = await clients.create(const CreateClientInput(fullName: 'Ana Cruz'));
  });

  tearDown(() async {
    await db.close();
  });

  Appointment make({
    required int id,
    required DateTime start,
    DateTime? end,
    AppointmentStatus status = AppointmentStatus.scheduled,
    int? clientId,
    String? purpose,
  }) {
    return Appointment(
      id: id,
      clientId: clientId ?? client.id!,
      startsAt: start,
      endsAt: end ?? start.add(const Duration(minutes: 30)),
      purpose: purpose,
      status: status,
      createdAt: start,
      updatedAt: start,
    );
  }

  test('create stores appointment and getById round-trips times', () async {
    final start = DateTime(2026, 6, 15, 10, 15, 0, 123);
    final created = await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
      purpose: 'First consultation',
    ));

    expect(created.id, isNotNull);
    expect(created.status, AppointmentStatus.scheduled);
    expect(created.clientName, 'Ana Cruz');
    expect(created.duration, const Duration(hours: 1));

    final fetched = await repo.getById(created.id!);
    expect(fetched.startsAt, start);
    expect(fetched.endsAt, start.add(const Duration(hours: 1)));
    expect(fetched.purpose, 'First consultation');
  });

  test('create rejects end time at or before start time', () async {
    final start = DateTime(2026, 6, 15, 10);
    await expectLater(
      repo.create(CreateAppointmentInput(
        clientId: client.id!,
        startsAt: start,
        endsAt: start,
      )),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      repo.create(CreateAppointmentInput(
        clientId: client.id!,
        startsAt: start,
        endsAt: start.subtract(const Duration(minutes: 5)),
      )),
      throwsA(isA<ValidationException>()),
    );
  });

  test('create rejects missing client', () async {
    final start = DateTime(2026, 6, 15, 10);
    await expectLater(
      repo.create(CreateAppointmentInput(
        clientId: 99999,
        startsAt: start,
        endsAt: start.add(const Duration(minutes: 30)),
      )),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('overlapping appointment is rejected with a conflict', () async {
    final start = DateTime(2026, 6, 15, 10);
    await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
    ));

    await expectLater(
      repo.create(CreateAppointmentInput(
        clientId: client.id!,
        startsAt: start.add(const Duration(minutes: 30)),
        endsAt: start.add(const Duration(minutes: 90)),
      )),
      throwsA(isA<ConflictException>()),
    );
  });

  test('touching appointments back to back do not conflict', () async {
    final start = DateTime(2026, 6, 15, 10);
    await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: start,
      endsAt: start.add(const Duration(minutes: 30)),
    ));
    final second = await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: start.add(const Duration(minutes: 30)),
      endsAt: start.add(const Duration(minutes: 60)),
    ));
    expect(second.id, isNotNull);
  });

  test('cancelled appointments do not block overlapping slots', () async {
    final start = DateTime(2026, 6, 15, 10);
    final first = await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
    ));
    await repo.update(make(
      id: first.id!,
      start: first.startsAt,
      end: first.endsAt,
      status: AppointmentStatus.cancelled,
    ));

    final overlap = await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: start.add(const Duration(minutes: 30)),
      endsAt: start.add(const Duration(minutes: 90)),
    ));
    expect(overlap.id, isNotNull);
  });

  test('update can reschedule but rejects a new overlap', () async {
    final start = DateTime(2026, 6, 15, 10);
    final a = await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
    ));
    final b = await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: start.add(const Duration(hours: 2)),
      endsAt: start.add(const Duration(hours: 3)),
    ));

    // Rescheduling an appointment onto another slot must be rejected.
    await expectLater(
      repo.update(make(
        id: a.id!,
        start: b.startsAt.add(const Duration(minutes: 15)),
        end: b.startsAt.add(const Duration(minutes: 45)),
      )),
      throwsA(isA<ConflictException>()),
    );

    // Moving to a free slot works, and keeping the same slot never
    // conflicts with itself.
    final moved = await repo.update(make(
      id: a.id!,
      start: start.add(const Duration(days: 1)),
      end: start.add(const Duration(days: 1, minutes: 30)),
      purpose: 'Rescheduled visit',
    ));
    expect(moved.purpose, 'Rescheduled visit');

    final same = await repo.update(make(
      id: a.id!,
      start: moved.startsAt,
      end: moved.endsAt,
    ));
    expect(same.id, a.id);
  });

  test('update throws NotFoundException for missing id', () async {
    await expectLater(
      repo.update(make(
        id: 99999,
        start: DateTime(2026, 6, 15, 10),
      )),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('list time filters use injected now for comparisons', () async {
    final now = DateTime(2026, 6, 15, 8);
    final upcoming = await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: DateTime(2026, 6, 15, 10),
      endsAt: DateTime(2026, 6, 15, 11),
    ));
    final laterToday = await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: DateTime(2026, 6, 15, 14),
      endsAt: DateTime(2026, 6, 15, 15),
    ));
    await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: DateTime(2026, 6, 14, 10),
      endsAt: DateTime(2026, 6, 14, 11),
    ));

    final upcomingList = await repo.list(
      const AppointmentQuery(timeFilter: AppointmentTimeFilter.upcoming),
      now: now,
    );
    expect(upcomingList.map((a) => a.id), [upcoming.id, laterToday.id]);

    final todayList = await repo.list(
      const AppointmentQuery(timeFilter: AppointmentTimeFilter.today),
      now: now,
    );
    expect(todayList, hasLength(2));

    final pastList = await repo.list(
      const AppointmentQuery(timeFilter: AppointmentTimeFilter.past),
      now: now,
    );
    expect(pastList, hasLength(1));
    expect(pastList.single.startsAt.day, 14);

    final allList = await repo.list(
      const AppointmentQuery(timeFilter: AppointmentTimeFilter.all),
      now: now,
    );
    expect(allList, hasLength(3));
  });

  test('list filters by status, client and client name search', () async {
    final start = DateTime(2026, 6, 15, 10);
    final scheduled = await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: start,
      endsAt: start.add(const Duration(minutes: 30)),
    ));
    final cancelled = await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: start.add(const Duration(days: 1)),
      endsAt: start.add(const Duration(days: 1, minutes: 30)),
    ));
    await repo.update(make(
      id: cancelled.id!,
      start: cancelled.startsAt,
      end: cancelled.endsAt,
      status: AppointmentStatus.cancelled,
    ));

    final cancelledOnly = await repo.list(const AppointmentQuery(
      timeFilter: AppointmentTimeFilter.all,
      status: AppointmentStatus.cancelled,
    ));
    expect(cancelledOnly.map((a) => a.id), [cancelled.id]);

    final byClient = await repo.list(AppointmentQuery(
      timeFilter: AppointmentTimeFilter.all,
      clientId: client.id,
    ));
    expect(byClient, hasLength(2));

    final byName = await repo.list(const AppointmentQuery(
      timeFilter: AppointmentTimeFilter.all,
      searchText: 'ana',
    ));
    expect(byName.map((a) => a.id), contains(scheduled.id));

    final noMatch = await repo.list(const AppointmentQuery(
      timeFilter: AppointmentTimeFilter.all,
      searchText: 'zzz-not-here',
    ));
    expect(noMatch, isEmpty);
  });

  test('archived clients remain visible on their appointments', () async {
    final start = DateTime(2026, 6, 15, 10);
    final created = await repo.create(CreateAppointmentInput(
      clientId: client.id!,
      startsAt: start,
      endsAt: start.add(const Duration(minutes: 30)),
    ));
    await clients.archive(client.id!);

    final fetched = await repo.getById(created.id!);
    expect(fetched.clientName, 'Ana Cruz');

    final rows = await repo.list(const AppointmentQuery(
      timeFilter: AppointmentTimeFilter.all,
    ));
    expect(rows.single.clientName, 'Ana Cruz');
  });
}
