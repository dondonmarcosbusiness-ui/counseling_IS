import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/features/appointments/data/appointment_repository.dart';
import 'package:counseling_is/features/appointments/domain/appointment.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/forms/data/form_submission_repository.dart';
import 'package:counseling_is/features/interventions/data/intervention_repository.dart';
import 'package:counseling_is/features/reports/data/report_repository.dart';
import 'package:counseling_is/features/sessions/data/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late ReportRepository repo;
  late Client ana;

  setUp(() async {
    db = await openTestDatabase();
    final clients = ClientRepository(db);
    final appointments = AppointmentRepository(db);
    final sessions = SessionRepository(db);
    repo = ReportRepository(db);

    ana = await clients.create(const CreateClientInput(fullName: 'Ana Cruz'));
    await clients.create(const CreateClientInput(fullName: 'Ben Reyes'));

    await appointments.create(
      CreateAppointmentInput(
        clientId: ana.id!,
        startsAt: DateTime(2026, 6, 15, 10),
        endsAt: DateTime(2026, 6, 15, 11),
        purpose: 'Intake interview',
      ),
    );
    final juneCompleted = await appointments.create(
      CreateAppointmentInput(
        clientId: ana.id!,
        startsAt: DateTime(2026, 6, 16, 14),
        endsAt: DateTime(2026, 6, 16, 15),
        purpose: 'Follow-up',
      ),
    );
    await appointments.update(
      Appointment(
        id: juneCompleted.id!,
        clientId: juneCompleted.clientId,
        startsAt: juneCompleted.startsAt,
        endsAt: juneCompleted.endsAt,
        purpose: juneCompleted.purpose,
        status: AppointmentStatus.completed,
        createdAt: juneCompleted.createdAt,
        updatedAt: juneCompleted.updatedAt,
      ),
    );
    await appointments.create(
      CreateAppointmentInput(
        clientId: ana.id!,
        startsAt: DateTime(2026, 8, 20, 9),
        endsAt: DateTime(2026, 8, 20, 10),
        purpose: 'August visit',
      ),
    );

    await sessions.create(
      CreateSessionInput(
        clientId: ana.id!,
        sessionDate: DateTime(2026, 6, 10),
        notes: 'SECRET NOTE ALPHA',
        nextRecommendedDate: DateTime(2026, 6, 24),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  String flatten(ReportTable table) =>
      [for (final row in table.rows) ...row].join(' | ');

  group('clients report', () {
    test('lists clients with a status breakdown', () async {
      final report = await repo.run(
        const ReportRequest(type: ReportType.clients),
      );

      expect(report.total, 2);
      expect(report.breakdown, {'active': 2});
      expect(report.columns, contains('Reference'));
      expect(
        report.rows.map((row) => row[1]),
        containsAll(['Ana Cruz', 'Ben Reyes']),
      );
    });

    test('filters by registered date range', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final inRange = await repo.run(
        ReportRequest(type: ReportType.clients, from: today, to: today),
      );
      expect(inRange.total, 2);

      final outOfRange = await repo.run(
        ReportRequest(
          type: ReportType.clients,
          from: DateTime(2000),
          to: DateTime(2000, 12, 31),
        ),
      );
      expect(outOfRange.total, 0);
      expect(outOfRange.rows, isEmpty);
    });

    test('filters by status', () async {
      await ClientRepository(db).archive(ana.id!);

      final report = await repo.run(
        const ReportRequest(type: ReportType.clients, status: 'archived'),
      );
      expect(report.total, 1);
      expect(report.rows.single[1], 'Ana Cruz');
      expect(report.breakdown, {'archived': 1});
    });
  });

  group('appointments report', () {
    test('filters by date range and joins the client name', () async {
      final report = await repo.run(
        ReportRequest(
          type: ReportType.appointments,
          from: DateTime(2026, 6, 1),
          to: DateTime(2026, 6, 30),
        ),
      );

      expect(report.total, 2);
      expect(report.breakdown, {'scheduled': 1, 'completed': 1});
      expect(report.rows.map((row) => row[2]), everyElement('Ana Cruz'));
      expect(
        report.rows.map((row) => row[4]),
        containsAll(['Scheduled', 'Completed']),
      );

      final outOfRange = await repo.run(
        ReportRequest(
          type: ReportType.appointments,
          from: DateTime(2026, 7, 1),
          to: DateTime(2026, 7, 31),
        ),
      );
      expect(outOfRange.total, 0);
    });

    test('filters by status', () async {
      final report = await repo.run(
        const ReportRequest(type: ReportType.appointments, status: 'completed'),
      );

      expect(report.total, 1);
      expect(report.rows.single[4], 'Completed');
      expect(report.rows.single[3], 'Follow-up');
    });
  });

  group('sessions report', () {
    test('never exposes confidential notes', () async {
      final report = await repo.run(
        ReportRequest(
          type: ReportType.sessions,
          from: DateTime(2026, 6, 1),
          to: DateTime(2026, 6, 30),
        ),
      );

      expect(report.total, 1);
      expect(report.columns, isNot(contains('Notes')));
      expect(flatten(report), isNot(contains('SECRET NOTE ALPHA')));
      expect(flatten(report), contains('Ana Cruz'));
      expect(report.rows.single[3], isNot('—'));
      expect(report.breakdown, isNull);
    });

    test('filters by session date range', () async {
      final outOfRange = await repo.run(
        ReportRequest(
          type: ReportType.sessions,
          from: DateTime(2026, 7, 1),
          to: DateTime(2026, 7, 31),
        ),
      );
      expect(outOfRange.total, 0);
    });
  });

  test('rejects an inverted date range', () async {
    await expectLater(
      repo.run(
        ReportRequest(
          type: ReportType.clients,
          from: DateTime(2026, 7, 1),
          to: DateTime(2026, 6, 1),
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test(
    'DepEd draft summarizes activity without exposing intake details',
    () async {
      await InterventionRepository(db).create(
        CreateInterventionInput(
          clientId: ana.id!,
          title: 'Attendance support',
          type: 'Academic support',
          startDate: DateTime(2026, 6, 1),
        ),
      );
      await FormSubmissionRepository(db).create(
        formId: 'child_protection_intake',
        clientId: ana.id,
        data: const {'factual_account': 'SECRET CHILD PROTECTION DETAIL'},
      );

      final report = await repo.run(
        const ReportRequest(type: ReportType.depedDraft),
      );

      expect(report.total, 5);
      expect(report.columns, ['Indicator', 'Count']);
      expect(report.rows.first, ['Learners registered', '2']);
      expect(report.rows.map((row) => row.last), containsAll(['3', '1']));
      expect(
        flatten(report),
        isNot(contains('SECRET CHILD PROTECTION DETAIL')),
      );
    },
  );
}
