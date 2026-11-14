import 'package:counseling_is/features/appointments/data/appointment_repository.dart';
import 'package:counseling_is/features/calendar/presentation/guidance_calendar_screen.dart';
import 'package:counseling_is/features/cases/data/case_repository.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late AppointmentRepository appointments;
  late CaseRepository cases;
  late ClientRepository clients;

  setUp(() async {
    db = await openTestDatabase();
    appointments = AppointmentRepository(db);
    cases = CaseRepository(db);
    clients = ClientRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<AppointmentRepository>.value(value: appointments)],
        child: const MaterialApp(
          home: Scaffold(body: GuidanceCalendarScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the appointment calendar without case tracking', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Guidance Calendar'), findsOneWidget);
    expect(find.text('Events · ${_formatToday()}'), findsOneWidget);
    expect(find.text('Nothing scheduled for this day.'), findsOneWidget);
    expect(find.text('Follow-up tracking'), findsNothing);
  });

  testWidgets('shows the last week of a six-week month in the calendar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1365, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    var monthOffset = 0;
    late DateTime targetMonth;
    late DateTime lastDay;
    while (true) {
      targetMonth = DateTime(now.year, now.month + monthOffset);
      final firstDay = DateTime(targetMonth.year, targetMonth.month);
      lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0);
      final gridStart = firstDay.subtract(Duration(days: firstDay.weekday - 1));
      if (lastDay.difference(gridStart).inDays >= 35) break;
      monthOffset++;
    }

    await pumpScreen(tester);
    for (var month = 0; month < monthOffset; month++) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }

    final lastDayFinder = find.byKey(
      ValueKey(
        'calendar-date-${targetMonth.year}-${targetMonth.month}-${lastDay.day}',
      ),
    );
    expect(lastDayFinder, findsOneWidget);
    expect(tester.getRect(lastDayFinder).bottom, lessThan(700));
  });

  testWidgets('keeps saved case records without displaying them', (
    tester,
  ) async {
    final client = await clients.create(
      const CreateClientInput(fullName: 'Ana Cruz'),
    );
    final today = DateTime.now();
    final record = await cases.create(
      CreateCaseInput(
        clientId: client.id!,
        openedAt: DateTime(today.year, today.month, today.day - 1),
        followUpDate: DateTime(today.year, today.month, today.day),
      ),
    );

    await pumpScreen(tester);
    expect(find.text(record.caseRef), findsNothing);
    expect((await cases.getById(record.id!)).followUpDate, isNotNull);
  });
}

String _formatToday() {
  final date = DateTime.now();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
