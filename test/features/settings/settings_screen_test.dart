import 'package:counseling_is/core/database/migrations.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:counseling_is/features/auth/data/auth_repository.dart';
import 'package:counseling_is/features/settings/data/settings_repository.dart';
import 'package:counseling_is/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../helpers/test_db.dart';

void main() {
  testWidgets('persists an auto-lock change and applies it to the session', (
    tester,
  ) async {
    final db = await openTestDatabase();
    final settings = SettingsRepository(db);
    final auth = AuthController(AuthRepository(db));
    await auth.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsRepository>.value(value: settings),
          ChangeNotifierProvider<AuthController>.value(value: auth),
          Provider<String>.value(value: '/tmp/example.db'),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Auto-lock'), findsOneWidget);
    expect(find.text('15 minutes'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Version $schemaVersion'), findsOneWidget);
    expect(find.text('/tmp/example.db'), findsOneWidget);

    await tester.tap(find.text('15 minutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 minutes'));
    await tester.pumpAndSettle();

    expect(auth.session.idleTimeout, const Duration(minutes: 10));
    expect(await settings.getIdleTimeoutMinutes(), 10);
    expect(find.text('Auto-lock set to 10 minutes.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    auth.dispose();
    await db.close();
  });
}
