import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

const _wordNamespace =
    'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _xmlNamespace = 'http://www.w3.org/XML/1998/namespace';

class FormDocxExport {
  const FormDocxExport({required this.bytes, required this.appendedResponses});

  final Uint8List bytes;
  final int appendedResponses;
}

class FormDocxExporter {
  static const _templateAssets = <String, String>{
    'student_information': 'CC_Form1_Student_Information_Sheet.docx',
    'counseling_intake': 'CC_Form2_Counseling_Intake_Form.docx',
    'individual_counseling': 'CC_Form3_Individual_Counseling_Record.docx',
    'referral': 'CC_Form4_Referral_Form.docx',
    'home_visit': 'CC_Form5_Home_Visit_Report.docx',
    'follow_up_monitoring': 'CC_Form6_Follow_Up_Monitoring_Sheet.docx',
    'parent_conference': 'CC_Form7_Parent_Conference_Report_A4_1Page.docx',
    'testing_log': 'CC_Form8_Testing_Log.docx',
    'monthly_accomplishment': 'CC_Form9_Monthly_Accomplishment_Report.docx',
    'informed_consent': 'CC_Form9_Pahintulot_na_may_Kaalaman.docx',
    'care_center_log': 'CC_Form10_Care_Center_Log_Sheet.docx',
  };

  static const _anchorOverrides = <String, Map<String, String>>{
    'student_information': {
      'form_number': 'Form No',
      'date_accomplished': 'Date Accomplished',
      'grade_section': 'Grade & Section',
      'sex': 'Sex',
      'father_name': 'Name',
      'father_occupation': 'Occupation',
      'father_education': 'Highest Educational Attainment',
      'father_contact': 'Contact No',
      'mother_name': 'Name',
      'mother_occupation': 'Occupation',
      'mother_education': 'Highest Educational Attainment',
      'mother_contact': 'Contact No',
      'guardian_name': 'Name',
      'guardian_contact_address': 'Contact No. / Address',
      'student_signature': "Student's Signature",
      'information_certified': 'I hereby certify',
    },
    'counseling_intake': {
      'form_number': 'Form No',
      'case_number': 'Case No',
      'learner_name': 'Name of Learner',
      'grade_section': 'Grade & Section',
      'sex': 'Sex',
      'contact_number': 'Contact No',
      'referral_date': 'Date of Referral',
      'referrer_contact': 'Contact No',
      'referral_other': 'Others',
      'disposition_other': 'Others',
      'counselor_remarks': "Counselor's Remarks",
    },
    'individual_counseling': {
      'case_number': 'Case No',
      'sex': 'Sex',
      'next_session_date': 'Date of Next Session',
      'referred_to': 'Referred to',
    },
    'referral': {
      'referral_number': 'Referral No',
      'referrer_contact': 'Contact No',
      'guardian_contact': 'Contact No',
      'referral_reasons': 'Reason for Referral',
      'other_reason': 'Others',
      'time_received': 'Time Received',
      'referrer_signature': 'Referring Person',
    },
    'home_visit': {
      'visit_time': 'Time',
      'address_visited': 'Home Address Visited',
      'other_purpose': 'Others',
    },
    'follow_up_monitoring': {'case_number': 'Case No'},
    'parent_conference': {
      'conference_number': 'Conference No',
      'guardian_name': 'Name',
      'guardian_contact': 'Contact No',
    },
    'testing_log': {
      'test_title': 'Test Title / Instrument Used',
      'sex': 'Sex',
      'other_test_type': 'Others',
    },
    'monthly_accomplishment': {
      'period_covered': 'Month / Period Covered',
      'activities': 'Activity / Program',
    },
    'informed_consent': {
      'form_number': 'Blg. ng Form',
      'completion_date': 'Petsa ng Pagkumpleto',
      'student_name': 'Naka-print na Pangalan ng Mag-aaral',
      'ack_read': 'Nabasa at naunawaan ko ang impormasyon',
      'ack_purpose': 'Naiintindihan ko ang layunin',
      'ack_confidentiality': 'Naiintindihan ko ang mga hangganan',
      'ack_voluntary': 'Sumasang-ayon ako',
      'ack_withdraw': 'Naiintindihan ko na maaari kong bawiin',
      'student_signature': 'Lagda ng Mag-aaral',
      'student_signature_date': 'Petsa',
      'guardian_name': 'Pangalan ng Magulang / Tagapag-alaga',
      'guardian_relationship': 'Relasyon sa Mag-aaral',
      'guardian_contact': 'Blg. ng Kontak',
      'guardian_signature': 'Lagda',
      'guardian_signature_date': 'Petsa',
      'counselor_received_date': 'Natanggap at Kinikilala ng',
    },
    'care_center_log': {
      'month_year': 'Buwan / Taon',
      'page_number': 'Pahina Blg',
    },
  };

