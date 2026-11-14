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
      clientId: client.id,
      data: const {
        'learner_name': 'Ana Cruz',
        'date_received': '2026-10-30',
        'reasons': ['Academic difficulty', 'Peer conflict'],
        'notified_parent': true,
      },
    );

    expect(created.id, isNotNull);
    expect(created.clientId, client.id);
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
      clientId: client.id,
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
}
