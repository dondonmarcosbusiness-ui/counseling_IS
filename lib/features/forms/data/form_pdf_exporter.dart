import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class FormPdfExport {
  const FormPdfExport({required this.bytes, required this.pageFormat});

  final Uint8List bytes;
  final PdfPageFormat pageFormat;
}

class FormPdfExporter {
  static const _standardDividerColor = PdfColor.fromInt(0xFF1F3864);
  static const _logDividerColor = PdfColor.fromInt(0xFF1F4E79);
  static const _schoolSealAsset =
      'assets/forms/branding/carranglan_school_seal.png';
  static const _depedSealAsset = 'assets/forms/branding/deped_seal.png';
  static const _footerBannerAsset =
      'assets/forms/branding/deped_matatag_banner.jpg';
  static const _regularFontAsset = 'assets/fonts/roboto-regular.ttf';
  static const _boldFontAsset = 'assets/fonts/roboto-bold.ttf';
  static const _headerLines = [
    'Republic of the Philippines',
    'Department of Education',
    'REGION III – CENTRAL LUZON',
    'SCHOOLS DIVISION OFFICE OF NUEVA ECIJA',
    'CARRANGLAN NATIONAL HIGH SCHOOL',
    'F.C. Otic, Carranglan, Nueva Ecija',
  ];
  static const _contactFooter =
      'Address: F.C. Otic, Carranglan, Nueva Ecija  |  Tel: 0968-469-1828  |  '
      'Email: carranglan.national.hs.@gmail  |  FB: carranglannhsofficial';