  static const _duplicateAnchorOverrides = <String, Map<String, List<String>>>{
    'counseling_intake': {
      'referral_date': ['Date Referred'],
    },
  };

  static const _appendOnlyQuestionIds = <String, Set<String>>{
    'student_information': {'siblings', 'education_background'},
    'follow_up_monitoring': {'follow_up_entries'},
    'parent_conference': {'participants'},
    'testing_log': {'results'},
    'monthly_accomplishment': {
      'services_summary',
      'counseling_statistics',
      'activities',
    },
    'care_center_log': {'visit_entries'},
  };

  Future<FormDocxExport> export({
    required CounselingForm form,
    required Map<String, Object?> data,
  }) async {
    final templateName = _templateAssets[form.id];
    if (templateName == null) {
      if (form.id == 'child_protection_intake') {
        return _exportLocalResponseDocument(form, data);
      }
      throw ArgumentError.value(form.id, 'form.id', 'Unknown form template');
    }

    final template = await rootBundle.load(
      'assets/forms/templates/$templateName',
    );
    final archive = ZipDecoder().decodeBytes(
      template.buffer.asUint8List(
        template.offsetInBytes,
        template.lengthInBytes,
      ),
    );
    final documentFile = archive.findFile('word/document.xml');
    if (documentFile == null) {
      throw const FormatException('The Word template has no document body.');
    }

    final document = XmlDocument.parse(utf8.decode(documentFile.content));
    final body = document
        .findAllElements('body', namespaceUri: _wordNamespace)
        .firstOrNull;
    if (body == null) {
      throw const FormatException('The Word template has no document body.');
    }

    final paragraphs = <_ParagraphSlot>[];
    _collectParagraphs(body, paragraphs);
    final anchors = _resolveAnchors(form, paragraphs);
    final appended = <_AdditionalResponse>[];

    for (final section in form.sections) {
      for (final question in section.questions) {
        if (question.nameGroup != null) {
          if (question.namePart != FormNamePart.first) continue;
          final answer = _personNameAnswer(question, data);
          if (answer.isEmpty) continue;
          final slot = anchors[question.id];
          if (slot == null || !_fillTextAnswer(slot, answer, paragraphs)) {
            final subject = question.label.split(' — ').first;
            appended.add(_AdditionalResponse('$subject name', answer));
          }
          continue;
        }

        final value = data[question.id];
        final slot = anchors[question.id];
        switch (question.type) {
          case FormInputType.text:
          case FormInputType.multiline:
          case FormInputType.date:
            final answer = _answerText(question, value);
            if (answer.isEmpty) continue;
            final filled =
                slot != null &&
                !(_appendOnlyQuestionIds[form.id]?.contains(question.id) ??
                    false) &&
                _fillTextAnswer(slot, answer, paragraphs);
            if (!filled) {
              appended.add(_AdditionalResponse(question.label, answer));
            } else {
              _fillDuplicateAnchors(
                form.id,
                question.id,
                answer,
                slot,
                paragraphs,
              );
            }
          case FormInputType.choice:
          case FormInputType.choices:
            final selected = value is List
                ? value.whereType<String>().toList()
                : value is String && value.isNotEmpty
                ? [value]
                : <String>[];
            if (selected.isEmpty) continue;
            final marked =
                slot != null &&
                _markSelectedOptions(
                  paragraphs,
                  slot.index,
                  _nextAnchorIndex(anchors, slot.index, paragraphs.length) + 1,
                  selected,
                );
            if (!marked) {
              appended.add(
                _AdditionalResponse(
                  question.label,
                  _genderAnswer(question.id, selected),
                ),
              );
            }
          case FormInputType.checkbox:
            if (value == true) {
              final isDeclaration =
                  form.id == 'student_information' &&
                  question.id == 'information_certified';
              if (!isDeclaration &&
                  (slot == null || !_markCheckbox(slot.paragraph))) {
                appended.add(_AdditionalResponse(question.label, 'Yes'));
              }
            }
          case FormInputType.repeatable:
            if (form.id == 'counseling_intake' &&
                question.id == 'session_records') {
              if (!_fillCounselingSessions(body, value)) {
                final answer = _repeatableAnswer(question, value);
                if (answer.isNotEmpty) {
                  appended.add(_AdditionalResponse(question.label, answer));
                }
              }
              continue;
            }
            final answer = _repeatableAnswer(question, value);
            if (answer.isNotEmpty) {
              appended.add(_AdditionalResponse(question.label, answer));
            }
        }
      }
    }

    if (appended.isNotEmpty) {
      _appendAdditionalResponses(body, appended);
    }

    archive.add(
      ArchiveFile.bytes(
        'word/document.xml',
        utf8.encode(document.toXmlString()),
      ),
    );
    final bytes = ZipEncoder().encode(archive);
    if (bytes.isEmpty) {
      throw const FormatException('The completed Word document is empty.');
    }
    return FormDocxExport(
      bytes: Uint8List.fromList(bytes),
      appendedResponses: appended.length,
    );
  }

