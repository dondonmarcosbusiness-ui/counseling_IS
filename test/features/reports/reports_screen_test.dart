import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/reports/data/report_repository.dart';
import 'package:counseling_is/features/reports/presentation/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../helpers/test_db.dart';

void main() {
  testWidgets('auto-runs the students report and shows the result', (
    tester,
  ) async {
    final db = await openTestDatabase();
    await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Ana Cruz'));

    await tester.pumpWidget(
      Provider<ReportRepository>(
        create: (_) => ReportRepository(db),
        child: const MaterialApp(home: Scaffold(body: ReportsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Run report'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('record found'), findsOneWidget);
    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.text('Active: 1'), findsOneWidget);

    final reportFilterHeight = tester
        .getSize(find.byType(AppDropdownFormField<ReportType>))
        .height;
    final statusFilterHeight = tester
        .getSize(find.byType(AppDropdownFormField<String>))
        .height;
    expect(reportFilterHeight, statusFilterHeight);

    await db.close();
  });

  testWidgets('Print opens an in-app report preview', (tester) async {
    final db = await openTestDatabase();
    await ClientRepository(db)
        .create(const CreateClientInput(fullName: 'Ana Cruz'));

    await tester.pumpWidget(
      Provider<ReportRepository>(
        create: (_) => ReportRepository(db),
        child: const MaterialApp(home: Scaffold(body: ReportsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Print'));
    await tester.pump();

    expect(find.text('Print preview'), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);

    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('labels the DepEd aggregate as a draft before export', (
    tester,
  ) async {
    final db = await openTestDatabase();
    await tester.pumpWidget(
      Provider<ReportRepository>(
        create: (_) => ReportRepository(db),
        child: const MaterialApp(home: Scaffold(body: ReportsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppDropdownFormField<ReportType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DepEd services report (draft)').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('not an official DepEd report'), findsOneWidget);

    await db.close();
  });
}
