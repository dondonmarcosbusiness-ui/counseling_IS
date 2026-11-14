import 'package:counseling_is/features/appointments/data/appointment_repository.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/sessions/data/session_repository.dart';
import 'package:counseling_is/features/sessions/presentation/sessions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late SessionRepository sessions;

  setUp(() async {
    db = await openTestDatabase();
    sessions = SessionRepository(db);
    final client = await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Ana Cruz'));
    await sessions.create(
      CreateSessionInput(
        clientId: client.id!,
        sessionDate: DateTime(2026, 3, 5),
        notes: 'Confidential: family conflict discussed in detail.',
        followUpActions: 'Send worksheet',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: sessions),
          Provider<ClientRepository>.value(value: ClientRepository(db)),
          Provider<AppointmentRepository>.value(
            value: AppointmentRepository(db),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: SessionsScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('list shows the session but never the confidential notes', (
    tester,
  ) async {
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
      tester.getCenter(find.widgetWithText(FilledButton, 'New session')).dy,
      closeTo(searchCenterY, 1),
    );
    expect(find.text('Session date'), findsOneWidget);
    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.textContaining('Mar 5, 2026'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    // Notes content must not appear anywhere in the list.
    expect(find.textContaining('family conflict'), findsNothing);

    // Opening the session shows the notes to the authorized admin.
    await tester.tap(find.text('Ana Cruz'));
    await tester.pumpAndSettle();

    expect(find.textContaining('family conflict'), findsOneWidget);
    expect(find.text('Session details'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('family conflict'), findsNothing);
  });

  testWidgets('search filters the session list', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Ana Cruz'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'no-such-person');
    await tester.pumpAndSettle();

    expect(find.text('Ana Cruz'), findsNothing);
    expect(find.text('No matching sessions'), findsOneWidget);
  });
}