  FormDocxExport _exportLocalResponseDocument(
    CounselingForm form,
    Map<String, Object?> data,
  ) {
    final paragraphs = <String>[
      form.title,
      'INTERNAL WORKFLOW — NOT AN OFFICIAL DEPED FORM',
    ];
    for (final section in form.sections) {
      paragraphs.add(section.title);
      for (final question in section.questions) {
        if (question.nameGroup != null) {
          if (question.namePart != FormNamePart.first) continue;
          final answer = _personNameAnswer(question, data);
          paragraphs.add('${question.nameAnchor ?? question.label}: $answer');
          continue;
        }
        final value = data[question.id];
        if (question.type == FormInputType.repeatable) {
          final entries = value is List
              ? value.whereType<Map<Object?, Object?>>().toList()
              : const <Map<Object?, Object?>>[];
          if (entries.isEmpty) {
            paragraphs.add('${question.label}: —');
            continue;
          }
          paragraphs.add('${question.label}:');
          for (final entry in entries) {
            for (final field in question.entryFields) {
              paragraphs.add(
                '  ${field.label}: ${entry[field.id]?.toString() ?? ''}',
              );
            }
          }
        } else {
          paragraphs.add('${question.label}: ${_displayValue(value)}');
        }
      }
    }

    final wordParagraphs = paragraphs
        .map(
          (text) =>
              '<w:p><w:r><w:t xml:space="preserve">${_escapeXml(text)}</w:t></w:r></w:p>',
        )
        .join();
    final documentXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="$_wordNamespace">'
        '<w:body>$wordParagraphs'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" '
        'w:left="1440"/></w:sectPr></w:body></w:document>';
    final archive = Archive()
      ..add(
        ArchiveFile.bytes(
          '[Content_Types].xml',
          utf8.encode(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/word/document.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
            '</Types>',
          ),
        ),
      )
      ..add(
        ArchiveFile.bytes(
          '_rels/.rels',
          utf8.encode(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
            'Target="word/document.xml"/>'
            '</Relationships>',
          ),
        ),
      )
      ..add(ArchiveFile.bytes('word/document.xml', utf8.encode(documentXml)));
    final bytes = ZipEncoder().encode(archive);
    if (bytes.isEmpty) {
      throw const FormatException('The completed Word document is empty.');
    }
    return FormDocxExport(
      bytes: Uint8List.fromList(bytes),
      appendedResponses: 0,
    );
  }

