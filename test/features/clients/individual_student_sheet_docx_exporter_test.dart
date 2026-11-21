import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:counseling_is/features/clients/data/individual_student_sheet_docx_exporter.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const exporter = IndividualStudentSheetDocxExporter();

  final student = Client(
    referenceNo: 'CLI-0001',
    fullName: 'Aira Garcia Navarro',
    firstName: 'Aira',
    middleName: 'Garcia',
    lastName: 'Navarro',
    dateOfBirth: DateTime(2010, 5, 4),
    gradeSection: 'Grade 8 - Sampaguita',
    learnerNo: '123456789012',
    sex: 'Female',
    religion: 'Catholic',
    address: 'Purok 3, Carranglan, Nueva Ecija',
    memberTags: '4Ps, PWD',
    hobbies: 'Basketball',
    emergencyName: 'Rosa Navarro',
    emergencyContactNo: '09171234567',
    emergencyAddress: 'Purok 3, Carranglan',
    emergencyJob: 'Vendor',
    emergencyRelationship: 'Mother',
    fatherName: 'Rogelio Navarro',
    fatherAge: '48',
    fatherJob: 'Farmer',
    fatherWorkplace: 'Carranglan',
    fatherEducation: 'High School Graduate',
    motherName: 'Rosa Navarro',
    motherAge: '46',
    motherJob: 'Vendor',
    motherEducation: 'College Graduate',
    guardianName: 'Rosa Navarro',
    guardianRelationship: 'Mother',
    livingWith: 'Parents',
    familyIncome: 'Below ₱10,000',
    parentsStatus: 'Married and living together',
    screenNoAppetite: 'Yes',
    screenCriesOften: 'No',
    screenAbuse: 'Yes',
    screenSelfBlame: 'No',
    screenSuicidalThoughts: 'No',
    registeredAt: DateTime(2026, 1, 5),
    updatedAt: DateTime(2026, 1, 5),
  );

  Future<String> filledDocument(Client client) async {
    final bytes = await exporter.export(client, now: DateTime(2026, 11, 20));
    final archive = ZipDecoder().decodeBytes(bytes);
    final document = archive.findFile('word/document.xml');
    expect(document, isNotNull);
    return utf8.decode(document!.content);
  }

  test('fills the real Word template from a student record', () async {
    final bytes = await exporter.export(student, now: DateTime(2026, 11, 20));
    expect(bytes.length, greaterThan(1000));
    // A zip (docx) starts with the PK signature.
    expect(bytes.take(2), equals([0x50, 0x4B]));

    final xml = await filledDocument(student);

    // Write-in blanks.
    expect(xml, contains('Nov 20, 2026')); // Petsa
    expect(xml, contains('Aira')); // first name line
    expect(xml, contains('Garcia')); // middle name line
    expect(xml, contains('Grade 8 - Sampaguita')); // Antas at Pangkat
    expect(xml, contains('123456789012')); // Numero
    expect(xml, contains('Purok 3, Carranglan, Nueva Ecija')); // Tirahan
    expect(xml, contains('May 4, 2010')); // birth date
    expect(xml, contains('Basketball')); // hilig
    expect(xml, contains('Rogelio Navarro')); // tatay / gardyan row

    // ( ) option marks: income (text box + VML fallback) and parents.
    final parens = RegExp(r'\(X\)').allMatches(xml).length;
    expect(parens, greaterThanOrEqualTo(2));

    // Shape tick boxes: member tags (2), sex (1), education (2) and the
    // five Section III screening rows.
    final ticks = RegExp('<w:t>X</w:t>').allMatches(xml).length;
    expect(ticks, greaterThanOrEqualTo(8));

    // The living-with choice marks its underscore box with an X while the
    // padded line keeps its width, so the labels after it stay in place.
    final plain = xml.replaceAll(RegExp(r'<[^>]+>'), '');
    expect(plain, contains(RegExp(r'X_{3,}\s+Magulang')));
  });

  test('leaves blanks and boxes empty for a bare record', () async {
    final xml = await filledDocument(
      Client(
        referenceNo: 'CLI-0002',
        fullName: 'New Learner',
        registeredAt: DateTime(2026, 1, 5),
        updatedAt: DateTime(2026, 1, 5),
      ),
    );

    expect(xml, isNot(contains('(X)')));
    expect(xml, isNot(contains('<w:t>X</w:t>')));
    // The template's printed lines stay in place.
    expect(xml, contains(RegExp(r'_{3,}')));
  });
}
