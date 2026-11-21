import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:counseling_is/core/widgets/success_banner.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/forms/data/form_submission_repository.dart';
import 'package:counseling_is/features/forms/presentation/batch_fill_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late ClientRepository clients;
  late FormSubmissionRepository submissions;

  setUp(() async {
    db = await openTestDatabase();
    clients = ClientRepository(db);
    submissions = FormSubmissionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClientRepository>.value(value: clients),
          Provider<FormSubmissionRepository>.value(value: submissions),
        ],
        child: const MaterialApp(home: Scaffold(body: BatchFillScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder fieldByLabel(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(AppField)),
    matching: find.byType(TextField),
  );

  Future<void> selectStudent(WidgetTester tester, String name) async {
    final dropdown = find.byType(AppDropdownFormField<int>);
    expect(dropdown, findsOneWidget);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'fills four forms on one merged page and saves them as one batch',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = await clients.create(
        const CreateClientInput(fullName: 'Ana Batch'),
      );
      await pumpScreen(tester);

      expect(find.text('Batch fill forms'), findsOneWidget);
      expect(find.text('Save all'), findsNothing);
      // The confidential child-protection intake and the retired CC Form 1
      // are not offered in the batch picker.
      expect(find.textContaining('Child Protection Intake'), findsNothing);
      expect(find.text('CC Form 1 · Student Information Sheet'), findsNothing);
      // Open stays disabled until a student and a form are chosen.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Open merged form'),
            )
            .onPressed,
        isNull,
      );

      await selectStudent(tester, 'Ana Batch');
      expect(find.text('No record yet for this student'), findsNWidgets(10));
      expect(find.text('10 selected'), findsNothing);

      Future<void> tick(String title) async {
        final tile = find.widgetWithText(CheckboxListTile, title);
        expect(tile, findsOneWidget);
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }

      await tick('GS Form 2 · Counseling Intake Form');
      await tick('CC Form 3 · Individual Counseling Record');
      await tick('CC Form 4 · Referral Form');
      await tick('CC Form 5 · Home Visit Report');
      expect(find.text('4 selected'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Open merged form'));
      await tester.pumpAndSettle();

      // Merged page: batch heading, shared student block once, one banner
      // per chosen form, and no single-form-only actions.
      expect(find.text('BATCH FILL'), findsOneWidget);
      expect(find.text('COMBINED STUDENT FORMS'), findsOneWidget);
      expect(find.text('STUDENT INFORMATION'), findsOneWidget);
      expect(find.text('GS Form 2 · Counseling Intake Form'), findsOneWidget);
      expect(
        find.text('CC Form 3 · Individual Counseling Record'),
        findsOneWidget,
      );
      expect(find.text('CC Form 4 · Referral Form'), findsOneWidget);
      expect(find.text('CC Form 5 · Home Visit Report'), findsOneWidget);
      expect(find.text('Save all'), findsOneWidget);
      expect(find.text('Save form'), findsNothing);
      expect(
        find.byTooltip('Print (exact form layout, opens Word)'),
        findsNothing,
      );
      expect(find.text('Batch for Ana Batch'), findsOneWidget);
      expect(find.text('4 forms merged in one page'), findsOneWidget);

      // Answer two of the four forms with a uniquely labelled field each.
      await tester.enterText(
        fieldByLabel('Other referral reason'),
        'Peer conflict in class',
      );
      await tester.enterText(fieldByLabel('Session duration'), '45 minutes');
      await tester.pumpAndSettle();

      // Focusing the last field scrolled the merged page down to it, so bring
      // the save toolbar back into view before tapping it.
      final saveAll = find.widgetWithText(FilledButton, 'Save all');
      await tester.ensureVisible(saveAll);
      await tester.pumpAndSettle();
      await tester.tap(saveAll);
      await tester.pumpAndSettle();

      expect(find.byType(SuccessBanner), findsOneWidget);
      expect(
        find.text('Saved 2 of 4 forms — 2 empty forms skipped.'),
        findsOneWidget,
      );

      // The confirmation stays on the page until dismissed.
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(SuccessBanner), findsNothing);

      final rows = await db.query(
        'form_submissions',
        where: 'client_id = ?',
        whereArgs: [client.id],
      );
      expect(rows, hasLength(2));
      expect(
        rows.map((row) => row['form_id']),
        unorderedEquals(['counseling_intake', 'individual_counseling']),
      );
      final batchIds = rows.map((row) => row['batch_id']).toSet();
      expect(batchIds, hasLength(1));
      expect(batchIds.single, isNotNull);

      final intake = rows.singleWhere(
        (row) => row['form_id'] == 'counseling_intake',
      );
      expect(intake['form_data'], contains('Peer conflict in class'));
      final record = rows.singleWhere(
        (row) => row['form_id'] == 'individual_counseling',
      );
      expect(record['form_data'], contains('45 minutes'));

      // Leave the merged page and confirm the batch is listed.
      final changeSelection = find.byTooltip('Change selection');
      await tester.ensureVisible(changeSelection);
      await tester.pumpAndSettle();
      await tester.tap(changeSelection);
      await tester.pumpAndSettle();
      final savedBatchesTab = find.text('Saved batches');
      expect(savedBatchesTab, findsOneWidget);
      await tester.ensureVisible(savedBatchesTab);
      await tester.pumpAndSettle();
      await tester.tap(savedBatchesTab);
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Ana Batch'), findsOneWidget);
      expect(find.text('2 forms'), findsOneWidget);
    },
  );

  testWidgets('reopening a saved batch updates records without duplicating', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = await clients.create(
      const CreateClientInput(fullName: 'Ben Batch'),
    );
    final saved = await submissions.saveBatch(
      clientId: client.id!,
      batchId: 'batch-seeded',
      dataByForm: const {
        'counseling_intake': {'referral_other': 'Peer conflict in class'},
        'individual_counseling': {'session_duration': '45 minutes'},
      },
    );
    final originalIds = {
      for (final entry in saved.entries) entry.key: entry.value.id,
    };

    await pumpScreen(tester);

    await tester.tap(find.text('Saved batches'));
    await tester.pumpAndSettle();
    expect(find.text('Ben Batch'), findsOneWidget);
    expect(find.text('2 forms'), findsOneWidget);

    await tester.tap(find.byTooltip('Open batch'));
    await tester.pumpAndSettle();

    // The reopened batch prefills both saved forms.
    expect(find.text('BATCH FILL'), findsOneWidget);
    expect(find.text('GS Form 2 · Counseling Intake Form'), findsOneWidget);
    expect(
      find.text('CC Form 3 · Individual Counseling Record'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(fieldByLabel('Other referral reason'))
          .controller!
          .text,
      'Peer conflict in class',
    );
    expect(
      tester
          .widget<TextField>(fieldByLabel('Session duration'))
          .controller!
          .text,
      '45 minutes',
    );
    expect(
      find.byTooltip('Print (exact form layout, opens Word)'),
      findsNothing,
    );

    // Edit one form and save: the same two records are updated in place.
    await tester.enterText(
      fieldByLabel('Other referral reason'),
      'Updated concern',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save all'));
    await tester.pumpAndSettle();

    expect(find.text('Saved 2 forms.'), findsOneWidget);

    final rows = await db.query('form_submissions');
    expect(rows, hasLength(2));
    expect(rows.map((row) => row['id']).toSet(), originalIds.values.toSet());
    expect(rows.map((row) => row['batch_id']).toSet(), {'batch-seeded'});
    final intake = rows.singleWhere(
      (row) => row['form_id'] == 'counseling_intake',
    );
    expect(intake['form_data'], contains('Updated concern'));
    expect(intake['form_data'], isNot(contains('Peer conflict in class')));
    final record = rows.singleWhere(
      (row) => row['form_id'] == 'individual_counseling',
    );
    expect(record['form_data'], contains('45 minutes'));
  });
}
