import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/features/cases/data/case_repository.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/interventions/data/intervention_repository.dart';
import 'package:counseling_is/features/interventions/domain/intervention.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late ClientRepository clients;
  late InterventionRepository repo;
  late int clientId;
  late int otherClientId;

  setUp(() async {
    db = await openTestDatabase();
    clients = ClientRepository(db);
    repo = InterventionRepository(db);
    clientId = (await clients.create(
      const CreateClientInput(fullName: 'Ana Cruz'),
    )).id!;
    otherClientId = (await clients.create(
      const CreateClientInput(fullName: 'Ben Santos'),
    )).id!;
  });

  tearDown(() async => db.close());

  test(
    'creates an intervention with planned status and searchable links',
    () async {
      final caseRecord = await CaseRepository(db).create(
        CreateCaseInput(clientId: clientId, openedAt: DateTime(2026, 1, 1)),
      );
      final created = await repo.create(
        CreateInterventionInput(
          clientId: clientId,
          caseId: caseRecord.id,
          title: 'Attendance support',
          type: 'Academic support',
          startDate: DateTime(2026, 2, 1),
          targetDate: DateTime(2026, 3, 1),
        ),
      );

      expect(created.status, InterventionStatus.planned);
      expect(created.clientName, 'Ana Cruz');
      expect(created.caseRef, caseRecord.caseRef);
      expect(
        (await repo.list(const InterventionQuery(searchText: 'attendance')))
            .single
            .id,
        created.id,
      );
    },
  );

  test('group counseling saves multiple participants', () async {
    final created = await repo.create(
      CreateInterventionInput(
        clientId: clientId,
        participantIds: [clientId, otherClientId],
        title: 'Peer support group',
        type: 'Group counseling',
        startDate: DateTime(2026, 2, 1),
      ),
    );

    expect(created.participantIds, containsAll([clientId, otherClientId]));
    expect(created.participantLabel, contains('Ana Cruz'));
    expect(created.participantLabel, contains('Ben Santos'));
    expect(
      (await repo.list(const InterventionQuery())).single.participantIds,
      containsAll([clientId, otherClientId]),
    );
  });

  test('stores a required custom intervention type for Other', () async {
    final created = await repo.create(
      CreateInterventionInput(
        clientId: clientId,
        title: 'Community session',
        type: 'Other',
        customType: 'Community outreach',
        startDate: DateTime(2026, 2, 1),
      ),
    );

    expect(created.type, 'Other');
    expect(created.customType, 'Community outreach');
    await expectLater(
      repo.create(
        CreateInterventionInput(
          clientId: clientId,
          title: 'Unspecified',
          type: 'Other',
          startDate: DateTime(2026, 2, 1),
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('requires a linked case to belong to the selected client', () async {
    final caseRecord = await CaseRepository(db).create(
      CreateCaseInput(clientId: otherClientId, openedAt: DateTime(2026, 1, 1)),
    );
    await expectLater(
      repo.create(
        CreateInterventionInput(
          clientId: clientId,
          caseId: caseRecord.id,
          title: 'Support',
          type: 'Referral',
          startDate: DateTime(2026, 2, 1),
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('completion stamps date and audit log excludes private notes', () async {
    final created = await repo.create(
      CreateInterventionInput(
        clientId: clientId,
        title: 'Attendance support',
        type: 'Academic support',
        description: 'PRIVATE SUPPORT DETAILS',
        startDate: DateTime(2026, 2, 1),
      ),
    );
    final completed = await repo.update(
      Intervention(
        id: created.id,
        clientId: created.clientId,
        title: created.title,
        type: created.type,
        description: created.description,
        goal: created.goal,
        status: InterventionStatus.completed,
        startDate: created.startDate,
        targetDate: created.targetDate,
        outcome: 'PRIVATE OUTCOME',
        createdAt: created.createdAt,
        updatedAt: created.updatedAt,
      ),
    );
    expect(completed.completedAt, isNotNull);
    final logs = await db.query('audit_logs');
    final contents = logs.map((row) => row['detail'] ?? '').join(' ');
    expect(contents, isNot(contains('PRIVATE SUPPORT DETAILS')));
    expect(contents, isNot(contains('PRIVATE OUTCOME')));
  });

  test('rejects a target date before the start date', () async {
    await expectLater(
      repo.create(
        CreateInterventionInput(
          clientId: clientId,
          title: 'Attendance support',
          type: 'Academic support',
          startDate: DateTime(2026, 2, 2),
          targetDate: DateTime(2026, 2, 1),
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });
}
