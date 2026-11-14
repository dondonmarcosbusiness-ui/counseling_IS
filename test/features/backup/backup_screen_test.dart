import 'dart:io';

import 'package:counseling_is/features/backup/data/backup_service.dart';
import 'package:counseling_is/features/backup/presentation/backup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../helpers/test_db.dart';

void main() {
  testWidgets('shows the create and restore actions', (tester) async {
    final db = await openTestDatabase();
    final dir = Directory.systemTemp.createTempSync('backup_screen_test');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      Provider<BackupService>(
        create: (_) => BackupService(db, '${dir.path}/app.db'),
        child: const MaterialApp(
          home: Scaffold(body: BackupScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backup and Restore'), findsOneWidget);
    expect(find.text('Create a backup'), findsOneWidget);
    expect(find.text('Create backup…'), findsOneWidget);
    expect(find.text('Restore from a backup'), findsOneWidget);
    expect(find.text('Choose backup to restore…'), findsOneWidget);
    expect(find.textContaining('not encrypted'), findsWidgets);

    await db.close();
  });
}
