import 'package:counseling_is/features/reports/data/report_exporter.dart';
import 'package:counseling_is/features/reports/data/report_repository.dart';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final exporter = ReportExporter();

  const table = ReportTable(
    columns: ['Name', 'Note'],
    rows: [
      ['Ana Cruz', 'a,b'],
      ['Ben Reyes', 'say "hi"'],
    ],
    total: 2,
  );

  test('exportCsv includes headers and rows with correct quoting', () {
    final text = exporter.exportCsv(table);

    expect(text, startsWith('\uFEFF'));
    final decoded = Csv().decode(text.replaceFirst('\uFEFF', ''));
    expect(decoded, [
      ['Name', 'Note'],
      ['Ana Cruz', 'a,b'],
      ['Ben Reyes', 'say "hi"'],
    ]);
  });

  test('exportCsv includes report draft warnings in the metadata', () {
    final text = exporter.exportCsv(
      table,
      title: 'DepEd services report (draft)',
      subtitle: 'DRAFT ONLY — verify against the official DepEd template',
    );
    final decoded = Csv().decode(text.replaceFirst('\uFEFF', ''));

    expect(decoded[0], ['Report', 'DepEd services report (draft)']);
    expect(decoded[1].join(' '), contains('DRAFT ONLY'));
    expect(decoded[2], ['Name', 'Note']);
  });

  test('exportPdf produces a valid, paginated PDF document', () async {
    final rows = [
      for (var i = 0; i < 100; i++)
        ['Client $i', 'Row number $i with a little text'],
    ];
    final big = ReportTable(
      columns: const ['Name', 'Detail'],
      rows: rows,
      total: rows.length,
    );

    final bytes = await exporter.exportPdf(
      table: big,
      title: 'Students report',
      subtitle: 'Period: all dates  ·  100 records',
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(String.fromCharCodes(bytes), contains('%%EOF'));
  });

  test('exportPdf handles an empty table', () async {
    const empty = ReportTable(columns: ['A'], rows: [], total: 0);

    final bytes = await exporter.exportPdf(
      table: empty,
      title: 'Students report',
      subtitle: 'Period: all dates  ·  0 records',
    );

    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(String.fromCharCodes(bytes), contains('%%EOF'));
  });
}