  String _displayValue(Object? value) {
    if (value == null) return '';
    if (value is List) return value.join(', ');
    if (value is bool) return value ? 'Yes' : 'No';
    return value.toString();
  }

  String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  void _fillDuplicateAnchors(
    String formId,
    String questionId,
    String answer,
    _ParagraphSlot primarySlot,
    List<_ParagraphSlot> paragraphs,
  ) {
    final duplicateAnchors =
        _duplicateAnchorOverrides[formId]?[questionId] ?? const [];
    for (final anchor in duplicateAnchors) {
      final normalizedAnchor = _normalize(anchor);
      for (final slot in paragraphs.skip(primarySlot.index + 1)) {
        if (!_normalize(_paragraphText(slot.paragraph))
            .contains(normalizedAnchor)) {
          continue;
        }
        _fillTextAnswer(
          _ParagraphSlot(
            paragraph: slot.paragraph,
            cell: slot.cell,
            row: slot.row,
            index: slot.index,
            anchor: anchor,
          ),
          answer,
          paragraphs,
        );
        break;
      }
    }
  }

  bool _fillCounselingSessions(XmlElement body, Object? value) {
    if (value is! List) return true;
    final entries = value.whereType<Map<Object?, Object?>>().where((entry) {
      return entry.values.any(
        (field) => field != null && field.toString().trim().isNotEmpty,
      );
    }).toList();
    if (entries.isEmpty) return true;

    XmlElement? sessionTable;
    for (final table in body.findAllElements(
      'tbl',
      namespaceUri: _wordNamespace,
    )) {
      final header = table
          .findAllElements('tr', namespaceUri: _wordNamespace)
          .firstOrNull;
      if (header == null) continue;
      final headerCells = _tableCells(header)
          .map((cell) => _normalize(_elementText(cell)))
          .toList();
      if (headerCells.length < 4 ||
          !headerCells[0].contains('session') ||
          !headerCells[1].contains('date') ||
          !headerCells[2].contains('summaryofsessioninterventionapplied') ||
          !headerCells[3].contains('nextstepsfollowup')) {
        continue;
      }
      sessionTable = table;
      break;
    }
    if (sessionTable == null) return false;

    var rows = sessionTable.childElements
        .where(
          (element) =>
              element.name.local == 'tr' &&
              element.name.namespaceUri == _wordNamespace,
        )
        .toList();
    if (rows.length < 2) return false;

    for (var index = 0; index < entries.length; index++) {
      if (index + 1 >= rows.length) {
        final clone = rows.last.copy();
        sessionTable.children.insert(
          sessionTable.children.indexOf(rows.last) + 1,
          clone,
        );
        rows = [...rows, clone];
      }
      final cells = _tableCells(rows[index + 1]);
      if (cells.length < 4) return false;
      if (index >= 4) _setCellText(cells[0], '${index + 1}');

      final entry = entries[index];
      final date = _formatSessionDate(entry['date']?.toString() ?? '');
      final summary = [
        entry['summary']?.toString().trim(),
        entry['interventions']?.toString().trim(),
      ].whereType<String>().where((text) => text.isNotEmpty).join('\n');
      final nextSteps = entry['next_steps']?.toString().trim() ?? '';

      _setCellText(cells[1], date);
      _setCellText(cells[2], summary);
      _setCellText(cells[3], nextSteps);
    }
    return true;
  }

