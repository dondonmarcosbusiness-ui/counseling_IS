import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class IndividualStudentSheetExport {
  const IndividualStudentSheetExport({
    required this.bytes,
    required this.pageFormat,
  });

  final Uint8List bytes;
  final PdfPageFormat pageFormat;
}

/// Renders one student's record as the Individual Student Information Sheet —
/// the layout of the school's supplied Word template (Personal na Impormasyon,
/// emergency contact, Pamilya, well-being check), filled straight from the
/// student record so any learner can be printed without saving a form first.
class IndividualStudentSheetPdfExporter {
  static const _regularFontAsset = 'assets/fonts/roboto-regular.ttf';
  static const _boldFontAsset = 'assets/fonts/roboto-bold.ttf';
  static const _accent = PdfColor.fromInt(0xFF1F3864);
  static const _labelColor = PdfColor.fromInt(0xFF595959);
  static const _ruleColor = PdfColor.fromInt(0xFF9E9E9E);

  static const _bodyStyle = pw.TextStyle(fontSize: 8.5);
  static const _labelStyle = pw.TextStyle(fontSize: 7, color: _labelColor);
  static const _smallStyle = pw.TextStyle(fontSize: 7);

  static const _intro =
      'Pakisagutan ang mga impormasyon sa ibaba ng kumpleto at tama. Ang form '
      'na ito ay magsisilbing rekord ng CNHS-Care Center. Makakaasa ka na ang '
      'lahat ng iyong impormasyong ibabahagi ay ikokonsiderang kumpidensiyal. '
      'Ang mga impormasyon inilahad ay magsisilbing gabay ng paaralan. '
      'Maraming Salamat!';

  static const _privacy =
      'By signing this form, I agree to voluntarily provide the information to '
      'Carranglan National High School - Care Center in accordance to RA 10173 '
      'or known as the Data Privacy Act of 2012';

  /// Stored answer → the label printed on the paper form.
  static const _sexLabels = <String, String>{
    'Male': 'Lalaki',
    'Female': 'Babae',
    'Gay': 'Bakla',
    'Lesbian': 'Tomboy',
    'Bisexual': 'Bisexual',
    'Transgender': 'Transgender',
  };

  static const _livingLabels = <String, String>{
    'Parents': 'Magulang',
    'Relatives': 'Kamag-anak',
    'Sibling': 'Kapatid',
    'Other': 'Iba pa',
  };

  static const _incomeLabels = <String, String>{
    'Below ₱10,000': 'below P10,000',
    '₱10,001 – ₱20,000': 'P10,001-20,000',
    '₱20,001 – ₱30,000': 'P20,001-30,000',
    'Above ₱30,000': 'above P30,000',
  };

