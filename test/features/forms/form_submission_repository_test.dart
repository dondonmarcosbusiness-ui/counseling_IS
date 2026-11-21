import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/forms/data/form_submission_repository.dart';
import 'package:counseling_is/features/forms/domain/form_submission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late FormSubmissionRepository repository;

  setUp(() async {
    db = await openTestDatabase();
    repository = FormSubmissionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates and reads a form record with client and typed data', () async {
    final client = await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Ana Cruz'));
    final created = await repository.create(
      formId: 'referral',
      clientId: client.id!,
      data: const {
        'learner_name': 'Ana Cruz',
        'date_received': '2026-10-30',
        'reasons': ['Academic difficulty', 'Peer conflict'],
        'notified_parent': true,
      },
    );

    expect(created.id, isNotNull);
    expect(created.clientId, client.id!);
    expect(created.clientName, 'Ana Cruz');
    expect(created.data['learner_name'], 'Ana Cruz');
    expect(created.data['reasons'], ['Academic difficulty', 'Peer conflict']);
    expect(created.data['notified_parent'], isTrue);
  });

  test('updates and filters saved form records', () async {
    final client = await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Ben Santos'));
    final created = await repository.create(
      formId: 'home_visit',
      clientId: client.id!,
      data: const {'visit_date': '2026-10-28'},
    );

    final updated = await repository.update(
      FormSubmission(
        id: created.id,
        formId: created.formId,
        clientId: created.clientId,
        data: const {'visit_date': '2026-10-29'},
        createdAt: created.createdAt,
        updatedAt: created.updatedAt,
      ),
    );

    expect(updated.data['visit_date'], '2026-10-29');
    expect(await repository.list(searchText: 'ben'), hasLength(1));
    expect(await repository.list(formId: 'home_visit'), hasLength(1));
    expect(await repository.list(formId: 'referral'), isEmpty);
  });

  test('deletes saved form records', () async {
    final created = await repository.create(
      formId: 'care_center_log',
      data: const {'month_year': 'October 2026'},
    );

    await repository.delete(created.id!);

    expect(await repository.list(), isEmpty);
  });

  group('saveBatch', () {
    test('creates one record per form sharing a batch id', () async {
      final client = await ClientRepository(db)
          .create(const CreateClientInput(fullName: 'Clara Reyes'));

      final saved = await repository.saveBatch(
        clientId: client.id!,
        batchId: 'batch-1000',
        dataByForm: const {
          'counseling_intake': {'referral_other': 'Peer conflict'},
          'referral': {'other_reason': 'Tardiness'},
          'home_visit': {'visit_time': '3:00 PM'},
        },
      );

      expect(
        saved.keys,
        containsAll(['counseling_intake', 'referral', 'home_visit']),
      );
      expect(saved.values.map((record) => record.clientId).toSet(), {
        client.id!,
      });

      final rows = await db.query(
        'form_submissions',
        where: 'batch_id = ?',
        whereArgs: ['batch-1000'],
      );
      expect(rows, hasLength(3));
      expect(rows.map((row) => row['form_id']).toSet(), {
        'counseling_intake',
        'referral',
        'home_visit',
      });
      expect(rows.every((row) => row['client_id'] == client.id!), isTrue);
    });

    test('updates existing records instead of duplicating them', () async {
      final client = await ClientRepository(db)
          .create(const CreateClientInput(fullName: 'Dina Lopez'));
      final existing = await repository.create(
        formId: 'referral',
        clientId: client.id!,
        data: const {'other_reason': 'Old reason'},
      );

      final saved = await repository.saveBatch(
        clientId: client.id!,
        batchId: 'batch-2000',
        dataByForm: const {
          'referral': {'other_reason': 'New reason'},
          'home_visit': {'visit_time': '4:00 PM'},
        },
        existingIdsByForm: {'referral': existing.id},
      );

      expect(saved['referral']!.id, existing.id);
      expect(saved['referral']!.data['other_reason'], 'New reason');

      final referralRows = await db.query(
        'form_submissions',
        where: "form_id = 'referral' AND client_id = ?",
        whereArgs: [client.id!],
      );
      expect(referralRows, hasLength(1));
      expect(referralRows.single['batch_id'], 'batch-2000');

      final decoded = (await repository.latestForClient(
        client.id!,
        'referral',
      ))!.data;
      expect(decoded['other_reason'], 'New reason');
    });

    test('rejects an empty batch or missing batch id', () async {
      final client = await ClientRepository(db)
          .create(const CreateClientInput(fullName: 'Ella Cruz'));

      expect(
        () => repository.saveBatch(
          clientId: client.id!,
          batchId: '   ',
          dataByForm: const {
            'referral': {'other_reason': 'x'},
          },
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => repository.saveBatch(
          clientId: client.id!,
          batchId: 'batch-3000',
          dataByForm: const {},
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  test('lists batches newest first with student and form IDs', () async {
    final client = await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Fina Santos'));
    await repository.saveBatch(
      clientId: client.id!,
      batchId: 'batch-old',
      dataByForm: const {
        'referral': {'other_reason': 'Old'},
      },
    );
    await repository.saveBatch(
      clientId: client.id!,
      batchId: 'batch-new',
      dataByForm: const {
        'counseling_intake': {'referral_other': 'A'},
        'home_visit': {'visit_time': '9:00 AM'},
      },
    );

    final batches = await repository.listBatches();

    expect(batches, hasLength(2));
    expect(batches.first.batchId, 'batch-new');
    expect(batches.first.clientName, 'Fina Santos');
    expect(batches.first.formCount, 2);
    expect(
      batches.first.formIds,
      unorderedEquals(['counseling_intake', 'home_visit']),
    );
    expect(batches.last.batchId, 'batch-old');
    expect(batches.last.formCount, 1);

    // Unbatched records never appear in the batch list.
    await repository.create(
      formId: 'referral',
      data: const {'other_reason': 'x'},
    );
    expect(await repository.listBatches(), hasLength(2));
  });

  test('returns a batch submissions and unlinking keeps the records', () async {
    final client = await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Gina Torres'));
    await repository.saveBatch(
      clientId: client.id!,
      batchId: 'batch-4000',
      dataByForm: const {
        'counseling_intake': {'referral_other': 'A'},
        'referral': {'other_reason': 'B'},
      },
    );

    final records = await repository.batchSubmissions('batch-4000');
    expect(records, hasLength(2));
    expect(
      records.map((record) => record.formId),
      unorderedEquals(['counseling_intake', 'referral']),
    );
    expect(
      records.every((record) => record.clientName == 'Gina Torres'),
      isTrue,
    );

    await repository.unlinkBatch('batch-4000');

    expect(await repository.batchSubmissions('batch-4000'), isEmpty);
    expect(await repository.listBatches(), isEmpty);
    // The records themselves survive, still linked to the student.
    final kept = await repository.list();
    expect(kept, hasLength(2));
    expect(kept.every((record) => record.clientId == client.id!), isTrue);
    expect(await repository.latestForClient(client.id!, 'referral'), isNotNull);

    expect(
      () => repository.unlinkBatch('batch-missing'),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('latestForClient returns the most recent record per form', () async {
    final client = await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Helen Cruz'));
    await repository.saveBatch(
      clientId: client.id!,
      batchId: 'batch-5000',
      dataByForm: const {
        'referral': {'other_reason': 'First'},
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    // Saving again without linking the existing ID creates a second row for
    // the same student + form; latestForClient must return the newer one.
    await repository.saveBatch(
      clientId: client.id!,
      batchId: 'batch-5001',
      dataByForm: const {
        'referral': {'other_reason': 'Second'},
      },
    );

    final latest = await repository.latestForClient(client.id!, 'referral');
    expect(latest, isNotNull);
    expect(latest!.data['other_reason'], 'Second');
    expect(await repository.latestForClient(client.id!, 'home_visit'), isNull);

    final otherClient = await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Ivy Ramos'));
    expect(
      await repository.latestForClient(otherClient.id!, 'referral'),
      isNull,
    );
  });
}
