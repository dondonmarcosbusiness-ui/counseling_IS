import 'package:counseling_is/core/security/password_hasher.dart';
import 'package:counseling_is/core/security/session_manager.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:counseling_is/features/auth/data/auth_repository.dart';
import 'package:counseling_is/features/auth/presentation/admin_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;
  late AuthController auth;

  setUp(() async {
    db = await openTestDatabase();
    auth = AuthController(
      AuthRepository(db, hasher: PasswordHasher(logRounds: 4)),
      session: SessionManager(
        onLock: () {},
        idleTimeout: const Duration(days: 1),
      ),
    );
    await auth.init();
    await auth.setup(
      username: 'admin',
      fullName: 'Site Administrator',
      password: 'Password123',
      confirmPassword: 'Password123',
    );
  });

  tearDown(() async {
    auth.dispose();
    await db.close();
  });

  testWidgets('lists shared-permission accounts and protects current account', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: const MaterialApp(home: AdminManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('User Management'), findsOneWidget);
    expect(find.text('Site Administrator'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    final deactivate = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Deactivate'),
    );
    expect(deactivate.onPressed, isNull);
  });
}
