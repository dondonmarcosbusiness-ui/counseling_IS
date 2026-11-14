import 'dart:convert';
import 'dart:io';

import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/reports/data/report_repository.dart';
import 'package:counseling_is/features/reports/presentation/reports_screen.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

class _FakeFileSelector extends FileSelectorPlatform {
  _FakeFileSelector(this.savePath);

  final String savePath;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async => FileSaveLocation(savePath);
}

void main() {
  late FileSelectorPlatform previousInstance;

  setUp(() {
    previousInstance = FileSelectorPlatform.instance;
  });

  tearDown(() {
    FileSelectorPlatform.instance = previousInstance;
  });

  Future<Database> seededDb() async {
    final db = await openTestDatabase();
    addTearDown(() async {
      if (db.isOpen) await db.close();
    });
    await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Ana Cruz'));
    return db;
  }

  Future<void> pumpReports(WidgetTester tester, Database db) async {
    await tester.pumpWidget(
      Provider<ReportRepository>(
        create: (_) => ReportRepository(db),
        child: const MaterialApp(home: Scaffold(body: ReportsScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> waitForMessage(WidgetTester tester, Finder message) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (message.evaluate().isNotEmpty) return;
    }
  }

  testWidgets('exports the current report as CSV through the save dialog', (
    tester,
  ) async {
    final db = await seededDb();
    final dir = Directory.systemTemp.createTempSync('csv_export_widget');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final target = '${dir.path}/report.csv';
    FileSelectorPlatform.instance = _FakeFileSelector(target);

    await pumpReports(tester, db);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Export CSV…'));

    final file = File(target);
    final successMessage = find.textContaining('CSV exported to');
    await waitForMessage(tester, successMessage);
    expect(successMessage, findsOneWidget);
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
    final content = utf8.decode(bytes.skip(3).toList());
    expect(content, contains('Reference'));
    expect(content, contains('Ana Cruz'));

    // Let the snackbar dismiss so no timers remain at test end.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('exports the current report as PDF through the save dialog', (
    tester,
  ) async {
    final db = await seededDb();
    final dir = Directory.systemTemp.createTempSync('pdf_export_widget');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final target = '${dir.path}/report.pdf';
    FileSelectorPlatform.instance = _FakeFileSelector(target);

    await pumpReports(tester, db);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Export PDF…'));

    final file = File(target);
    final successMessage = find.textContaining('PDF exported to');
    await waitForMessage(tester, successMessage);
    expect(successMessage, findsOneWidget);
    final bytes = file.readAsBytesSync();
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(String.fromCharCodes(bytes), contains('%%EOF'));

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('export actions are disabled while the report is loading', (
    tester,
  ) async {
    final db = await openTestDatabase();
    addTearDown(() async {
      if (db.isOpen) await db.close();
    });

    await tester.pumpWidget(
      Provider<ReportRepository>(
        create: (_) => ReportRepository(db),
        child: const MaterialApp(home: Scaffold(body: ReportsScreen())),
      ),
    );

    // First frame: initState started the initial load.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Export CSV…'),
          )
          .onPressed,
      isNull,
    );

    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Export CSV…'),
          )
          .onPressed,
      isNotNull,
    );
  });
}
