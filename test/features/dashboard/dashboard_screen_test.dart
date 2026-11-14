import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/time.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/dashboard/data/stats_repository.dart';
import 'package:counseling_is/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('shows the reference dashboard overview when there is no data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      Provider<StatsRepository>(
        create: (_) => StatsRepository(db),
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to your dashboard'), findsOneWidget);
    expect(find.text('REGISTERED STUDENTS'), findsOneWidget);
    expect(find.text('ACTIVE INTERVENTIONS'), findsOneWidget);
    expect(find.text('TOTAL VIOLATIONS'), findsNothing);
    expect(find.text('PENDING CASES'), findsNothing);
    final banner = find.byKey(const ValueKey('dashboard-welcome-banner'));
    final bannerDecoration =
        tester.widget<Container>(banner).decoration! as BoxDecoration;
    expect((bannerDecoration.gradient! as LinearGradient).colors, [
      AppColors.sidebar,
      AppColors.navy,
    ]);
    expect(
      find.ancestor(of: banner, matching: find.byType(ClipRRect)),
      findsOneWidget,
    );
    final bannerStack = tester.widget<Stack>(
      find.descendant(of: banner, matching: find.byType(Stack)).first,
    );
    expect(bannerStack.children, hasLength(1));
    final schoolSeal = tester.widget<Image>(
      find.byKey(const ValueKey('school-seal-logo')),
    );
    expect(
      (schoolSeal.image as AssetImage).assetName,
      'assets/images/carranglan_national_high_school_logo_transparent.png',
    );
    final sealOpacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byWidget(schoolSeal),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(sealOpacity.opacity, .34);
    expect(tester.getSize(find.byWidget(schoolSeal)).width, 220);
    expect(find.text("Today's Guidance Queue"), findsOneWidget);
    expect(find.text('No scheduled appointments for today.'), findsOneWidget);

    final quickActionFinder = find.descendant(
      of: find.byKey(const ValueKey('guidance-queue-header')),
      matching: find.byType(FilledButton),
    );
    final quickActions = tester.widgetList<FilledButton>(quickActionFinder);
    expect(quickActions, hasLength(4));
    for (final button in quickActions) {
      expect(button.style?.backgroundColor?.resolve({}), AppColors.teal);
    }
    final actionCenters = [
      for (final label in [
        'Add student',
        'Add intervention',
        'New counseling',
        'CP intake',
      ])
        tester.getCenter(find.text(label)),
    ];
    expect(
      actionCenters.map((center) => center.dy),
      everyElement(closeTo(actionCenters.first.dy, 1)),
    );
    expect(
      tester.getCenter(find.text('Add student')).dx,
      greaterThan(tester.getCenter(find.text("Today's Guidance Queue")).dx),
    );
  });

  testWidgets('hides the school seal when the welcome card is narrow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      Provider<StatsRepository>(
        create: (_) => StatsRepository(db),
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Counseling Information System'), findsOneWidget);
    expect(find.byKey(const ValueKey('school-seal-logo')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("shows today's and upcoming appointments without legacy cases", (
    tester,
  ) async {
    final client = await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Jordan Rivera'));
    final now = DateTime.now();
    final appointmentStart = now.add(const Duration(days: 1));
    final todayStart = DateTime(now.year, now.month, now.day, 9);
    await db.insert('appointments', {
      'client_id': client.id,
      'starts_at': dateTimeToDb(todayStart),
      'ends_at': dateTimeToDb(todayStart.add(const Duration(hours: 1))),
      'purpose': 'Today check-in',
      'status': 'scheduled',
      'created_at': nowUtcIso(),
      'updated_at': nowUtcIso(),
    });
    await db.insert('appointments', {
      'client_id': client.id,
      'starts_at': dateTimeToDb(appointmentStart),
      'ends_at': dateTimeToDb(appointmentStart.add(const Duration(hours: 1))),
      'purpose': 'Progress review',
      'status': 'scheduled',
      'created_at': nowUtcIso(),
      'updated_at': nowUtcIso(),
    });
    await db.insert('counseling_sessions', {
      'client_id': client.id,
      'session_date': dateToDb(now),
      'notes': 'PRIVATE COUNSELING NOTES',
      'created_at': nowUtcIso(),
      'updated_at': nowUtcIso(),
    });
    await db.insert('case_records', {
      'case_ref': 'CASE-2026-0042',
      'client_id': client.id,
      'opened_at': dateToDb(now.subtract(const Duration(days: 14))),
      'status': 'open',
      'follow_up_date': dateToDb(now),
      'created_at': nowUtcIso(),
      'updated_at': nowUtcIso(),
    });

    await tester.pumpWidget(
      Provider<StatsRepository>(
        create: (_) => StatsRepository(db),
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Appointments & sessions today'),
      findsOneWidget,
    );
    expect(find.text('AWAITING COUNSELING'), findsOneWidget);
    expect(find.text('DUE FOLLOW-UPS'), findsNothing);
    expect(find.text('Upcoming appointments'), findsOneWidget);
    expect(find.text('Jordan Rivera'), findsWidgets);
    expect(find.text('Today check-in'), findsWidgets);
    expect(find.text('Counseling session recorded'), findsOneWidget);
    expect(find.text('Progress review'), findsOneWidget);
    expect(find.text('CASE-2026-0042 · Open'), findsNothing);
    expect((await db.query('case_records')).length, 1);
    expect(find.text('PRIVATE COUNSELING NOTES'), findsNothing);
  });

  testWidgets('shows the guidance queue on wide screens', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Dashboard Client'));
    await tester.pumpWidget(
      Provider<StatsRepository>(
        create: (_) => StatsRepository(db),
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Today's Guidance Queue"), findsOneWidget);
    expect(find.textContaining('Due & overdue follow-ups'), findsNothing);
  });

  testWidgets('shows only the remaining summary cards', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Dashboard Client'));
    await tester.pumpWidget(
      Provider<StatsRepository>(
        create: (_) => StatsRepository(db),
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ),
    );
    await tester.pumpAndSettle();

    final firstRowLabels = [
      'REGISTERED STUDENTS',
      'ACTIVE INTERVENTIONS',
      'AWAITING COUNSELING',
      'COUNSELING SESSIONS',
    ];
    final firstRowTops = firstRowLabels
        .map((label) => tester.getTopLeft(find.text(label)).dy)
        .toList();
    expect(firstRowTops, everyElement(closeTo(firstRowTops.first, 1)));
  });
}
