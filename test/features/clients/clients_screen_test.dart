import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/clients/presentation/client_form_dialog.dart';
import 'package:counseling_is/features/clients/presentation/clients_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late ClientRepository repo;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<ClientRepository>.value(value: repo)],
        child: MaterialApp(home: Scaffold(body: ClientsScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    db = await openTestDatabase();
    repo = ClientRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('shows empty state then creates a student through the dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1365, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpScreen(tester);
    expect(find.text('No students yet'), findsOneWidget);

    final searchCenterY = tester.getCenter(find.byType(TextField).first).dy;
    expect(
      tester.getCenter(find.byTooltip('Refresh')).dy,
      closeTo(searchCenterY, 1),
    );
    expect(
      tester
          .getCenter(find.widgetWithText(FilledButton, 'New student').first)
          .dy,
      closeTo(searchCenterY, 1),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'New student').first);
    await tester.pumpAndSettle();
    expect(find.text('New student'), findsWidgets);
    expect(find.text('Create student'), findsOneWidget);

    final nameFields = find.byType(TextFormField);
    await tester.enterText(nameFields.at(0), 'Widget');
    await tester.enterText(nameFields.at(1), 'Test');
    await tester.enterText(nameFields.at(2), 'Client');
    await tester.enterText(nameFields.at(3), 'Jr.');
    await tester.tap(find.text('Create student'));
    await tester.pumpAndSettle();

    expect(find.text('Widget Test Client Jr.'), findsOneWidget);
    expect(find.textContaining('CLI-'), findsOneWidget);

    final stored = await repo.search(const ClientQuery());
    expect(stored, hasLength(1));
    expect(stored.single.fullName, 'Widget Test Client Jr.');
    expect(stored.single.firstName, 'Widget');
    expect(stored.single.middleName, 'Test');
    expect(stored.single.lastName, 'Client');
    expect(stored.single.suffix, 'Jr.');
  });

  testWidgets('client table fills the available content width', (tester) async {
    tester.view.physicalSize = const Size(1365, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await repo.create(const CreateClientInput(fullName: 'Aisha Rahman'));
    await pumpScreen(tester);

    expect(tester.getSize(find.byType(DataTable)).width, greaterThan(1250));
  });

  testWidgets('checkbox selection batches archive and restore actions', (
    tester,
  ) async {
    final client = await repo.create(
      const CreateClientInput(fullName: 'Aisha Rahman'),
    );
    await pumpScreen(tester);

    final rowCheckboxes = find.descendant(
      of: find.byType(DataTable),
      matching: find.byType(Checkbox),
    );
    await tester.tap(rowCheckboxes.last);
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Archive (1)'), findsOneWidget);
    expect(find.text('STUDENT DETAILS'), findsNothing);

    await tester.tap(find.text('Archive (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Archive selected students?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect((await repo.getById(client.id!)).status, ClientStatus.archived);
    expect(find.text('1 selected'), findsNothing);

    final refreshedRowCheckboxes = find.descendant(
      of: find.byType(DataTable),
      matching: find.byType(Checkbox),
    );
    await tester.tap(refreshedRowCheckboxes.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();

    expect((await repo.getById(client.id!)).status, ClientStatus.active);
  });

  testWidgets('checkbox selection batch deletes students with confirmation', (
    tester,
  ) async {
    final client = await repo.create(
      const CreateClientInput(fullName: 'Aisha Rahman'),
    );
    await pumpScreen(tester);

    final rowCheckboxes = find.descendant(
      of: find.byType(DataTable),
      matching: find.byType(Checkbox),
    );
    await tester.tap(rowCheckboxes.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Delete selected students?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repo.count(), 0);
    expect(find.text('No students yet'), findsOneWidget);
    await expectLater(
      repo.getById(client.id!),
      throwsA(isA<NotFoundException>()),
    );
  });

  testWidgets('batch delete shows an error when selected client has history', (
    tester,
  ) async {
    final client = await repo.create(
      const CreateClientInput(fullName: 'Linked Client'),
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final year = DateTime.now().toUtc().year;
    await db.insert('case_records', {
      'case_ref': 'CASE-$year-0001',
      'client_id': client.id,
      'opened_at': now,
      'status': 'open',
      'created_at': now,
      'updated_at': now,
    });
    await pumpScreen(tester);

    final rowCheckboxes = find.descendant(
      of: find.byType(DataTable),
      matching: find.byType(Checkbox),
    );
    await tester.tap(rowCheckboxes.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 cases'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(await repo.count(), 1);
  });

  testWidgets('validation blocks saving without a first name', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'New student').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create student'));
    await tester.pumpAndSettle();

    expect(find.text('First name is required'), findsOneWidget);
    expect(find.text('First name *'), findsOneWidget);
    expect(await repo.search(const ClientQuery()), isEmpty);

    final cancel = find.text('Cancel');
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.text('No students yet'), findsOneWidget);
  });

  testWidgets('client details dialog presents information and actions', (
    tester,
  ) async {
    final client = await repo.create(
      const CreateClientInput(
        fullName: 'Aisha Rahman',
        phone: '555-0198',
        intakeNotes: 'Initial consultation requested.',
      ),
    );
    await pumpScreen(tester);

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Reference'), findsOneWidget);
    await tester.tap(find.text(client.fullName));
    await tester.pumpAndSettle();

    expect(find.text('STUDENT DETAILS'), findsOneWidget);
    expect(find.text(client.referenceNo), findsWidgets);
    expect(find.text('555-0198'), findsWidgets);
    expect(find.text('Initial consultation requested.'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('date picker keeps comfortable padding from window edges', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(513, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<ClientRepository>.value(value: repo)],
        child: const MaterialApp(home: Scaffold(body: ClientFormDialog())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not set'));
    await tester.pumpAndSettle();

    final datePicker = find.byType(DatePickerDialog);
    final rect = tester.getRect(datePicker);
    expect(rect.left, greaterThanOrEqualTo(16));
    expect(rect.right, lessThanOrEqualTo(513 - 16));
  });

  testWidgets('date of birth field matches text input height', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<ClientRepository>.value(value: repo)],
        child: const MaterialApp(home: Scaffold(body: ClientFormDialog())),
      ),
    );
    await tester.pumpAndSettle();

    final textFieldHeight = tester
        .getSize(find.byType(TextFormField).first)
        .height;
    final dateField = find.ancestor(
      of: find.text('Not set'),
      matching: find.byType(InkWell),
    );
    final dateFieldHeight = tester.getSize(dateField).height;

    expect(dateFieldHeight, textFieldHeight);
  });
}