  List<XmlElement> _tableCells(XmlElement row) => row.childElements
      .where(
        (element) =>
            element.name.local == 'tc' &&
            element.name.namespaceUri == _wordNamespace,
      )
      .toList();

  String _formatSessionDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  Map<String, _ParagraphSlot> _resolveAnchors(
    CounselingForm form,
    List<_ParagraphSlot> paragraphs,
  ) {
    final result = <String, _ParagraphSlot>{};
    var cursor = 0;
    String? previousAnchor;
    final intakeAnchorOffsets = <String, int>{};
    final overrides = _anchorOverrides[form.id] ?? const {};
    for (final section in form.sections) {
      for (final question in section.questions) {
        if (question.nameGroup != null &&
            question.namePart != FormNamePart.first) {
          continue;
        }
        final anchor =
            overrides[question.nameGroup] ??
            overrides[question.id] ??
            question.nameAnchor ??
            question.label;
        final normalizedAnchor = _normalize(anchor);
        if (normalizedAnchor.isEmpty) continue;
        final intakeForm = form.id == 'counseling_intake';
        final start = intakeForm
            ? intakeAnchorOffsets[normalizedAnchor] ?? 0
            : normalizedAnchor == previousAnchor
            ? cursor + 1
            : cursor;
        for (var index = start; index < paragraphs.length; index++) {
          if (_normalize(_paragraphText(paragraphs[index].paragraph))
              .contains(normalizedAnchor)) {
            result[question.id] = _ParagraphSlot(
              paragraph: paragraphs[index].paragraph,
              cell: paragraphs[index].cell,
              row: paragraphs[index].row,
              index: index,
              anchor: anchor,
            );
            cursor = index;
            previousAnchor = normalizedAnchor;
            if (intakeForm) intakeAnchorOffsets[normalizedAnchor] = index + 1;
            break;
          }
        }
      }
    }
    return result;
  }

  void _collectParagraphs(
    XmlElement element,
    List<_ParagraphSlot> paragraphs, {
    XmlElement? cell,
    XmlElement? row,
  }) {
    final localName = element.name.local;
    if (element.name.namespaceUri == _wordNamespace && localName == 'tc') {
      cell = element;
    } else if (element.name.namespaceUri == _wordNamespace &&
        localName == 'tr') {
      row = element;
    } else if (element.name.namespaceUri == _wordNamespace &&
        localName == 'p') {
      paragraphs.add(
        _ParagraphSlot(
          paragraph: element,
          cell: cell,
          row: row,
          index: paragraphs.length,
        ),
      );
      return;
    }
    for (final child in element.childElements) {
      _collectParagraphs(child, paragraphs, cell: cell, row: row);
    }
  }

  bool _fillTextAnswer(
    _ParagraphSlot slot,
    String answer,
    List<_ParagraphSlot> paragraphs,
  ) {
    final anchor = slot.anchor;
    if (anchor != null &&
        _replaceUnderscoresAfterAnchor(slot.paragraph, anchor, answer)) {
      return true;
    }
    if (_replaceUnderscores(slot.paragraph, answer)) return true;

    final row = slot.row;
    final currentCell = slot.cell;
    if (row != null && currentCell != null) {
      final cells = row.childElements
          .where(
            (element) =>
                element.name.local == 'tc' &&
                element.name.namespaceUri == _wordNamespace,
          )
          .toList();
      final currentIndex = cells.indexOf(currentCell);
      for (var index = currentIndex + 1; index < cells.length; index++) {
        final text = _elementText(cells[index]);
        if (_isBlankOrLine(text)) {
          _setCellText(cells[index], answer);
          return true;
        }
      }
    }

    final cell = slot.cell;
    if (cell != null) {
      final cellParagraphs = cell
          .findAllElements('p', namespaceUri: _wordNamespace)
          .toList();
      for (final paragraph in cellParagraphs.skip(1)) {
        if (_isBlankOrLine(_paragraphText(paragraph))) {
          _setParagraphText(paragraph, answer);
          return true;
        }
      }
      _appendInlineText(slot.paragraph, answer);
      return true;
    }

    for (final next in paragraphs.skip(slot.index + 1)) {
      final text = _paragraphText(next.paragraph);
      if (_isBlankOrLine(text)) {
        _setParagraphText(next.paragraph, answer);
        return true;
      }
      if (text.trim().isNotEmpty) break;
    }

    _appendInlineText(slot.paragraph, answer);
    return true;
  }

