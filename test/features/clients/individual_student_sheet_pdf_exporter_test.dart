import 'dart:convert';

import 'package:counseling_is/features/clients/data/individual_student_sheet_pdf_exporter.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final exporter = IndividualStudentSheetPdfExporter();

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

  test('exports a student record as an information sheet PDF', () async {
    final result = await exporter.export(student);
    final header = latin1.decode(result.bytes.take(8).toList());

    expect(header, startsWith('%PDF-'));
    expect(result.bytes.length, greaterThan(1000));
    expect(result.pageFormat, PdfPageFormat.a4);
  });

  test('exports a student with almost no details filled in', () async {
    final result = await exporter.export(
      Client(
        referenceNo: 'CLI-0002',
        fullName: 'New Learner',
        registeredAt: DateTime(2026, 1, 5),
        updatedAt: DateTime(2026, 1, 5),
      ),
    );

    expect(result.bytes.length, greaterThan(1000));
  });
}
