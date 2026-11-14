import 'package:counseling_is/core/widgets/app_logo.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:counseling_is/features/auth/data/auth_repository.dart';
import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:counseling_is/shell/main_shell.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late AuthController auth;

  setUp(() async {
    db = await openTestDatabase();
    auth = AuthController(AuthRepository(db));
  });

  tearDown(() async {
    auth.dispose();
    await db.close();
  });

  testWidgets(
    'Student Forms stays flat and child protection has direct access',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (_, _, child) => MainShell(child: child),
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const Scaffold(body: Text('Dashboard page')),
              ),
              GoRoute(
                path: '/forms',
                builder: (_, state) =>
                    Scaffold(body: Text('Opened ${state.uri.path}')),
                routes: [
                  GoRoute(
                    path: ':formId',
                    builder: (_, state) =>
                        Scaffold(body: Text('Opened ${state.uri.path}')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reports'), findsOneWidget);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();

      Future<void> hoverAt(Offset position) async {
        await mouse.moveTo(position);
        await tester.pumpAndSettle();
      }

      expect(find.text('Student Forms'), findsOneWidget);
      expect(find.text('Child Protection Intake'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      final clientFormsTile = find
          .ancestor(
            of: find.text('Student Forms'),
            matching: find.byType(InkWell),
          )
          .first;
      await hoverAt(tester.getCenter(find.text('Student Forms')));
      final hoverBackground = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: clientFormsTile,
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(
        (hoverBackground.decoration! as BoxDecoration).color,
        isNot(Colors.transparent),
      );
      await hoverAt(const Offset(600, 500));
      for (final form in counselingFormCatalog) {
        expect(find.text('${form.documentNo} · ${form.title}'), findsNothing);
      }

      await tester.tap(find.text('Student Forms'));
      await tester.pumpAndSettle();
      expect(find.text('Opened /forms'), findsOneWidget);

      router.go('/forms/student_information');
      await tester.pumpAndSettle();
      expect(find.text('Opened /forms/student_information'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);

      await tester.tap(find.text('Child Protection Intake'));
      await tester.pumpAndSettle();
      expect(
        find.text('Opened /forms/child_protection_intake'),
        findsOneWidget,
      );
      router.go('/forms/student_information');
      await tester.pumpAndSettle();

      await hoverAt(tester.getCenter(find.byType(AppLogo)));
      expect(find.byType(AppLogo), findsNothing);
      expect(find.byTooltip('Collapse sidebar'), findsOneWidget);
      expect(find.byTooltip('Hide sidebar'), findsNothing);
      await hoverAt(const Offset(600, 500));
      expect(find.byType(AppLogo), findsOneWidget);
      await hoverAt(tester.getCenter(find.byType(AppLogo)));
      await tester.tap(find.byTooltip('Collapse sidebar'));
      await tester.pump();
      final sidebarTransition = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('sidebar-width-transition')),
      );
      expect(sidebarTransition.duration, const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('sidebar-width-transition')))
            .width,
        72,
      );
      expect(find.text('Student Forms'), findsNothing);
      expect(find.byType(AppLogo), findsNothing);
      expect(find.byTooltip('Expand sidebar'), findsOneWidget);
      expect(find.byTooltip('Hide sidebar'), findsNothing);

      await tester.tap(find.byTooltip('Expand sidebar'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('sidebar-width-transition')))
            .width,
        240,
      );
      await hoverAt(const Offset(600, 500));
      expect(find.text('Student Forms'), findsOneWidget);
      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.byTooltip('Hide sidebar'), findsNothing);
      expect(find.text('Opened /forms/student_information'), findsOneWidget);
      expect(find.byTooltip('Hide sidebar'), findsNothing);
      await mouse.removePointer();
    },
  );
}
