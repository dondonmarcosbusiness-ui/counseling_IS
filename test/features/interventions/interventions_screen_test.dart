import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/interventions/data/intervention_repository.dart';
import 'package:counseling_is/features/interventions/presentation/interventions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late InterventionRepository interventions;
  late int clientId;

  setUp(() async {
    db = await openTestDatabase();
    interventions = InterventionRepository(db);
    clientId = (await ClientRepository(
      db,
    ).create(const CreateClientInput(fullName: 'Ana Cruz'))).id!;
  });

  tearDown(() async => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<InterventionRepository>.value(value: interventions),
          Provider<ClientRepository>.value(value: ClientRepository(db)),
        ],
        child: const MaterialApp(home: Scaffold(body: InterventionsScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty state and supports a new intervention', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('No interventions yet'), findsOneWidget);
    expect(find.text('New intervention'), findsWidgets);
  });

  testWidgets('lists a saved intervention with its learner and status', (
    tester,
  ) async {
    await interventions.create(
      CreateInterventionInput(
        clientId: clientId,
        title: 'Attendance support',
        type: 'Academic support',
        startDate: DateTime(2026, 6, 1),
      ),
    );

    await pumpScreen(tester);

    expect(find.text('Attendance support'), findsOneWidget);
    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);
  });

  testWidgets('group counseling allows selecting multiple learners', (
    tester,
  ) async {
    final otherClientId = (await ClientRepository(
      db,
    ).create(const CreateClientInput(fullName: 'Ben Santos'))).id!;
    await pumpScreen(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, 'New intervention').first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select learner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Cruz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Individual counseling'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group counseling').last);
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('Learners *')).dy,
      closeTo(tester.getCenter(find.text('Select learners')).dy, 4),
    );
    await tester.tap(find.text('Select learners'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ben');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, 'Ben Santos'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Ana Cruz'), findsNothing);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ben Santos'));
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Peer support group',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = (await interventions.list(const InterventionQuery())).single;
    expect(saved.type, 'Group counseling');
    expect(saved.participantIds, containsAll([clientId, otherClientId]));
    expect(saved.participantLabel, contains('Ana Cruz'));
    expect(saved.participantLabel, contains('Ben Santos'));
  });

  testWidgets('Other intervention type reveals and saves its specification', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, 'New intervention').first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select learner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Cruz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Individual counseling'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    expect(find.text('Specify intervention type *'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Community outreach',
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'Outreach program',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = (await interventions.list(const InterventionQuery())).single;
    expect(saved.type, 'Other');
    expect(saved.customType, 'Community outreach');
  });
}
