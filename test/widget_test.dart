import 'package:counseling_is/app.dart';
import 'package:counseling_is/core/widgets/app_logo.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:counseling_is/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_db.dart';

void main() {
  testWidgets('boots to setup screen when no admin exists', (tester) async {
    final db = await openTestDatabase();
    final auth = AuthController(AuthRepository(db));
    await auth.init();

    await tester.pumpWidget(CounselingApp(
      authController: auth,
      db: db,
      dbPath: ':memory:',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Initial setup'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);

    auth.dispose();
    await db.close();
  });

  testWidgets('boots to login screen when admin exists', (tester) async {
    final db = await openTestDatabase();
    final repo = AuthRepository(db);
    // bcrypt hashes in a background isolate: real async needs runAsync.
    await tester.runAsync(() => repo.createAdmin(
          username: 'admin',
          fullName: 'Test Admin',
          password: 'Password123',
        ));
    final auth = AuthController(repo);
    await auth.init();

    await tester.pumpWidget(CounselingApp(
      authController: auth,
      db: db,
      dbPath: ':memory:',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Administrator sign in'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(AppLogo), findsOneWidget);

    auth.dispose();
    await db.close();
  });
}
