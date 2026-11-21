import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/clients/presentation/client_form_dialog.dart';
import 'package:counseling_is/features/clients/presentation/clients_screen.dart';
import 'package:counseling_is/features/clients/presentation/student_sheet_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
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

  /// Text input rendered under the given [AppField] label.
  Finder fieldLabeled(String label) {
    final appField = find.byWidgetPredicate(
      (widget) => widget is AppField && widget.label == label,
      description: 'AppField "$label"',
    );
    return find.descendant(of: appField, matching: find.byType(TextFormField));
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

  testWidgets('new student dialog collects the information sheet fields', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'New student').first);
    await tester.pumpAndSettle();

    expect(find.text('I. PERSONAL INFORMATION'), findsOneWidget);
    expect(find.text('PERSON TO NOTIFY IN CASE OF EMERGENCY'), findsOneWidget);
    expect(find.text('II. FAMILY'), findsOneWidget);
    expect(find.text('III. CONFIDENTIAL WELL-BEING CHECK'), findsOneWidget);
    expect(find.text('INTAKE NOTES'), findsOneWidget);

    await tester.enterText(fieldLabeled('First name *'), 'Maria');
    await tester.enterText(
      fieldLabeled('Grade and section'),
      'Grade 9 - Sampaguita',
    );
    await tester.enterText(
      fieldLabeled('Learner reference no.'),
      '123456789012',
    );
    await tester.enterText(
      fieldLabeled('Permanent address'),
      'Purok 3, Carranglan, Nueva Ecija',
    );
    await tester.enterText(fieldLabeled('Hobbies / interests'), 'Reading');

    await tester.tap(find.text('Create student'));
    await tester.pumpAndSettle();

    final stored = await repo.search(const ClientQuery());
    expect(stored, hasLength(1));
    expect(stored.single.firstName, 'Maria');
    expect(stored.single.gradeSection, 'Grade 9 - Sampaguita');
    expect(stored.single.learnerNo, '123456789012');
    expect(stored.single.address, 'Purok 3, Carranglan, Nueva Ecija');
    expect(stored.single.hobbies, 'Reading');
  });

  testWidgets('student details present the recorded information sheet', (
    tester,
  ) async {
    final client = await repo.create(
      const CreateClientInput(
        fullName: 'Maria Clara Santos',
        firstName: 'Maria Clara',
        lastName: 'Santos',
        gradeSection: 'Grade 9 - Sampaguita',
        learnerNo: '123456789012',
        sex: 'Female',
        livingWith: 'Relatives',
        emergencyName: 'Juan Santos',
        emergencyRelationship: 'Father',
        fatherName: 'Juan Dela Santos',
        fatherJob: 'Farmer',
        screenAbuse: 'Yes',
        screenSuicidalThoughts: 'No',
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.text(client.fullName));
    await tester.pumpAndSettle();

    expect(find.text('STUDENT DETAILS'), findsOneWidget);
    expect(find.text('PERSON TO NOTIFY IN CASE OF EMERGENCY'), findsOneWidget);
    expect(find.text('FAMILY'), findsOneWidget);
    expect(find.text('CONFIDENTIAL WELL-BEING CHECK'), findsOneWidget);
    expect(find.text('Grade 9 - Sampaguita'), findsOneWidget);
    expect(find.text('123456789012'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Relatives'), findsOneWidget);
    expect(find.text('Juan Santos'), findsOneWidget);
    expect(find.text('Juan Dela Santos'), findsOneWidget);
    expect(
      find.text('Experiences abuse or harm (sexual / physical)'),
      findsOneWidget,
    );
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Wants to end life'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });

  testWidgets('previews the information sheet from the list and the details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = await repo.create(
      const CreateClientInput(
        fullName: 'Maria Clara Santos',
        firstName: 'Maria Clara',
        lastName: 'Santos',
        gradeSection: 'Grade 9 - Sampaguita',
        sex: 'Female',
        livingWith: 'Relatives',
        screenAbuse: 'Yes',
      ),
    );
    await pumpScreen(tester);

    // The row action opens the print-ready sheet.
    await tester.tap(find.byTooltip('Preview information sheet'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(StudentSheetPreviewDialog), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.textContaining('ready to print'), findsOneWidget);
    expect(find.byTooltip('Close preview'), findsOneWidget);

    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentSheetPreviewDialog), findsNothing);

    // The student's detail window offers the same preview.
    await tester.tap(find.text(client.fullName));
    await tester.pumpAndSettle();
    expect(find.text('STUDENT DETAILS'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Preview'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(StudentSheetPreviewDialog), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.textContaining('ready to print'), findsOneWidget);
  });
}