  bool _replaceUnderscoresAfterAnchor(
    XmlElement element,
    String anchor,
    String answer,
  ) {
    final nodes = element
        .findAllElements('t', namespaceUri: _wordNamespace)
        .map((text) => text.children.whereType<XmlText>().firstOrNull)
        .whereType<XmlText>()
        .toList();
    final fullText = nodes.map((node) => node.value).join();
    final anchorStart = fullText.toLowerCase().indexOf(anchor.toLowerCase());
    if (anchorStart < 0) return false;

    final anchorEnd = anchorStart + anchor.length;
    for (final match in RegExp(r'_{3,}').allMatches(fullText)) {
      if (match.start < anchorEnd) continue;

      var offset = 0;
      var insertedAnswer = false;
      for (final node in nodes) {
        final nodeEnd = offset + node.value.length;
        if (match.start < nodeEnd && match.end > offset) {
          final localStart = match.start > offset ? match.start - offset : 0;
          final localEnd = match.end < nodeEnd
              ? match.end - offset
              : node.value.length;
          node.value = node.value.replaceRange(
            localStart,
            localEnd,
            insertedAnswer ? '' : answer,
          );
          insertedAnswer = true;
        }
        offset = nodeEnd;
      }
      return insertedAnswer;
    }
    return false;
  }

  bool _replaceUnderscores(XmlElement element, String answer) {
    final textNodes = element.findAllElements(
      't',
      namespaceUri: _wordNamespace,
    );
    for (final text in textNodes) {
      final node = text.children.whereType<XmlText>().firstOrNull;
      if (node == null || !RegExp(r'_{3,}').hasMatch(node.value)) continue;
      node.value = node.value.replaceFirst(RegExp(r'_{3,}'), answer);
      return true;
    }
    return false;
  }

  void _setCellText(XmlElement cell, String value) {
    final paragraph = cell
        .findAllElements('p', namespaceUri: _wordNamespace)
        .firstOrNull;
    if (paragraph == null) {
      cell.children.add(_newElement('p'));
      _setParagraphText(cell.childElements.last, value);
    } else if (!_replaceUnderscores(paragraph, value)) {
      _setParagraphText(paragraph, value);
    }
  }

  void _setParagraphText(XmlElement paragraph, String value) {
    final paragraphProperties = paragraph.childElements
        .where(
          (element) =>
              element.name.local == 'pPr' &&
              element.name.namespaceUri == _wordNamespace,
        )
        .map((element) => element.copy())
        .toList();
    final runProperties = paragraph
        .findAllElements('r', namespaceUri: _wordNamespace)
        .expand((run) => run.childElements)
        .where(
          (element) =>
              element.name.local == 'rPr' &&
              element.name.namespaceUri == _wordNamespace,
        )
        .map((element) => element.copy())
        .firstOrNull;
    paragraph.children.clear();
    paragraph.children.addAll(paragraphProperties);
    _appendRuns(
      paragraph,
      value,
      runProperties: runProperties == null ? null : [runProperties],
    );
  }

  void _appendInlineText(XmlElement paragraph, String value) {
    final existingRun = paragraph
        .findAllElements('r', namespaceUri: _wordNamespace)
        .lastOrNull;
    final runProperties = existingRun?.childElements
        .where(
          (element) =>
              element.name.local == 'rPr' &&
              element.name.namespaceUri == _wordNamespace,
        )
        .map((element) => element.copy())
        .toList();
    final run = _newElement('r');
    if (runProperties != null) run.children.addAll(runProperties);
    _appendTextNodes(run, ' $value');
    paragraph.children.add(run);
  }

