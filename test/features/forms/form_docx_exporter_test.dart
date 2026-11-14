import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:counseling_is/features/forms/data/form_docx_exporter.dart';
import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final exporter = FormDocxExporter();
  const wordNamespace =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

  test('exports all catalog forms as valid Word documents', () async {
    for (final form in counselingFormCatalog) {
      final result = await exporter.export(form: form, data: const {});
      final archive = ZipDecoder().decodeBytes(result.bytes);
      expect(
        archive.findFile('word/document.xml'),
        isNotNull,
        reason: '${form.title} should retain its original document body.',
      );
      expect(
        archive.findFile('[Content_Types].xml'),
        isNotNull,
        reason: '${form.title} should remain a valid DOCX package.',
      );
      if (form.id == 'child_protection_intake') {
        final body = utf8.decode(
          archive.findFile('word/document.xml')!.content,
        );
        expect(body, contains('NOT AN OFFICIAL DEPED FORM'));
      }
    }
  });

  test(
    'fills a response in the original template and preserves its package',
    () async {
      final form = counselingFormById('student_information')!;
      final result = await exporter.export(
        form: form,
        data: const {'student_name': 'Alex Student'},
      );
      final archive = ZipDecoder().decodeBytes(result.bytes);
      final body = utf8.decode(archive.findFile('word/document.xml')!.content);

      expect(body, contains('STUDENT INFORMATION SHEET'));
      expect(body, contains('Full Name (Last, First, MI):'));
      expect(body, contains('Alex Student'));
      expect(result.appendedResponses, 0);
      expect(archive.findFile('word/styles.xml'), isNotNull);
      expect(archive.findFile('word/numbering.xml'), isNotNull);
    },
  );

  test('prints composed name parts in one original template field', () async {
    final form = counselingFormById('student_information')!;
    final result = await exporter.export(
      form: form,
      data: const {
        'student_name_first': 'Alex',
        'student_name_middle': 'Marie',
        'student_name_last': 'Student',
        'student_name_suffix': 'Jr.',
      },
    );
    final body = utf8.decode(
      ZipDecoder()
          .decodeBytes(result.bytes)
          .findFile('word/document.xml')!
          .content,
    );

    expect(body, contains('Alex Marie Student Jr.'));
    expect(result.appendedResponses, 0);
  });

  test(
    'fills personal details on the original student information sheet',
    () async {
      final form = counselingFormById('student_information')!;
      final result = await exporter.export(
        form: form,
        data: const {
          'form_number': '12345',
          'date_accomplished': '2026-11-03',
          'grade_section': '12 Mahogany',
          'date_of_birth': '2008-07-14',
          'age': '18',
          'sex': 'Female',
          'home_address': 'North Street',
        },
      );
      final body = utf8.decode(
        ZipDecoder()
            .decodeBytes(result.bytes)
            .findFile('word/document.xml')!
            .content,
      );

      expect(body, contains('Form No.: 12345'));
      expect(body, contains('Date Accomplished: 11/03/2026'));
      expect(body, contains('12 Mahogany'));
      expect(body, contains('☒ Female'));
      expect(body, isNot(contains('Additional responses')));
      expect(result.appendedResponses, 0);

      final document = XmlDocument.parse(body);
      final personalTable = document
          .findAllElements('tbl', namespaceUri: wordNamespace)
          .first;
      final rows = personalTable.childElements
          .where(
            (element) =>
                element.name.local == 'tr' &&
                element.name.namespaceUri == wordNamespace,
          )
          .toList();
      List<String> cellTexts(XmlElement row) => row.childElements
          .where(
            (element) =>
                element.name.local == 'tc' &&
                element.name.namespaceUri == wordNamespace,
          )
          .map(
            (cell) => cell
                .findAllElements('t', namespaceUri: wordNamespace)
                .map((text) => text.innerText)
                .join(),
          )
          .toList();

      expect(cellTexts(rows[1])[1], contains('12 Mahogany'));
      expect(body, contains('Date Accomplished: 11/03/2026'));
      expect(cellTexts(rows[1])[3], contains('07/14/2008'));
      expect(cellTexts(rows[2])[1], contains('18'));
      expect(cellTexts(rows[2])[2], contains('☐ Male  ☒ Female'));
      expect(cellTexts(rows[3])[1], contains('North Street'));
    },
  );

  test(
    'matches the revised counseling intake template and fills session rows',
    () async {
      final form = counselingFormById('counseling_intake')!;
      final result = await exporter.export(
        form: form,
        data: const {
          'learner_name': 'Jamie Student',
          'parent_guardian': 'Morgan Student',
          'grade_section': 'Grade 10 - Sampaguita',
          'sex': 'Female',
          'age': '16',
          'date_of_birth': '2010-03-12',
          'home_address': 'North Street',
          'contact_number': '555-0101',
          'form_number': 'GS-2027-01',
          'case_number': 'C-42',
          'referred_by': 'Alex Counselor',
          'designation': 'Guidance Counselor',
          'referrer_contact': '555-0102',
          'referral_date': '2026-11-05',
          'referral_nature': ['Academic difficulty', 'Others'],
          'referral_other': 'Attendance concern',
          'concern_description': 'Needs additional learning support.',
          'session_records': [
            {
              'date': '2026-11-06',
              'summary': 'Discussed attendance.',
              'interventions': 'Created a check-in plan.',
              'next_steps': 'Review progress next week.',
            },
            {
              'date': '2026-11-13',
              'summary': 'Reviewed attendance.',
              'interventions': 'Recognized progress.',
              'next_steps': 'Continue check-ins.',
            },
            {
              'date': '2026-11-20',
              'summary': 'Checked current goals.',
              'interventions': 'Updated supports.',
              'next_steps': 'Follow up with adviser.',
            },
            {
              'date': '2026-11-27',
              'summary': 'Reviewed supports.',
              'interventions': 'Adjusted plan.',
              'next_steps': 'Continue counseling.',
            },
            {
              'date': '2026-12-04',
              'summary': 'Checked progress.',
              'interventions': 'Reinforced strategies.',
              'next_steps': 'Schedule next review.',
            },
          ],
          'disposition': ['For continued counseling', 'Others'],
          'disposition_other': 'Continue weekly sessions.',
          'counselor_remarks': 'Coordinate with the class adviser.',
        },
      );
      final archive = ZipDecoder().decodeBytes(result.bytes);
      final body = utf8.decode(archive.findFile('word/document.xml')!.content);

      expect(body, contains('Form No.: GS-2027-01'));
      expect(body, contains('Date of Referral: 11/05/2026'));
      expect(body, contains('Case No.: C-42'));
      expect(body, contains('☒Female'));
      expect(body, contains('555-0101'));
      expect(body, contains('555-0102'));
      expect(body, contains('Attendance concern'));
      expect(body, contains('Needs additional learning support.'));
      expect(body, contains('☒  Academic Difficulty'));
      expect(body, contains('☒  For continued counseling'));
      expect(body, contains('Continue weekly sessions.'));
      expect(body, isNot(contains('Additional responses')));
      expect(result.appendedResponses, 0);

      final document = XmlDocument.parse(body);
      List<String> cellTexts(XmlElement row) => row.childElements
          .where(
            (element) =>
                element.name.local == 'tc' &&
                element.name.namespaceUri == wordNamespace,
          )
          .map(
            (cell) => cell
                .findAllElements('t', namespaceUri: wordNamespace)
                .map((text) => text.innerText)
                .join(),
          )
          .toList();

      expect(body, contains('Date Referred:'));
      expect(RegExp('11/05/2026').allMatches(body), hasLength(2));

      final sessionTable = document
          .findAllElements('tbl', namespaceUri: wordNamespace)
          .firstWhere(
            (table) => table
                .findAllElements('tr', namespaceUri: wordNamespace)
                .first
                .findAllElements('tc', namespaceUri: wordNamespace)
                .map(
                  (cell) => cell
                      .findAllElements('t', namespaceUri: wordNamespace)
                      .map((text) => text.innerText)
                      .join(),
                )
                .join()
                .contains('Summary of Session'),
          );
      final sessionRows = sessionTable.childElements
          .where(
            (element) =>
                element.name.local == 'tr' &&
                element.name.namespaceUri == wordNamespace,
          )
          .toList();

      expect(sessionRows, hasLength(6));
      expect(cellTexts(sessionRows[1])[1], contains('11/06/2026'));
      expect(
        cellTexts(sessionRows[1])[2],
        contains('Discussed attendance.Created a check-in plan.'),
      );
      expect(
        cellTexts(sessionRows[1])[3],
        contains('Review progress next week.'),
      );
      expect(cellTexts(sessionRows[5])[0], contains('5'));
      expect(cellTexts(sessionRows[5])[1], contains('12/04/2026'));
      expect(
        cellTexts(sessionRows[5])[2],
        contains('Checked progress.Reinforced strategies.'),
      );
    },
  );

  test(
    'sex selection marks one template checkbox and leaves the other blank',
    () async {
      final form = counselingFormById('student_information')!;
      for (final (selected, expected) in [
        ('Male', '☒ Male  ☐ Female'),
        ('Female', '☐ Male  ☒ Female'),
      ]) {
        final result = await exporter.export(
          form: form,
          data: {'sex': selected},
        );
        final body = utf8.decode(
          ZipDecoder()
              .decodeBytes(result.bytes)
              .findFile('word/document.xml')!
              .content,
        );
        expect(body, contains(expected));
        expect(result.appendedResponses, 0);
      }
    },
  );

  test(
    'prints gender as checked boxes in every matching form template',
    () async {
      for (final formId in [
        'student_information',
        'counseling_intake',
        'individual_counseling',
        'testing_log',
      ]) {
        final result = await exporter.export(
          form: counselingFormById(formId)!,
          data: const {'sex': 'Female'},
        );
        final body = utf8.decode(
          ZipDecoder()
              .decodeBytes(result.bytes)
              .findFile('word/document.xml')!
              .content,
        );

        expect(
          RegExp(r'☒\s*Female').hasMatch(body),
          isTrue,
          reason: '$formId should check the Female box.',
        );
        expect(result.appendedResponses, 0, reason: formId);
      }
    },
  );

  test('marks selected checkboxes in the source template', () async {
    final form = counselingFormById('referral')!;
    final result = await exporter.export(
      form: form,
      data: const {
        'referral_reasons': ['Self-harm / suicidal ideation'],
      },
    );
    final body = utf8.decode(
      ZipDecoder()
          .decodeBytes(result.bytes)
          .findFile('word/document.xml')!
          .content,
    );

    expect(body, contains('☒'));
    expect(result.appendedResponses, 0);
  });

  test(
    'appends answers when the template has no matching answer field',
    () async {
      final form = counselingFormById('student_information')!;
      final result = await exporter.export(
        form: form,
        data: const {'siblings': 'One sibling'},
      );
      final body = utf8.decode(
        ZipDecoder()
            .decodeBytes(result.bytes)
            .findFile('word/document.xml')!
            .content,
      );

      expect(result.appendedResponses, 1);
      expect(body, contains('Additional responses'));
      expect(body, contains('One sibling'));
    },
  );

  test('exports structured sibling and education entries', () async {
    final form = counselingFormById('student_information')!;
    final result = await exporter.export(
      form: form,
      data: const {
        'siblings': [
          {
            'first_name': 'Jamie',
            'middle_name': '',
            'last_name': 'Student',
            'suffix': '',
            'age': '12',
            'gender': 'Prefer not to say',
            'grade_year_work': 'Grade 7',
            'school': 'North School',
          },
        ],
        'education_background': [
          {
            'school_last_attended': 'South Elementary',
            'year_graduated': '2024',
            'awards_honors': 'With honors',
          },
        ],
      },
    );
    final body = utf8.decode(
      ZipDecoder()
          .decodeBytes(result.bytes)
          .findFile('word/document.xml')!
          .content,
    );

    expect(body, contains('First name: Jamie'));
    expect(body, contains('Gender: ☒ Prefer not to say'));
    expect(body, contains('School last attended: South Elementary'));
    expect(body, contains('Awards / honors: With honors'));
    expect(result.appendedResponses, 2);
  });

  test('formats dates in repeatable responses', () async {
    final form = counselingFormById('care_center_log')!;
    final result = await exporter.export(
      form: form,
      data: const {
        'visit_entries': [
          {'date': '2026-11-01', 'first_name': 'Alex'},
        ],
      },
    );
    final body = utf8.decode(
      ZipDecoder()
          .decodeBytes(result.bytes)
          .findFile('word/document.xml')!
          .content,
    );
    expect(body, contains('Date: 11/01/2026'));
    expect(body, contains('Date: 11/01/2026'));
  });
}