  Future<IndividualStudentSheetExport> export(Client client) async {
    final regularFontData = await rootBundle.load(_regularFontAsset);
    final boldFontData = await rootBundle.load(_boldFontAsset);
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(regularFontData),
          bold: pw.Font.ttf(boldFontData),
        ),
        build: (context) => [
          _title(),
          _introBlock(),
          ..._personalSection(client),
          ..._emergencySection(client),
          ..._familySection(client),
          ..._wellbeingSection(client),
          _signatureBlock(),
        ],
      ),
    );

    return IndividualStudentSheetExport(
      bytes: await document.save(),
      pageFormat: PdfPageFormat.a4,
    );
  }

  pw.Widget _title() => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(
      'INDIVIDUAL STUDENT INFORMATION SHEET',
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget _introBlock() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(_intro, style: const pw.TextStyle(fontSize: 7.5)),
      pw.SizedBox(height: 4),
      pw.Text('Petsa: ${formatDate(DateTime.now())}', style: _bodyStyle),
    ],
  );

  pw.Widget _sectionHeading(String title) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 6, bottom: 3),
    padding: const pw.EdgeInsets.only(bottom: 2),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 0.8)),
    ),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: _accent,
      ),
    ),
  );

  /// A label sitting above its underlined blank, the way the paper form
  /// prints it: the value lands on the line when one is recorded.
  pw.Widget _field(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text(label, style: _labelStyle),
      pw.Container(
        width: double.infinity,
        constraints: const pw.BoxConstraints(minHeight: 12),
        padding: const pw.EdgeInsets.only(bottom: 1),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: _ruleColor, width: 0.6),
          ),
        ),
        child: pw.Text(value, style: _bodyStyle, maxLines: 1),
      ),
    ],
  );

  pw.Widget _fields(List<({String label, String value})> entries) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final (index, entry) in entries.indexed) ...[
        if (index > 0) pw.SizedBox(width: 10),
        pw.Expanded(child: _field(entry.label, entry.value)),
      ],
    ],
  );

  pw.Widget _checks(List<({String label, bool checked})> items) => pw.Wrap(
    spacing: 12,
    runSpacing: 2,
    children: [
      for (final item in items)
        pw.Text(
          '${item.checked ? '[x]' : '[ ]'} ${item.label}',
          style: _bodyStyle,
        ),
    ],
  );

  pw.Widget _checkLine(
    String label,
    List<({String label, bool checked})> items,
  ) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: _smallStyle),
        _checks(items),
      ],
    ),
  );

  List<pw.Widget> _personalSection(Client client) => [
    _sectionHeading('I. PERSONAL NA IMPORMASYON'),
    _fields([
      (label: 'First Name', value: client.firstName ?? ''),
      (label: 'Middle Name', value: client.middleName ?? ''),
      (label: 'Last Name', value: client.lastName ?? ''),
      (label: 'Suffix', value: client.suffix ?? ''),
    ]),
    pw.SizedBox(height: 4),
    _fields([
      (label: 'Antas at Pangkat', value: client.gradeSection ?? ''),
      (label: 'Numero', value: client.learnerNo ?? ''),
    ]),
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Kabilang sa: ', style: _bodyStyle),
          pw.Expanded(child: _checks(_memberChecks(client))),
        ],
      ),
    ),
    pw.SizedBox(height: 4),
    _fields([(label: 'Permanenteng Tirahan', value: client.address ?? '')]),
    pw.SizedBox(height: 4),
    _fields([
      (
        label: 'Petsa ng Kapanganakan',
        value: client.dateOfBirth == null
            ? ''
            : formatDate(client.dateOfBirth!),
      ),
      (label: 'Edad', value: _ageOf(client)),
      (label: 'Relihiyon', value: client.religion ?? ''),
    ]),
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Kasarian: ', style: _bodyStyle),
          pw.Expanded(child: _checks(_sexChecks(client))),
        ],
      ),
    ),
  ];

  List<({String label, bool checked})> _memberChecks(Client client) {
    final recorded = client.memberTagList;
    return [
      for (final option in kMemberTagOptions)
        (label: option, checked: recorded.contains(option)),
    ];
  }

  List<({String label, bool checked})> _sexChecks(Client client) {
    final recorded = client.sex ?? '';
    final options = <({String label, bool checked})>[
      for (final entry in _sexLabels.entries)
        (label: entry.value, checked: entry.key == recorded),
    ];
    if (!_sexLabels.containsKey(recorded) && recorded.isNotEmpty) {
      options.add((label: 'Iba pa: $recorded', checked: true));
    } else {
      options.add((label: 'Iba pa', checked: false));
    }
    return options;
  }

  List<pw.Widget> _emergencySection(Client client) => [
    _sectionHeading('PERSON TO BE NOTIFIED IN CASE OF EMERGENCY'),
    _fields([
      (label: 'Pangalan', value: client.emergencyName ?? ''),
      (label: 'Contact Number', value: client.emergencyContactNo ?? ''),
      (label: 'Tirahan', value: client.emergencyAddress ?? ''),
    ]),
    pw.SizedBox(height: 4),
    _fields([
      (label: 'Trabaho', value: client.emergencyJob ?? ''),
      (label: 'Relasyon', value: client.emergencyRelationship ?? ''),
    ]),
  ];

  List<pw.Widget> _familySection(Client client) => [
    _sectionHeading('II. PAMILYA'),
    pw.Table(
      border: pw.TableBorder.all(width: 0.45),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _headerCell(''),
            _headerCell('Pangalan'),
            _headerCell('Edad'),
            _headerCell('Trabaho'),
            _headerCell('Lugar ng Trabaho'),
          ],
        ),
        _memberRow('Pangalan ng Tatay', [
          client.fatherName ?? '',
          client.fatherAge ?? '',
          client.fatherJob ?? '',
          client.fatherWorkplace ?? '',
        ]),
        _memberRow('Pangalan ng Nanay', [
          client.motherName ?? '',
          client.motherAge ?? '',
          client.motherJob ?? '',
          client.motherWorkplace ?? '',
        ]),
        _memberRow('Pangalan ng Gardyan', [
          client.guardianName ?? '',
          client.guardianAge ?? '',
          client.guardianJob ?? '',
          client.guardianWorkplace ?? '',
        ]),
      ],
    ),
    pw.SizedBox(height: 5),
    pw.Text(
      'Edukasyong Natapos (Paki-tsek)',
      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 3),
    pw.Table(
      border: pw.TableBorder.all(width: 0.45),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _headerCell('Edukasyon'),
            _headerCell('Tatay'),
            _headerCell('Nanay'),
          ],
        ),
        for (final option in kEducationOptions)
          pw.TableRow(
            children: [
              _bodyCell(option),
              _bodyCell(client.fatherEducation == option ? '[x]' : ''),
              _bodyCell(client.motherEducation == option ? '[x]' : ''),
            ],
          ),
      ],
    ),
    _checkLine('Kanino ka kasalukuyang nakatira? (Paki-tsek)', [
      for (final entry in _livingLabels.entries)
        (label: entry.value, checked: entry.key == client.livingWith),
    ]),
    _checkLine('Buwanan na kita ng Pamilya (combined)', [
      for (final entry in _incomeLabels.entries)
        (label: entry.value, checked: entry.key == client.familyIncome),
    ]),
    _checkLine('Relasyon ng iyong mga magulang (Paki-tsek)', [
      for (final option in kParentsStatusOptions)
        (
          label:
              option == 'Deceased' &&
                  (client.parentsStatusDetail?.isNotEmpty ?? false)
              ? 'Deceased, pls. specify ${client.parentsStatusDetail}'
              : option,
          checked: option == client.parentsStatus,
        ),
    ]),
    pw.SizedBox(height: 4),
    _fields([
      (label: 'Ano ang iyong hilig na gawin?', value: client.hobbies ?? ''),
    ]),
  ];

  pw.Widget _headerCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget _bodyCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.5)),
  );

  pw.TableRow _memberRow(String label, List<String> values) => pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        ),
      ),
      for (final value in values)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 7.5)),
        ),
    ],
  );

  List<pw.Widget> _wellbeingSection(Client client) => [
    _sectionHeading('III. ILANG MAHAHALAGANG MGA KATANUNGAN'),
    pw.Table(
      border: pw.TableBorder.all(width: 0.45),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: pw.FlexColumnWidth(),
        1: pw.FixedColumnWidth(34),
        2: pw.FixedColumnWidth(34),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _headerCell('*Tanong'),
            _headerCell('Oo'),
            _headerCell('Hindi'),
          ],
        ),
        for (final row in _screeningRows(client))
          pw.TableRow(
            children: [
              _bodyCell('*${row.question}'),
              _bodyCell(row.answer == 'Yes' ? '[x]' : ''),
              _bodyCell(row.answer == 'No' ? '[x]' : ''),
            ],
          ),
      ],
    ),
  ];

  List<({String question, String? answer})> _screeningRows(Client client) => [
    (
      question: 'Hindi ako makakain o walang gana sa pagkain.',
      answer: client.screenNoAppetite,
    ),
    (question: 'Madalas akong umiiyak.', answer: client.screenCriesOften),
    (
      question:
          'Ako ay nakararanas ng pang-aabuso at pananakit (sekswal/pisikal).',
      answer: client.screenAbuse,
    ),
    (
      question: 'Madalas kong sisihin ang aking sarili dahil sa aking nagawa.',
      answer: client.screenSelfBlame,
    ),
    (
      question: 'Nais kong patayin ang aking sarili.',
      answer: client.screenSuicidalThoughts,
    ),
  ];

  pw.Widget _signatureBlock() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 10),
      pw.Container(
        width: 260,
        padding: const pw.EdgeInsets.only(bottom: 1),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
        ),
        child: pw.Text(' ', style: _bodyStyle),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'Signature over Printed Name (*for student 18 years old and above',
        style: _smallStyle,
      ),
      pw.Text(
        'Or Signature of Parent/Guardian (*if the student is minor)',
        style: _smallStyle,
      ),
      pw.SizedBox(height: 4),
      pw.Text(_privacy, style: _smallStyle, textAlign: pw.TextAlign.justify),
    ],
  );

  String _ageOf(Client client) {
    final dateOfBirth = client.dateOfBirth;
    if (dateOfBirth == null) return '';
    final today = DateTime.now();
    var age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }
    return '$age';
  }
}