  void _appendRuns(
    XmlElement paragraph,
    String value, {
    List<XmlElement>? runProperties,
  }) {
    for (final line in value.split('\n').indexed) {
      if (line.$1 > 0) {
        final breakRun = _newElement('r');
        breakRun.children.add(_newElement('br'));
        paragraph.children.add(breakRun);
      }
      final run = _newElement('r');
      if (runProperties != null) {
        run.children.addAll(runProperties.map((property) => property.copy()));
      }
      _appendTextNodes(run, line.$2);
      paragraph.children.add(run);
    }
  }

  void _appendTextNodes(XmlElement run, String value) {
    final text = _newElement(
      't',
      attributes: [
        XmlAttribute(
          const XmlName.qualified('xml:space', namespaceUri: _xmlNamespace),
          'preserve',
        ),
      ],
      children: [XmlText(value)],
    );
    run.children.add(text);
  }

  bool _markSelectedOptions(
    List<_ParagraphSlot> paragraphs,
    int start,
    int end,
    List<String> options,
  ) {
    var allMarked = true;
    for (final option in options) {
      var marked = false;
      final normalizedOption = _normalize(option);
      for (final slot in paragraphs.skip(start).take(end - start)) {
        final textNodes = slot.paragraph
            .findAllElements('t', namespaceUri: _wordNamespace)
            .toList();
        final texts = textNodes
            .map((element) => element.children.whereType<XmlText>().firstOrNull)
            .toList();
        final fullText = texts.map((node) => node?.value ?? '').join();
        final normalizedText = _normalize(fullText);
        if (!normalizedText.contains(normalizedOption)) continue;

        final optionPosition = fullText.toLowerCase().indexOf(
          option.toLowerCase(),
        );
        if (optionPosition < 0) continue;
        final checkboxPosition = fullText.lastIndexOf('☐', optionPosition);
        if (checkboxPosition < 0 || optionPosition - checkboxPosition > 5) {
          continue;
        }
        var offset = 0;
        for (final node in texts) {
          final value = node?.value ?? '';
          if (checkboxPosition >= offset &&
              checkboxPosition < offset + value.length) {
            final localPosition = checkboxPosition - offset;
            node!.value = value.replaceRange(
              localPosition,
              localPosition + 1,
              '☒',
            );
            marked = true;
            break;
          }
          offset += value.length;
        }
        if (marked) break;
      }
      allMarked = allMarked && marked;
    }
    return allMarked;
  }

  bool _markCheckbox(XmlElement paragraph) {
    final checkbox = paragraph
        .findAllElements('t', namespaceUri: _wordNamespace)
        .expand((element) => element.children.whereType<XmlText>())
        .where((node) => node.value.contains('☐'))
        .firstOrNull;
    if (checkbox == null) return false;
    checkbox.value = checkbox.value.replaceFirst('☐', '☒');
    return true;
  }

  int _nextAnchorIndex(
    Map<String, _ParagraphSlot> anchors,
    int current,
    int fallback,
  ) {
    for (final slot in anchors.values) {
      if (slot.index > current && slot.index < fallback) {
        fallback = slot.index;
      }
    }
    return fallback;
  }

  void _appendAdditionalResponses(
    XmlElement body,
    List<_AdditionalResponse> responses,
  ) {
    final sectionPropertiesIndex = body.children.indexWhere(
      (node) =>
          node is XmlElement &&
          node.name.local == 'sectPr' &&
          node.name.namespaceUri == _wordNamespace,
    );
    final insertIndex = sectionPropertiesIndex < 0
        ? body.children.length
        : sectionPropertiesIndex;
    final pageBreak = _newElement('p');
    final breakRun = _newElement('r');
    breakRun.children.add(
      _newElement(
        'br',
        attributes: [
          XmlAttribute(
            const XmlName.parts(
              'type',
              prefix: 'w',
              namespaceUri: _wordNamespace,
            ),
            'page',
          ),
        ],
      ),
    );
    pageBreak.children.add(breakRun);
    final appendix = <XmlElement>[
      pageBreak,
      _paragraphWithText('Additional responses'),
      for (final response in responses)
        _paragraphWithText('${response.label}: ${response.value}'),
    ];
    body.children.insertAll(insertIndex, appendix);
  }

