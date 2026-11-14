import 'package:counseling_is/app.dart';
import 'package:counseling_is/core/database/database_factory.dart';
import 'package:counseling_is/core/database/db.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:counseling_is/features/auth/data/auth_repository.dart';
import 'package:counseling_is/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initSqliteFfi();

  Object? dbError;
  try {
    await AppDatabase.instance.open();
  } catch (e) {
    dbError = e;
  }

  if (dbError != null) {
    runApp(DatabaseErrorApp(error: dbError));
    return;
  }

  final authController = AuthController(
    AuthRepository(AppDatabase.instance.db),
  );
  await authController.init();

  final idleMinutes = await SettingsRepository(AppDatabase.instance.db)
      .getIdleTimeoutMinutes();
  authController.session.updateTimeout(Duration(minutes: idleMinutes));

  runApp(CounselingApp(
    authController: authController,
    db: AppDatabase.instance.db,
    dbPath: AppDatabase.instance.path ?? '',
  ));
}

class DatabaseErrorApp extends StatelessWidget {
  const DatabaseErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counseling IS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 56, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text('Database error',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  const Text(
                    'The application could not open its data file.\n'
                    'Your records have not been modified.\n\n'
                    'Check that the application data folder is readable '
                    'and that no other instance of the application is '
                    'running, then restart.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => _showDetails(context),
                    child: const Text('Technical details'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Technical details'),
        content: SelectableText('$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
