import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:counseling_is/core/widgets/picker_field.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/forms/data/form_submission_repository.dart';
import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:counseling_is/features/forms/domain/form_submission.dart';
import 'package:counseling_is/features/forms/presentation/forms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await openTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('opens and saves a digital form', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/forms',
      routes: [
        GoRoute(
          path: '/forms',
          builder: (_, _) => const Scaffold(body: FormsScreen()),
          routes: [
            GoRoute(
              path: ':formId',
              builder: (_, state) => CounselingFormPage(
                form: counselingFormById(state.pathParameters['formId']!)!,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClientRepository>(create: (_) => ClientRepository(db)),
          Provider<FormSubmissionRepository>(
            create: (_) => FormSubmissionRepository(db),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Available forms'), findsNothing);
    expect(find.text('Form type'), findsNothing);
    expect(find.byType(AppDropdownFormField<String?>), findsNothing);
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('No saved forms yet'), findsOneWidget);
    expect(find.text('Ready to complete'), findsNothing);

    await tester.tap(find.text('Fill form'));
    await tester.pumpAndSettle();

    expect(find.text('Available forms'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(12));
    expect(find.text('CC Form 1 · Student Information Sheet'), findsWidgets);
    expect(find.text('Save form'), findsOneWidget);
    expect(find.byKey(const ValueKey('sex_Male')), findsOneWidget);
    expect(find.byKey(const ValueKey('sex_Female')), findsOneWidget);
    expect(find.byKey(const ValueKey('sex_Prefer not to say')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText != null,
      ),
      findsNothing,
    );
    final formTextFields = tester.widgetList<TextField>(find.byType(TextField));
    expect(formTextFields, isNotEmpty);
    expect(
      formTextFields.every(
        (field) => field.decoration?.hintText?.isNotEmpty == true,
      ),
      isTrue,
    );
    expect(
      tester.getSize(find.byType(SingleChildScrollView).first).width,
      greaterThan(1000),
    );
    await tester.enterText(
      find.byKey(const ValueKey('student_name_first')),
      'Alex',
    );
    expect(find.text('First name'), findsWidgets);
    expect(find.text('Middle name (optional)'), findsWidgets);
    expect(find.text('Suffix (optional)'), findsWidgets);
    await tester.tap(find.text('Save form'));
    await tester.pumpAndSettle();

    expect(find.text('Saved forms'), findsWidgets);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Last saved'), findsOneWidget);
    expect(find.text('Student Information Sheet'), findsOneWidget);

    await tester.tap(find.text('Fill form'));
    await tester.pumpAndSettle();
    expect(find.text('Available forms'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);

    await tester.tap(find.text('Saved forms').first);
    await tester.pumpAndSettle();
    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search student or form',
    );
    final searchCenterY = tester.getCenter(searchField).dy;
    final searchWidth = tester.getSize(searchField).width;
    expect(
      tester.getCenter(find.byTooltip('Refresh')).dy,
      closeTo(searchCenterY, 1),
    );
    expect(searchWidth, greaterThan(420));
  });

  testWidgets('saved forms is the default view', (tester) async {
    final submissions = FormSubmissionRepository(db);
    await submissions.create(
      formId: 'student_information',
      data: const {'student_name': 'Aisha Rahman'},
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClientRepository>(create: (_) => ClientRepository(db)),
          Provider<FormSubmissionRepository>.value(value: submissions),
        ],
        child: const MaterialApp(home: Scaffold(body: FormsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Student Information Sheet'), findsOneWidget);
    expect(find.text('Available forms'), findsNothing);
  });

  testWidgets('tabs switch the inline form and pinning prevents switching', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClientRepository>(create: (_) => ClientRepository(db)),
          Provider<FormSubmissionRepository>(
            create: (_) => FormSubmissionRepository(db),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: FormsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fill form'));
    await tester.pumpAndSettle();

    final secondTab = find.text('GS Form 2 · Counseling Intake Form').first;
    await tester.ensureVisible(secondTab);
    await tester.pumpAndSettle();
    await tester.tap(secondTab);
    await tester.pumpAndSettle();
    expect(find.text('GS Form 2 · Counseling Intake Form'), findsWidgets);

    await tester.tap(find.byTooltip('Pin form tab'));
    await tester.pumpAndSettle();
    final firstTab = find.text('CC Form 1 · Student Information Sheet').first;
    await tester.ensureVisible(firstTab);
    await tester.pumpAndSettle();
    await tester.tap(firstTab);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unpin form tab'), findsOneWidget);
    expect(
      find.text('This form is pinned. Unpin it before switching tabs.'),
      findsOneWidget,
    );
    expect(find.text('Unpin'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byTooltip('Unpin form tab'));
    await tester.pumpAndSettle();
    expect(
      find.text('This form is pinned. Unpin it before switching tabs.'),
      findsNothing,
    );
    await tester.ensureVisible(firstTab);
    await tester.pumpAndSettle();
    await tester.tap(firstTab);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pin form tab'), findsOneWidget);
  });

  testWidgets('prefills split name fields from a legacy saved name', (
    tester,
  ) async {
    final now = DateTime(2026);
    final submission = FormSubmission(
      id: 1,
      formId: 'student_information',
      data: const {'student_name': 'Student, Alex Marie'},
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClientRepository>(create: (_) => ClientRepository(db)),
          Provider<FormSubmissionRepository>(
            create: (_) => FormSubmissionRepository(db),
          ),
        ],
        child: MaterialApp(
          home: CounselingFormPage(
            form: counselingFormById('student_information')!,
            submission: submission,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('student_name_first')))
          .controller!
          .text,
      'Alex',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('student_name_middle')))
          .controller!
          .text,
      'Marie',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('student_name_last')))
          .controller!
          .text,
      'Student',
    );
  });

  testWidgets('wrapped field labels keep name inputs horizontally aligned', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClientRepository>(create: (_) => ClientRepository(db)),
          Provider<FormSubmissionRepository>(
            create: (_) => FormSubmissionRepository(db),
          ),
        ],
        child: MaterialApp(
          home: CounselingFormPage(
            form: counselingFormById('informed_consent')!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final middleName = find.byKey(const ValueKey('student_signature_middle'));
    await tester.ensureVisible(middleName);
    await tester.pumpAndSettle();
    final inputTops = [
      for (final part in ['first', 'middle', 'last', 'suffix'])
        tester.getTopLeft(find.byKey(ValueKey('student_signature_$part'))).dy,
    ];

    expect(inputTops, everyElement(closeTo(inputTops.first, 1)));
    final firstInput = find.byKey(const ValueKey('student_signature_first'));
    final firstField = find.ancestor(
      of: firstInput,
      matching: find.byType(AppField),
    );
    final firstLabel = find.descendant(
      of: firstField,
      matching: find.text('First name'),
    );
    expect(
      tester.getTopLeft(firstInput).dy - tester.getBottomLeft(firstLabel).dy,
      lessThanOrEqualTo(8),
    );
  });

  testWidgets('reviewed-by name fields do not repeat their group label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClientRepository>(create: (_) => ClientRepository(db)),
          Provider<FormSubmissionRepository>(
            create: (_) => FormSubmissionRepository(db),
          ),
        ],
        child: MaterialApp(
          home: CounselingFormPage(
            form: counselingFormById('care_center_log')!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstNameInput = find.byKey(const ValueKey('reviewed_by_first'));
    await tester.ensureVisible(firstNameInput);
    await tester.pumpAndSettle();

    expect(find.text('Reviewed By'), findsOneWidget);
    expect(find.text('Received and reviewed by — First name'), findsNothing);
    final nameField = find.ancestor(
      of: firstNameInput,
      matching: find.byType(AppField),
    );
    expect(
      find.descendant(of: nameField, matching: find.text('First name')),
      findsOneWidget,
    );
  });

  testWidgets('repeatable sibling and education fields save as separate rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final submissions = FormSubmissionRepository(db);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClientRepository>(create: (_) => ClientRepository(db)),
          Provider<FormSubmissionRepository>.value(value: submissions),
        ],
        child: MaterialApp(
          home: CounselingFormPage(
            form: counselingFormById('student_information')!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sibling 1'));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(of: find.text('Sibling 1'), matching: find.byType(Card)),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('siblings_0_first_name')),
      'Jamie',
    );
    expect(
      find.byKey(const ValueKey('siblings_0_gender_Female')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('siblings_0_gender')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('siblings_0_gender_Female')));
    await tester.pumpAndSettle();
    final addSibling = find.widgetWithText(OutlinedButton, 'Add sibling');
    await tester.ensureVisible(addSibling);
    await tester.tap(addSibling);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('siblings_1_first_name')),
      'Taylor',
    );

    await tester.ensureVisible(find.text('School last attended'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.ancestor(
          of: find.text('School last attended'),
          matching: find.byType(AppField),
        ),
        matching: find.byType(TextField),
      ),
      'North Elementary',
    );
    await tester.tap(find.text('Add record'));
    await tester.pumpAndSettle();
    final schoolFields = find.ancestor(
      of: find.text('School last attended'),
      matching: find.byType(AppField),
    );
    await tester.enterText(
      find.descendant(of: schoolFields.last, matching: find.byType(TextField)),
      'West Junior High',
    );

    await tester.tap(find.text('Save form'));
    await tester.pumpAndSettle();

    final saved = await submissions.list();
    expect(saved, hasLength(1));
    expect(saved.single.data['siblings'], [
      {
        'first_name': 'Jamie',
        'middle_name': '',
        'last_name': '',
        'suffix': '',
        'age': '',
        'gender': 'Female',
        'grade_year_work': '',
        'school': '',
      },
      {
        'first_name': 'Taylor',
        'middle_name': '',
        'last_name': '',
        'suffix': '',
        'age': '',
        'gender': '',
        'grade_year_work': '',
        'school': '',
      },
    ]);
    expect(saved.single.data['education_background'], [
      {
        'school_last_attended': 'North Elementary',
        'year_graduated': '',
        'awards_honors': '',
      },
      {
        'school_last_attended': 'West Junior High',
        'year_graduated': '',
        'awards_honors': '',
      },
    ]);
  });

  testWidgets('care center visit details save as separate fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final submissions = FormSubmissionRepository(db);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClientRepository>(create: (_) => ClientRepository(db)),
          Provider<FormSubmissionRepository>.value(value: submissions),
        ],
        child: MaterialApp(
          home: CounselingFormPage(
            form: counselingFormById('care_center_log')!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Visit 1'));
    await tester.pumpAndSettle();
    final today = DateTime.now();
    Future<void> enterField(String id, String value) async {
      await tester.enterText(
        find.byKey(ValueKey('visit_entries_0_$id')),
        value,
      );
    }

    final dateField = find.byKey(const ValueKey('visit_entries_0_date'));
    expect(tester.widget(dateField), isA<PickerField>());
    await tester.tap(dateField);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await enterField('first_name', 'Avery');
    await enterField('last_name', 'Santos');
    await enterField('concern_code', 'AK');
    await enterField('action_taken', 'Counseling');
    await enterField('remarks', 'Follow up next week');
    final saveButton = find.text('Save form');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final saved = await submissions.list();
    expect(saved, hasLength(1));
    expect(saved.single.data['visit_entries'], [
      {
        'date':
            '${today.year.toString().padLeft(4, '0')}-'
            '${today.month.toString().padLeft(2, '0')}-'
            '${today.day.toString().padLeft(2, '0')}',
        'first_name': 'Avery',
        'middle_name': '',
        'last_name': 'Santos',
        'suffix': '',
        'grade_section': '',
        'reason_referral': '',
        'concern_code': 'AK',
        'action_taken': 'Counseling',
        'follow_up_needed': '',
        'counselor_staff': '',
        'remarks': 'Follow up next week',
      },
    ]);
  });

  testWidgets('checkbox selection deletes saved forms as a batch', (
    tester,
  ) async {
    final submissions = FormSubmissionRepository(db);
    await submissions.create(
      formId: 'student_information',
      data: const {'student_name': 'Aisha Rahman'},
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClientRepository>(create: (_) => ClientRepository(db)),
          Provider<FormSubmissionRepository>.value(value: submissions),
        ],
        child: const MaterialApp(home: Scaffold(body: FormsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved forms').first);
    await tester.pumpAndSettle();

    final rowCheckboxes = find.descendant(
      of: find.byType(DataTable),
      matching: find.byType(Checkbox),
    );
    await tester.ensureVisible(rowCheckboxes.last);
    await tester.pumpAndSettle();
    await tester.tap(rowCheckboxes.last);
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Delete (1)'), findsOneWidget);
    expect(find.text('Student Information Sheet'), findsWidgets);
    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search student or form',
    );
    final searchCenterY = tester.getCenter(searchField).dy;
    expect(
      tester.getCenter(find.text('Delete (1)')).dy,
      closeTo(searchCenterY, 1),
    );

    await tester.tap(find.text('Delete (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Delete selected forms?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await submissions.list(), isEmpty);
    expect(find.text('No saved forms yet'), findsOneWidget);
  });

  testWidgets('form dropdown opens below its field and selects value', (
    tester,
  ) async {
    await ClientRepository(db).create(
      CreateClientInput(
        fullName: 'Aisha Rahman',
        phone: '09171234567',
        dateOfBirth: DateTime(2010, 1, 15),
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ClientRepository>(create: (_) => ClientRepository(db)),
          Provider<FormSubmissionRepository>(
            create: (_) => FormSubmissionRepository(db),
          ),
        ],
        child: MaterialApp(
          home: CounselingFormPage(
            form: counselingFormById('student_information')!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final clientDropdown = find.byType(AppDropdownFormField<int>);
    expect(find.text('Select linked student (optional)'), findsOneWidget);
    final clientFieldRect = tester.getRect(clientDropdown);
    expect(clientFieldRect.width, lessThan(400));
    final dropdownButton = find.descendant(
      of: clientDropdown,
      matching: find.byType(AppDropdownButton<int>),
    );
    final dropdownButtonRect = tester.getRect(dropdownButton);
    final firstNameField = find.byKey(const ValueKey('student_name_first'));
    final firstNameInput = find.descendant(
      of: firstNameField,
      matching: find.byType(InputDecorator),
    );
    final dropdownInput = find.descendant(
      of: clientDropdown,
      matching: find.byType(InputDecorator),
    );
    final dateInput = find.descendant(
      of: find.byType(PickerField).first,
      matching: find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 50,
      ),
    );
    expect(tester.getSize(firstNameInput).height, 50);
    expect(tester.getSize(dropdownInput).height, greaterThanOrEqualTo(50));
    expect(tester.getSize(dateInput).height, 50);
    await tester.enterText(firstNameField, 'Alex');
    await tester.tap(clientDropdown);
    await tester.pumpAndSettle();

    final clientOption = find.text('Aisha Rahman').last;
    expect(clientOption, findsOneWidget);
    expect(
      tester.getTopLeft(clientOption).dy,
      greaterThan(dropdownButtonRect.bottom),
    );
    await tester.tap(clientOption);
    await tester.pumpAndSettle();
    expect(find.text('Aisha Rahman'), findsOneWidget);
    expect(tester.widget<TextField>(firstNameField).controller!.text, 'Alex');

    final lastNameField = find.byKey(const ValueKey('student_name_last'));
    expect(tester.widget<TextField>(lastNameField).controller!.text, 'Rahman');
    final contactField = find.descendant(
      of: find.ancestor(
        of: find.text('Contact number'),
        matching: find.byType(AppField),
      ),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(contactField).controller!.text,
      '09171234567',
    );
    expect(find.text('Jan 15, 2010'), findsOneWidget);

    const femaleCheckbox = ValueKey('sex_Female');
    final checkboxFinder = find.byKey(femaleCheckbox);
    await tester.ensureVisible(checkboxFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);
    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);
  });

  testWidgets('filter dropdown menu also opens directly below its button', (
    tester,
  ) async {
    String selected = 'Upcoming';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Align(
              alignment: Alignment.topLeft,
              child: AppDropdownButton<String>(
                value: selected,
                items: const [
                  DropdownMenuItem(value: 'Upcoming', child: Text('Upcoming')),
                  DropdownMenuItem(value: 'Today', child: Text('Today')),
                ],
                onChanged: (value) => setState(() {
                  selected = value!;
                }),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byType(AppDropdownButton<String>);
    final buttonRect = tester.getRect(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    final option = find.text('Today').last;
    expect(tester.getTopLeft(option).dy, greaterThan(buttonRect.bottom));
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
  });
}