  XmlElement _paragraphWithText(String text) {
    final paragraph = _newElement('p');
    final run = _newElement('r');
    _appendTextNodes(run, text);
    paragraph.children.add(run);
    return paragraph;
  }

  XmlElement _newElement(
    String localName, {
    Iterable<XmlAttribute> attributes = const [],
    Iterable<XmlNode> children = const [],
  }) {
    return XmlElement(
      XmlName.parts(localName, prefix: 'w', namespaceUri: _wordNamespace),
      attributes,
      children,
    );
  }

  String _paragraphText(XmlElement paragraph) => _elementText(paragraph);

  String _elementText(XmlElement element) => element
      .findAllElements('t', namespaceUri: _wordNamespace)
      .map(
        (text) => text.children.whereType<XmlText>().firstOrNull?.value ?? '',
      )
      .join();

  String _answerText(FormQuestion question, Object? value) {
    if (value == null) return '';
    if (value is String) {
      final trimmed = value.trim();
      if (question.type == FormInputType.date) {
        final date = DateTime.tryParse(trimmed);
        if (date != null) {
          return '${date.month.toString().padLeft(2, '0')}/'
              '${date.day.toString().padLeft(2, '0')}/'
              '${date.year}';
        }
      }
      return trimmed;
    }
    if (value is List) {
      return value.whereType<String>().join(', ').trim();
    }
    if (value is bool) return value ? 'Yes' : '';
    return '$value'.trim();
  }

  String _repeatableAnswer(FormQuestion question, Object? value) {
    if (value is String) return value.trim();
    if (value is! List) return '';

    final rows = <String>[];
    for (var index = 0; index < value.length; index++) {
      final row = value[index];
      if (row is! Map) continue;
      final fields = <String>[];
      for (final field in question.entryFields) {
        var answer = row[field.id]?.toString().trim() ?? '';
        if (field.type == FormInputType.date) {
          answer = _formatDateAnswer(answer);
        } else if (field.type == FormInputType.choice &&
            field.label.toLowerCase().contains('gender') &&
            answer.isNotEmpty) {
          answer = _genderAnswer(field.id, [answer]);
        }
        if (answer.isNotEmpty) fields.add('${field.label}: $answer');
      }
      if (fields.isNotEmpty) {
        rows.add(
          '${question.entryLabel[0].toUpperCase()}'
          '${question.entryLabel.substring(1)} '
          '${index + 1}: ${fields.join('; ')}',
        );
      }
    }
    return rows.join('\n');
  }

  String _genderAnswer(String questionId, List<String> selected) {
    if (questionId != 'sex' && questionId != 'gender') {
      return selected.join(', ');
    }
    return selected.map((option) => '☒ $option').join(', ');
  }

  String _formatDateAnswer(String value) {
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
    final composed = parts.join(' ');
    if (composed.isNotEmpty) return composed;
    return data[group] is String ? (data[group] as String).trim() : '';
  }

  bool _isBlankOrLine(String text) =>
      text.trim().isEmpty || RegExp(r'^[_\s]+$').hasMatch(text);

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class _ParagraphSlot {
  const _ParagraphSlot({
    required this.paragraph,
    required this.cell,
    required this.row,
    required this.index,
    this.anchor,
  });

  final XmlElement paragraph;
  final XmlElement? cell;
  final XmlElement? row;
  final int index;
  final String? anchor;
}

class _AdditionalResponse {
  const _AdditionalResponse(this.label, this.value);

  final String label;
  final String value;
}
