import 'dart:convert';

import 'package:counseling_is/features/forms/data/form_pdf_exporter.dart';
import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final exporter = FormPdfExporter();

  test('exports every counseling form as a PDF', () async {
    for (final form in counselingFormCatalog) {
      final result = await exporter.export(form: form, data: const {});
      final header = latin1.decode(result.bytes.take(8).toList());

      expect(
        header,
        startsWith('%PDF-'),
        reason: '${form.title} should be a valid PDF.',
      );
      expect(
        result.bytes.length,
        greaterThan(1000),
        reason: '${form.title} should contain its rendered form content.',
      );
    }
  });

  test('uses the supplied form sizes and landscape orientation', () async {
    final studentForm = await exporter.export(
      form: counselingFormById('student_information')!,
      data: const {},
    );
    final intakeForm = await exporter.export(
      form: counselingFormById('counseling_intake')!,
      data: const {},
    );
    final logForm = await exporter.export(
      form: counselingFormById('care_center_log')!,
      data: const {},
    );

    expect(studentForm.pageFormat.width, closeTo(612, 1));
    expect(studentForm.pageFormat.height, closeTo(792, 1));
    expect(intakeForm.pageFormat.width, closeTo(595, 1));
    expect(intakeForm.pageFormat.height, closeTo(842, 1));
    expect(logForm.pageFormat.width, greaterThan(logForm.pageFormat.height));
  });

  test('keeps repeatable rows beyond the template blank-row count', () async {
    final form = counselingFormById('care_center_log')!;
    final blankResult = await exporter.export(form: form, data: const {});
    final filledResult = await exporter.export(
      form: form,
      data: {
        'visit_entries': [
          for (var index = 0; index < 20; index++)
            {'first_name': 'Learner $index', 'remarks': 'Record $index'},
        ],
      },
    );

    expect(filledResult.bytes.length, greaterThan(blankResult.bytes.length));
  });
}
