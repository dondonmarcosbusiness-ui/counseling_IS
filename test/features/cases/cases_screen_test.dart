import 'package:counseling_is/features/cases/data/case_repository.dart';
import 'package:counseling_is/features/cases/presentation/cases_screen.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late CaseRepository cases;

  setUp(() async {
    db = await openTestDatabase();
    cases = CaseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CaseRepository>.value(value: cases),
          Provider<ClientRepository>.value(value: ClientRepository(db)),
        ],
        child: MaterialApp(home: Scaffold(body: CasesScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state for a fresh database', (tester) async {
    await pumpScreen(tester);
    expect(find.text('No cases yet'), findsOneWidget);
    expect(find.text('New case'), findsWidgets);
  });

  testWidgets('lists a case and opens its edit dialog with status control', (
    tester,
  ) async {
    final client = await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Ana Cruz'));
    final year = DateTime.now().year;
    final record = await cases.create(
      CreateCaseInput(
        clientId: client.id!,
        openedAt: DateTime(2026, 1, 10),
        summary: 'Anxiety reported during intake',
      ),
    );

    await pumpScreen(tester);

    expect(find.byType(DataTable), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.byType(Checkbox),
      ),
      findsNothing,
    );
    final searchCenterY = tester.getCenter(find.byType(TextField).first).dy;
    expect(
      tester.getCenter(find.byTooltip('Refresh')).dy,
      closeTo(searchCenterY, 1),
    );
    expect(
      tester.getCenter(find.widgetWithText(FilledButton, 'New case')).dy,
      closeTo(searchCenterY, 1),
    );
    expect(find.text('Case reference'), findsOneWidget);
    expect(find.textContaining('CASE-$year-0001'), findsOneWidget);
    expect(find.textContaining('Ana Cruz'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.byIcon(Icons.show_chart), findsOneWidget);
    expect(find.byIcon(Icons.gavel), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);

    await tester.tap(find.text('Ana Cruz'));
    await tester.pumpAndSettle();

    expect(find.text('Edit case'), findsOneWidget);
    expect(find.text('Status'), findsWidgets);
    expect(find.text(record.summary!), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit case'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Case history'));
    await tester.tap(find.byTooltip('Case history'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Case history —'), findsOneWidget);
    expect(find.text('Case opened'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('records and displays disciplinary timeline events', (
    tester,
  ) async {
    final client = await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Ana Cruz'));
    final record = await cases.create(
      CreateCaseInput(clientId: client.id!, openedAt: DateTime(2026, 1, 10)),
    );

    await pumpScreen(tester);
    await tester.ensureVisible(find.byTooltip('Disciplinary timeline'));
    await tester.tap(find.byTooltip('Disciplinary timeline'));
    await tester.pumpAndSettle();

    expect(find.text('No disciplinary events yet'), findsOneWidget);
    await tester.tap(find.text('Add disciplinary event'));
    await tester.pumpAndSettle();

    expect(find.text('Add disciplinary timeline event'), findsOneWidget);
    expect(find.text('Event type'), findsNothing);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Parent conference',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'Follow-up conference held.',
    );
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();

    expect(find.text('Parent conference'), findsOneWidget);
    expect(find.textContaining('Disciplinary action'), findsOneWidget);
    expect(find.text('Follow-up conference held.'), findsOneWidget);
    expect(record.id, isNotNull);
  });
}