  Future<FormPdfExport> export({
    required CounselingForm form,
    required Map<String, Object?> data,
  }) async {
    final schoolSealData = await rootBundle.load(_schoolSealAsset);
    final depedSealData = await rootBundle.load(_depedSealAsset);
    final footerBannerData = await rootBundle.load(_footerBannerAsset);
    final regularFontData = await rootBundle.load(_regularFontAsset);
    final boldFontData = await rootBundle.load(_boldFontAsset);
    final schoolSeal = pw.MemoryImage(
      schoolSealData.buffer.asUint8List(
        schoolSealData.offsetInBytes,
        schoolSealData.lengthInBytes,
      ),
    );
    final depedSeal = pw.MemoryImage(
      depedSealData.buffer.asUint8List(
        depedSealData.offsetInBytes,
        depedSealData.lengthInBytes,
      ),
    );
    final footerBanner = pw.MemoryImage(
      footerBannerData.buffer.asUint8List(
        footerBannerData.offsetInBytes,
        footerBannerData.lengthInBytes,
      ),
    );
    final pageFormat = _pageFormatFor(form.id);
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: _pageMarginsFor(form.id),
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(regularFontData),
          bold: pw.Font.ttf(boldFontData),
        ),
        header: (_) => _header(form.id, schoolSeal, depedSeal),
        footer: (_) => _footer(form.id, footerBanner),
        build: (context) => [
          _documentTitle(form),
          if (form.id == 'child_protection_intake') _internalFormNotice(),
          for (final section in form.sections) ...[
            _sectionHeading(section.title, form.id),
            if (section.information case final information?)
              _information(information),
            ..._sectionQuestions(form, section, data),
          ],
        ],
      ),
    );

    return FormPdfExport(bytes: await document.save(), pageFormat: pageFormat);
  }

  static PdfPageFormat _pageFormatFor(String formId) {
    if (formId == 'care_center_log') {
      return PdfPageFormat.a4.landscape;
    }
    if (formId == 'counseling_intake' ||
        formId == 'individual_counseling' ||
        formId == 'referral' ||
        formId == 'parent_conference' ||
        formId == 'informed_consent') {
      return PdfPageFormat.a4;
    }
    return PdfPageFormat.letter;
  }

  static pw.EdgeInsets _pageMarginsFor(String formId) {
    final sourceMargins = switch (formId) {
      'student_information' => const pw.EdgeInsets.all(36),
      'parent_conference' => const pw.EdgeInsets.fromLTRB(54, 25, 54, 18),
      'informed_consent' => const pw.EdgeInsets.fromLTRB(54, 43, 54, 43),
      'care_center_log' => const pw.EdgeInsets.all(72),
      'individual_counseling' => const pw.EdgeInsets.fromLTRB(54, 73, 54, 72),
      'counseling_intake' ||
      'referral' => const pw.EdgeInsets.fromLTRB(54, 108, 54, 72),
      _ => const pw.EdgeInsets.fromLTRB(54, 108, 54, 72),
    };
    final specialHeader =
        formId == 'care_center_log' || formId == 'informed_consent';
    final specialFooter = specialHeader;
    final headerHeight = specialHeader ? 74.0 : 126.0;
    final footerHeight = specialFooter ? 11.0 : 61.0;

    return pw.EdgeInsets.fromLTRB(
      sourceMargins.left,
      sourceMargins.top > headerHeight ? sourceMargins.top - headerHeight : 0,
      sourceMargins.right,
      sourceMargins.bottom > footerHeight
          ? sourceMargins.bottom - footerHeight
          : 0,
    );
  }

  pw.Widget _header(
    String formId,
    pw.MemoryImage schoolSeal,
    pw.MemoryImage depedSeal,
  ) {
    final hasSchoolSeal =
        formId == 'care_center_log' || formId == 'informed_consent';
    final headerText = pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _headerLine(_headerLines[0], fontSize: 8),
        _headerLine(_headerLines[1], fontSize: 14, bold: true),
        for (final line in _headerLines.skip(2))
          _headerLine(line, fontSize: 9, bold: true),
      ],
    );

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
      ),
      child: hasSchoolSeal
          ? pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(schoolSeal, width: 52.5, height: 52.5),
                pw.Expanded(child: headerText),
                pw.Image(depedSeal, width: 52.5, height: 52.5),
              ],
            )
          : pw.Column(
              children: [
                pw.Image(depedSeal, width: 52.5, height: 52.5),
                headerText,
              ],
            ),
    );
  }

  pw.Widget _headerLine(
    String text, {
    required double fontSize,
    bool bold = false,
  }) {
    return pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  pw.Widget _footer(String formId, pw.MemoryImage footerBanner) {
    final footerText = switch (formId) {
      'care_center_log' =>
        'CC Form 10  |  Carranglan National High School  |  Care Center  |  '
            'SY 2026–2027        Tirahan: F.C. Otic, Carranglan, Nueva Ecija  |  '
            'Tel: 0968-469-1828  |  Email: carranglan.national.hs.@gmail',
      'informed_consent' =>
        'Tirahan: F.C. Otic, Carranglan, Nueva Ecija  |  Tel: 0968-469-1828  |  '
            'Email: carranglan.national.hs.@gmail  |  FB: carranglannhsofficial',
      _ => _contactFooter,
    };
    final hasBanner =
        formId != 'care_center_log' && formId != 'informed_consent';

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 0.5)),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (hasBanner)
            pw.Image(
              footerBanner,
              width: 97.5,
              height: 50.5,
              fit: pw.BoxFit.contain,
            ),
          pw.Text(
            footerText,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7),
          ),
        ],
      ),
    );
  }

  pw.Widget _documentTitle(CounselingForm form) {
    final title = form.id == 'counseling_intake'
        ? 'COUNSELING INTAKE'
        : form.title.toUpperCase();
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${form.documentNo}  |  Carranglan National High School  |  '
            'Care Center  |  SY 2026–2027',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  pw.Widget _internalFormNotice() {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1),
        color: PdfColors.grey200,
      ),
      child: pw.Text(
        'INTERNAL WORKFLOW — NOT AN OFFICIAL DEPED FORM',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _sectionHeading(String title, String formId) {
    final dividerColor = formId == 'care_center_log'
        ? _logDividerColor
        : _standardDividerColor;
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 8, bottom: 5),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(color: dividerColor),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _information(String information) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        information,
        style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 2),
      ),
    );
  }

  List<pw.Widget> _sectionQuestions(
    CounselingForm form,
    FormSection section,
    Map<String, Object?> data,
  ) {
    final widgets = <pw.Widget>[];
    var pendingQuestion = <FormQuestion>[];

    void flushRow() {
      if (pendingQuestion.isEmpty) return;
      widgets.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < pendingQuestion.length; index++) ...[
              if (index > 0) pw.SizedBox(width: 10),
              pw.Expanded(
                child: _question(pendingQuestion[index], data, form.id),
              ),
            ],
          ],
        ),
      );
      widgets.add(pw.SizedBox(height: 5));
      pendingQuestion = [];
    }

    for (final question in section.questions) {
      if (question.nameGroup != null &&
          question.namePart != FormNamePart.first) {
        continue;
      }

      if (question.type == FormInputType.repeatable) {
        flushRow();
        widgets.addAll(
          _repeatableQuestion(question, data[question.id], form.id),
        );
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }

      final isWide =
          question.type == FormInputType.multiline ||
          question.type == FormInputType.choices ||
          question.type == FormInputType.checkbox;
      if (isWide) {
        flushRow();
        widgets.add(_question(question, data, form.id));
        widgets.add(pw.SizedBox(height: 6));
      } else {
        pendingQuestion.add(question);
        if (pendingQuestion.length == 2) flushRow();
      }
    }
    flushRow();
    return widgets;
  }

  pw.Widget _question(
    FormQuestion question,
    Map<String, Object?> data,
    String formId,
  ) {
    final label = question.nameGroup != null
        ? question.label.split(' — ').first
        : question.label;
    final value = question.nameGroup != null
        ? _personNameAnswer(question, data)
        : data[question.id];

    if (question.type == FormInputType.choices) {
      final Set<String> selected = value is List
          ? value.whereType<String>().toSet()
          : <String>{};
      return _choiceQuestion(label, question.options, selected);
    }
    if (question.type == FormInputType.choice) {
      final Set<String> selected = value is String && value.isNotEmpty
          ? <String>{value}
          : <String>{};
      return _choiceQuestion(label, question.options, selected);
    }
    if (question.type == FormInputType.checkbox) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value == true ? '[x] ' : '[ ] ', style: _bodyStyle),
          pw.Expanded(child: pw.Text(label, style: _bodyStyle)),
        ],
      );
    }

    final answer = _answerText(question, value);
    final isMultiline = question.type == FormInputType.multiline;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
        pw.Container(
          width: double.infinity,
          constraints: pw.BoxConstraints(minHeight: isMultiline ? 34 : 19),
          padding: const pw.EdgeInsets.only(top: 3, bottom: 2),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.45)),
          ),
          child: answer.isEmpty ? null : pw.Text(answer, style: _bodyStyle),
        ),
      ],
    );
  }

  pw.Widget _choiceQuestion(
    String label,
    List<String> options,
    Set<String> selected,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.Wrap(
            spacing: 10,
            runSpacing: 3,
            children: [
              for (final option in options)
                pw.Text(
                  '${selected.contains(option) ? '[x]' : '[ ]'} $option',
                  style: _bodyStyle,
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _repeatableQuestion(
    FormQuestion question,
    Object? value,
    String formId,
  ) {
    final entries = value is List
        ? value.whereType<Map<Object?, Object?>>().toList()
        : <Map<Object?, Object?>>[];
    final minimumRows = switch (formId) {
      'care_center_log' => 18,
      'follow_up_monitoring' => 6,
      'testing_log' => 5,
      'monthly_accomplishment' => 5,
      'parent_conference' => 4,
      'counseling_intake' => 4,
      _ => 3,
    };
    final minimumRowCount = minimumRows < 4 ? 4 : minimumRows;
    final rowCount = entries.length > minimumRowCount
        ? entries.length
        : minimumRowCount;

    return [
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(
          question.label,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Table(
        border: pw.TableBorder.all(width: 0.45),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              for (final field in question.entryFields)
                _tableCell(field.label, bold: true),
            ],
          ),
          for (var rowIndex = 0; rowIndex < rowCount; rowIndex++)
            pw.TableRow(
              children: [
                for (final field in question.entryFields)
                  _tableCell(
                    rowIndex < entries.length
                        ? _entryFieldValue(
                            entries[rowIndex][field.id],
                            field.type,
                          )
                        : '',
                  ),
              ],
            ),
        ],
      ),
    ];
  }

  pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 19),
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _entryFieldValue(Object? value, FormInputType type) {
    if (value == null) return '';
    if (type == FormInputType.checkbox) return value == true ? '[x]' : '[ ]';
    if (value is List) return value.whereType<String>().join(', ');
    final text = value.toString().trim();
    if (type == FormInputType.date) return _formatDate(text);
    return text;
  }

  String _answerText(FormQuestion question, Object? value) {
    if (value == null) return '';
    if (question.type == FormInputType.date && value is String) {
      return _formatDate(value);
    }
    if (value is List) return value.whereType<String>().join(', ');
    if (value is bool) return value ? 'Yes' : 'No';
    return value.toString().trim();
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  String _personNameAnswer(FormQuestion question, Map<String, Object?> data) {
    final group = question.nameGroup!;
    final parts =
        [
              data['${group}_first'],
              data['${group}_middle'],
              data['${group}_last'],
              data['${group}_suffix'],
            ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty);
    final fullName = parts.join(' ');
    if (fullName.isNotEmpty) return fullName;
    return data[group] is String ? (data[group] as String).trim() : '';
  }

  pw.TextStyle get _bodyStyle => const pw.TextStyle(fontSize: 8);
}
