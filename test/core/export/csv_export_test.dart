import 'package:counseling_is/core/export/csv_export.dart';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes plain rows with CRLF line endings and a BOM', () {
    final out = encodeCsv([
      ['a', 'b'],
      ['c', 'd'],
    ]);

    expect(out, startsWith('\uFEFF'));
    expect(out, contains('\r\n'));
    final lines = out
        .substring(1)
        .split('\r\n')
        .where((line) => line.isNotEmpty)
        .toList();
    expect(lines, ['a,b', 'c,d']);
  });

  test('quotes only the fields that need it', () {
    final out = encodeCsv([
      ['plain', 'x,y'],
      ['say "hi"', 'line1\nline2'],
    ]);
    final body = out.substring(1);

    expect(body, contains('plain,'));
    expect(body, contains('"x,y"'));
    expect(body, contains('"say ""hi"""'));
    expect(body, contains('"line1\nline2"'));
  });

  test('round-trips through the CSV decoder', () {
    const rows = [
      ['Reference', 'Full name'],
      ['CLI-2026-0001', 'María, "M"'],
    ];

    final decoded = Csv().decode(encodeCsv(rows).replaceFirst('\uFEFF', ''));

    expect(decoded, rows);
  });

  test('empty input yields only the BOM', () {
    expect(encodeCsv(const []), '\uFEFF');
  });
}
