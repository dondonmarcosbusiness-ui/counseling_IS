import 'package:counseling_is/features/appointments/data/appointment_repository.dart';
import 'package:counseling_is/features/appointments/presentation/appointments_screen.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late AppointmentRepository appointments;

  setUp(() async {
    db = await openTestDatabase();
    appointments = AppointmentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppointmentRepository>.value(value: appointments),
          Provider<ClientRepository>.value(value: ClientRepository(db)),
        ],
        child: MaterialApp(home: Scaffold(body: AppointmentsScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state for a fresh database', (tester) async {
    await pumpScreen(tester);
    expect(find.text('No upcoming appointments'), findsOneWidget);
    expect(find.text('New appointment'), findsWidgets);
  });

  testWidgets('lists an upcoming appointment and opens its edit dialog', (
    tester,
  ) async {
    final client = await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Ana Cruz'));
    final start = DateTime.now().add(const Duration(hours: 2));
    final startSecond = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
      start.minute,
    );
    await appointments.create(
      CreateAppointmentInput(
        clientId: client.id!,
        startsAt: startSecond,
        endsAt: startSecond.add(const Duration(minutes: 60)),
        purpose: 'Follow-up visit',
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
      tester.getCenter(find.widgetWithText(FilledButton, 'New appointment')).dy,
      closeTo(searchCenterY, 1),
    );
    expect(find.text('Date and time'), findsOneWidget);
    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.textContaining('Follow-up visit'), findsOneWidget);
    expect(find.text('Scheduled'), findsOneWidget);

    await tester.tap(find.text('Ana Cruz'));
    await tester.pumpAndSettle();

    expect(find.text('Edit appointment'), findsOneWidget);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('Follow-up visit'), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit appointment'), findsNothing);
  });
}
