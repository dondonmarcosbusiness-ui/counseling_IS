import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/time.dart';
import 'package:counseling_is/features/cases/data/case_repository.dart';
import 'package:counseling_is/features/cases/domain/case_record.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late ClientRepository clients;
  late CaseRepository repo;
  late Client client;
  late Client otherClient;

  setUp(() async {
    db = await openTestDatabase();
    clients = ClientRepository(db);
    repo = CaseRepository(db);
    client = await clients.create(
      const CreateClientInput(fullName: 'Ana Cruz'),
    );
    otherClient = await clients.create(
      const CreateClientInput(fullName: 'Ben Santos'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('create assigns sequential case references and starts open', () async {
    final year = DateTime.now().year;
    final first = await repo.create(
      CreateCaseInput(
        clientId: client.id!,
        openedAt: DateTime(2026, 1, 10),
        summary: 'Anxiety reported during intake',
      ),
    );
    final second = await repo.create(
      CreateCaseInput(
        clientId: otherClient.id!,
        openedAt: DateTime(2026, 2, 1),
      ),
    );

    expect(first.caseRef, 'CASE-$year-0001');
    expect(second.caseRef, 'CASE-$year-0002');
    expect(first.status, CaseStatus.open);
    expect(first.closedAt, isNull);
    expect(first.clientName, 'Ana Cruz');
    expect(first.isOpen, isTrue);
  });

  test(
    'case history records creation, safe updates and manual events',
    () async {
      final created = await repo.create(
        CreateCaseInput(
          clientId: client.id!,
          openedAt: DateTime(2026, 1, 10),
          summary: 'PRIVATE CASE SUMMARY',
        ),
      );
      await repo.update(
        created.copyWith(
          status: CaseStatus.inProgress,
          summary: 'UPDATED PRIVATE SUMMARY',
        ),
      );
      await repo.recordTimelineEvent(
        caseId: created.id!,
        occurredAt: DateTime(2026, 2, 1),
        eventType: 'disciplinary_action',
        title: 'Parent conference',
        description: 'Follow-up conference held.',
      );

      final events = await repo.timeline(created.id!);
      expect(events, hasLength(3));
      expect(events.map((event) => event.title), contains('Parent conference'));
      expect(events.map((event) => event.title), contains('Case opened'));
      expect(events.map((event) => event.title), contains('Case updated'));
      final logs = await db.query('audit_logs');
      final logText = logs.map((row) => row['detail'] ?? '').join(' ');
      expect(logText, isNot(contains('PRIVATE CASE SUMMARY')));
      expect(logText, isNot(contains('UPDATED PRIVATE SUMMARY')));
    },
  );

  test(
    'completing a follow-up clears its date and records case history',
    () async {
      final today = DateTime.now();
      final record = await repo.create(
        CreateCaseInput(
          clientId: client.id!,
          openedAt: DateTime(today.year, today.month, today.day - 1),
          followUpDate: DateTime(today.year, today.month, today.day),
        ),
      );

      await repo.completeFollowUp(record.id!);

      final updated = await repo.getById(record.id!);
      final events = await repo.timeline(record.id!);
      expect(updated.followUpDate, isNull);
      expect(
        events.map((event) => event.eventType),
        contains('follow_up_completed'),
      );
      expect(
        events.map((event) => event.title),
        contains('Follow-up completed'),
      );
      expect(
        events.map((event) => event.description),
        contains(
          'Scheduled follow-up date: ${dateToDb(record.followUpDate!)}.',
        ),
      );
    },
  );

  test('completing a case without a scheduled follow-up is rejected', () async {
    final record = await repo.create(
      CreateCaseInput(clientId: client.id!, openedAt: DateTime(2026, 1, 10)),
    );

    await expectLater(
      repo.completeFollowUp(record.id!),
      throwsA(isA<ValidationException>()),
    );
  });

  test('create rejects follow-up date before opening date', () async {
    await expectLater(
      repo.create(
        CreateCaseInput(
          clientId: client.id!,
          openedAt: DateTime(2026, 2, 1),
          followUpDate: DateTime(2026, 1, 31),
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('create rejects missing client', () async {
    await expectLater(
      repo.create(
        CreateCaseInput(clientId: 99999, openedAt: DateTime(2026, 2, 1)),
      ),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('closing a case stamps closed_at with today', () async {
    final created = await repo.create(
      CreateCaseInput(clientId: client.id!, openedAt: DateTime(2026, 1, 10)),
    );
    final closed = await repo.update(
      created.copyWith(
        status: CaseStatus.closed,
        closureNotes: 'Resolved with referral',
      ),
    );

    expect(closed.status, CaseStatus.closed);
    final today = DateTime.now();
    expect(closed.closedAt, DateTime(today.year, today.month, today.day));
    expect(closed.closureNotes, 'Resolved with referral');
    expect(closed.isOpen, isFalse);
  });

  test(
    'updating an already-closed case keeps the original closed_at',
    () async {
      final created = await repo.create(
        CreateCaseInput(clientId: client.id!, openedAt: DateTime(2026, 1, 10)),
      );
      await db.update(
        'case_records',
        {
          'status': 'closed',
          'closed_at': '2020-01-01',
          'closure_notes': 'First closure',
        },
        where: 'id = ?',
        whereArgs: [created.id],
      );

      final stored = await repo.getById(created.id!);
      final updated = await repo.update(
        stored.copyWith(closureNotes: 'Revised note'),
      );

      expect(updated.closedAt, DateTime(2020, 1, 1));
      expect(updated.closureNotes, 'Revised note');
    },
  );

  test('reopening clears closed_at and closure notes', () async {
    final created = await repo.create(
      CreateCaseInput(clientId: client.id!, openedAt: DateTime(2026, 1, 10)),
    );
    final closed = await repo.update(
      created.copyWith(status: CaseStatus.closed),
    );
    expect(closed.closedAt, isNotNull);

    final reopened = await repo.update(
      closed.copyWith(status: CaseStatus.inProgress),
    );
    expect(reopened.status, CaseStatus.inProgress);
    expect(reopened.closedAt, isNull);
    expect(reopened.closureNotes, isNull);
  });

  test('update validates dates and throws for missing id', () async {
    final created = await repo.create(
      CreateCaseInput(clientId: client.id!, openedAt: DateTime(2026, 2, 1)),
    );

    await expectLater(
      repo.update(
        created.copyWith(
          openedAt: DateTime(2026, 3, 1),
          followUpDate: DateTime(2026, 2, 15),
        ),
      ),
      throwsA(isA<ValidationException>()),
    );

    await expectLater(
      repo.update(
        CaseRecord(
          id: 99999,
          caseRef: 'CASE-2026-9999',
          clientId: client.id!,
          openedAt: DateTime(2026, 2, 1),
          createdAt: DateTime(2026, 2, 1),
          updatedAt: DateTime(2026, 2, 1),
        ),
      ),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('list filters by status, client and search', () async {
    final openCase = await repo.create(
      CreateCaseInput(clientId: client.id!, openedAt: DateTime(2026, 1, 10)),
    );
    final otherCase = await repo.create(
      CreateCaseInput(
        clientId: otherClient.id!,
        openedAt: DateTime(2026, 2, 1),
      ),
    );
    await repo.update(otherCase.copyWith(status: CaseStatus.inProgress));

    final inProgress = await repo.list(
      const CaseQuery(status: CaseStatus.inProgress),
    );
    expect(inProgress.map((c) => c.id), [otherCase.id]);

    final openCases = await repo.list(const CaseQuery(status: CaseStatus.open));
    expect(openCases.map((c) => c.id), [openCase.id]);

    final byClient = await repo.list(CaseQuery(clientId: client.id));
    expect(byClient.map((c) => c.id), [openCase.id]);

    final year = DateTime.now().year;
    final byRef = await repo.list(CaseQuery(searchText: 'CASE-$year-000'));
    expect(byRef, hasLength(2));

    final byName = await repo.list(const CaseQuery(searchText: 'ben'));
    expect(byName.map((c) => c.id), [otherCase.id]);
  });
}
