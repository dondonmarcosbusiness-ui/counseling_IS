import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

const _wordNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _mcNs = 'http://schemas.openxmlformats.org/markup-compatibility/2006';
const _wpNs =
    'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';
const _aNs = 'http://schemas.openxmlformats.org/drawingml/2006/main';
const _wpsNs =
    'http://schemas.microsoft.com/office/word/2010/'
    'wordprocessingShape';
const _wpgNs =
    'http://schemas.microsoft.com/office/word/2010/'
    'wordprocessingGroup';
const _vNs = 'urn:schemas-microsoft-com:vml';

const _tickRun =
    '<w:r><w:rPr><w:rFonts w:ascii="Times New Roman" '
    'w:hAnsi="Times New Roman"/><w:sz w:val="14"/></w:rPr>'
    '<w:t>X</w:t></w:r>';

/// Fills the real Individual Student Information Sheet .docx template with one
/// student's record so the printed sheet keeps the exact DepEd layout, logos
/// and typography of the original Word file.
///
/// The template mixes three kinds of marks, and this exporter handles all of
/// them: underscore runs for write-in blanks, literal `( )` parens for the
/// income/parents options, and small absolutely-positioned rectangle shapes
/// (DrawingML `wps:wsp` with a VML `v:rect` fallback) for every tick box —
/// Kasarian, Kabilang sa, education and the Section III screening rows.
class IndividualStudentSheetDocxExporter {
  const IndividualStudentSheetDocxExporter();

  static const templateAsset =
      'assets/forms/templates/Individual_Student_Information_Sheet.docx';

  /// Renders the filled document as raw .docx bytes.
  Future<Uint8List> export(Client client, {DateTime? now}) async {
    final moment = now ?? DateTime.now();
    final template = await rootBundle.load(templateAsset);
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
        .findAllElements('body', namespaceUri: _wordNs)
        .firstOrNull;
    if (body == null) {
      throw const FormatException('The Word template has no document body.');
    }
    final paragraphs = body.childElements
        .where(
          (element) =>
              element.name.local == 'p' && element.name.namespaceUri == _wordNs,
        )
        .toList();

    _fillHeader(paragraphs, client, moment);
    _fillPersonal(paragraphs, client, moment);
    _fillEmergency(paragraphs, client);
    _fillFamily(paragraphs, client);
    _fillLivingWith(paragraphs, client);
    _fillHobbies(paragraphs, client);
    _fillOptions(document, paragraphs, client);
    _tickEducation(paragraphs, client);
    _tickMemberTags(paragraphs, client);
    _tickSex(paragraphs, client);
    _tickScreening(paragraphs, client);

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
    return Uint8List.fromList(bytes);
  }

  // ---------------------------------------------------------------- blanks --

  void _fillHeader(List<XmlElement> paragraphs, Client client, DateTime now) {
    final petsa = _firstWhere(
      paragraphs,
      (text) => text.trimLeft().startsWith('Petsa:'),
    );
    if (petsa != null) _fillBlank(petsa, 0, formatDate(now));
  }

  void _fillPersonal(List<XmlElement> paragraphs, Client client, DateTime now) {
    // The name line is a blank-only paragraph whose following paragraph holds
    // the First / Middle / Last Name labels.
    for (var index = 0; index < paragraphs.length; index++) {
      if (!_isBlankLine(_textOf(paragraphs[index]))) continue;
      final next = index + 1 < paragraphs.length
          ? _textOf(paragraphs[index + 1])
          : '';
      if (!next.contains('First Name')) continue;
      final names = _resolvedNames(client);
      _fillBlanks(paragraphs[index], [names.first, names.middle, names.last]);
      break;
    }

    final antas = _firstWhere(
      paragraphs,
      (text) => text.contains('Antas at Pangkat'),
    );
    if (antas != null) {
      _fillBlanks(antas, [client.gradeSection, client.learnerNo]);
    }

    final address = _firstWhere(
      paragraphs,
      (text) => text.contains('Permanenteng Tirahan'),
    );
    if (address != null) _fillBlank(address, 0, client.address ?? '');

    final birth = _firstWhere(
      paragraphs,
      (text) => text.contains('Petsa ng Kapanganakan'),
    );
    if (birth != null) {
      final dateOfBirth = client.dateOfBirth;
      _fillBlanks(birth, [
        dateOfBirth == null ? '' : formatDate(dateOfBirth),
        dateOfBirth == null ? '' : '${_ageOn(dateOfBirth, now)}',
        client.religion ?? '',
      ]);
    }
  }

  void _fillEmergency(List<XmlElement> paragraphs, Client client) {
    final contact = _firstWhere(
      paragraphs,
      (text) => text.contains('Pangalan:') && text.contains('Contact Number:'),
    );
    if (contact != null) {
      _fillBlanks(contact, [
        client.emergencyName,
        client.emergencyContactNo,
        client.emergencyAddress,
      ]);
    }
    final job = _firstWhere(
      paragraphs,
      (text) => text.contains('Trabaho:') && text.contains('Relasyon:'),
    );
    if (job != null) {
      _fillBlanks(job, [client.emergencyJob, client.emergencyRelationship]);
    }
  }

  void _fillFamily(List<XmlElement> paragraphs, Client client) {
    // Each family row is a blank-only paragraph followed by a paragraph with
    // the Tatay / Nanay / Gardyan labels; the Gardyan blanks sit at the end of
    // the paragraph that carries the Nanay labels.
    for (var index = 0; index < paragraphs.length; index++) {
      if (!_isBlankLine(_textOf(paragraphs[index]))) continue;
      final next = index + 1 < paragraphs.length
          ? _textOf(paragraphs[index + 1])
          : '';
      if (next.contains('Pangalan ng Tatay')) {
        _fillFour(paragraphs[index], [
          client.fatherName,
          client.fatherAge,
          client.fatherJob,
          client.fatherWorkplace,
        ]);
      } else if (next.contains('Pangalan ng Nanay')) {
        _fillFour(paragraphs[index], [
          client.motherName,
          client.motherAge,
          client.motherJob,
          client.motherWorkplace,
        ]);
      }
    }
    final guardianRow = _firstWhere(
      paragraphs,
      (text) =>
          text.contains('Pangalan ng Nanay') && RegExp(r'_{3,}').hasMatch(text),
    );
    if (guardianRow != null) {
      final filled = _fillBlanks(guardianRow, [
        client.guardianName,
        client.guardianAge,
        client.guardianJob,
        client.guardianWorkplace,
      ]);
      // The template keeps the Gardyan blanks on their own line only because
      // the underscore runs overflow the line above; a filled value is
      // shorter than the run it replaces, so the line would collapse back up
      // next to the Nanay labels. Break explicitly to hold the layout.
      if (filled) _breakBeforeFirstBlank(guardianRow);
    }
  }

  void _fillLivingWith(List<XmlElement> paragraphs, Client client) {
    final row = _firstWhere(
      paragraphs,
      (text) => text.contains('Magulang') && text.contains('Kapatid'),
    );
    if (row == null) return;
    final index = kLivingWithOptions.indexOf(client.livingWith?.trim() ?? '');
    // The living-with choices are underscore runs acting as tick boxes: the
    // selected one gets an X, the others keep their blank line.
    if (index >= 0) _fillBlank(row, index, 'X');
  }

  void _fillHobbies(List<XmlElement> paragraphs, Client client) {
    final hobbies = _firstWhere(
      paragraphs,
      (text) => text.contains('hilig na gawin'),
    );
    if (hobbies != null) _fillBlank(hobbies, 0, client.hobbies ?? '');
  }

  void _fillFour(XmlElement paragraph, List<String?> values) =>
      _fillBlanks(paragraph, values);

  /// Fills [values] into the paragraph's blanks, back to front: every filled
  /// blank removes its underscore run, so later (higher-index) blanks must be
  /// written before earlier ones to keep their positions stable. Returns
  /// whether at least one blank was written.
  bool _fillBlanks(XmlElement paragraph, List<String?> values) {
    var filled = false;
    for (var index = values.length - 1; index >= 0; index--) {
      if (_fillBlank(paragraph, index, values[index]?.trim() ?? '')) {
        filled = true;
      }
    }
    return filled;
  }

  /// Inserts a line break in [paragraph] just before its first underscore
  /// run, forcing that run onto its own line.
  void _breakBeforeFirstBlank(XmlElement paragraph) {
    final text = _read(paragraph);
    final match = RegExp(r'_{3,}').firstMatch(text.joined);
    if (match == null) return;
    for (final span in text.spans) {
      if (match.start < span.start || match.start >= span.end) continue;
      XmlNode? ancestor = span.node;
      XmlElement? run;
      while (ancestor != null) {
        if (ancestor is XmlElement &&
            ancestor.name.local == 'r' &&
            ancestor.name.namespaceUri == _wordNs) {
          run = ancestor;
          break;
        }
        ancestor = ancestor.parent;
      }
      final parent = run?.parent;
      if (run == null || parent == null) return;
      final fragment = XmlDocument.parse(
        '<w:r xmlns:w="$_wordNs"><w:br/></w:r>',
      );
      final breakRun = fragment.rootElement..remove();
      final children = parent.children;
      children.insert(children.indexOf(run), breakRun);
      return;
    }
  }

  // -------------------------------------------------------------- options --

  void _fillOptions(
    XmlDocument document,
    List<XmlElement> paragraphs,
    Client client,
  ) {
    // Income options live inside a floating text box (plus its VML fallback
    // copy), so match them by their wording wherever they appear.
    final incomeIndex = kFamilyIncomeOptions.indexOf(
      client.familyIncome?.trim() ?? '',
    );
    if (incomeIndex >= 0) {
      for (final paragraph in document.findAllElements(
        'p',
        namespaceUri: _wordNs,
      )) {
        final text = _textOf(paragraph);
        if (!text.contains('( )')) continue;
        if (_incomeOption(text) == incomeIndex) _tickParen(paragraph);
      }
    }

    // Parents options are plain top-level paragraphs in form order.
    final parentRows = paragraphs
        .where((paragraph) => _textOf(paragraph).trimLeft().startsWith('( )'))
        .toList();
    final parentIndex = kParentsStatusOptions.indexOf(
      client.parentsStatus?.trim() ?? '',
    );
    if (parentIndex < 0 || parentIndex >= parentRows.length) return;
    final row = parentRows[parentIndex];
    _tickParen(row);
    if (kParentsStatusOptions[parentIndex] == 'Deceased') {
      _fillBlank(row, 0, client.parentsStatusDetail ?? '');
    }
  }

  int? _incomeOption(String text) {
    if (text.contains('below 10,000')) return 0;
    if (text.contains('10,001')) return 1;
    if (text.contains('20,001')) return 2;
    if (text.contains('above')) return 3;
    return null;
  }

  // ------------------------------------------------------------- tick boxes --

  void _tickEducation(List<XmlElement> paragraphs, Client client) {
    final row = _firstWhere(
      paragraphs,
      (text) => text.contains('Elementary Graduate'),
    );
    if (row == null) return;
    final groups =
        row
            .findAllElements('AlternateContent', namespaceUri: _mcNs)
            .where(
              (content) => content
                  .findAllElements('wgp', namespaceUri: _wpgNs)
                  .isNotEmpty,
            )
            .toList()
          ..sort((a, b) => _anchorX(a).compareTo(_anchorX(b)));
    // Left column is TATAY (father), right column is NANAY (mother); within a
    // column the six boxes stack in the same order as kEducationOptions.
    final values = [client.fatherEducation, client.motherEducation];
    for (
      var column = 0;
      column < groups.length && column < values.length;
      column++
    ) {
      final value = values[column]?.trim() ?? '';
      if (value.isEmpty) continue;
      final rowIndex = kEducationOptions.indexOf(value);
      if (rowIndex < 0) continue;
      _tickGroupBox(groups[column], rowIndex);
    }
  }

  void _tickGroupBox(XmlElement content, int row) {
    final group = content
        .findAllElements('wgp', namespaceUri: _wpgNs)
        .firstOrNull;
    if (group != null) {
      final shapes = group.findElements('wsp', namespaceUri: _wpsNs).toList()
        ..sort((a, b) => _shapeY(a).compareTo(_shapeY(b)));
      if (row < shapes.length) _tickShape(shapes[row]);
    }
    final vmlGroup = content
        .findAllElements('group', namespaceUri: _vNs)
        .firstOrNull;
    if (vmlGroup != null) {
      final rects = vmlGroup.findElements('rect', namespaceUri: _vNs).toList()
        ..sort((a, b) => _vmlTop(a).compareTo(_vmlTop(b)));
      if (row < rects.length) _tickVmlRect(rects[row]);
    }
  }

  void _tickMemberTags(List<XmlElement> paragraphs, Client client) {
    final row = _firstWhere(paragraphs, (text) => text.contains('Kabilang sa'));
    if (row == null) return;
    final boxes = _checkboxAcs(row);
    const options = ['4Ps', 'PWD', 'IP', 'Left-handed'];
    final selected = client.memberTagList.map(_tagKey).toSet();
    for (
      var index = 0;
      index < options.length && index < boxes.length;
      index++
    ) {
      if (selected.contains(_tagKey(options[index]))) _tickAc(boxes[index]);
    }
  }

  void _tickSex(List<XmlElement> paragraphs, Client client) {
    final row = _firstWhere(paragraphs, (text) => text.contains('Kasarian'));
    if (row == null) return;
    final boxes = _checkboxAcs(row);
    const boxForSex = <String, int>{
      'Male': 0,
      'Female': 1,
      'Gay': 2,
      'Lesbian': 3,
      'Bisexual': 4,
      'Transgender': 5,
      'Other': 6,
    };
    final index = boxForSex[client.sex?.trim() ?? ''];
    if (index == null || index >= boxes.length) return;
    _tickAc(boxes[index]);
  }

  void _tickScreening(List<XmlElement> paragraphs, Client client) {
    final answers = <String?>[
      client.screenNoAppetite,
      client.screenCriesOften,
      client.screenAbuse,
      client.screenSelfBlame,
      client.screenSuicidalThoughts,
    ];
    final questions = paragraphs.where((paragraph) {
      final text = _textOf(paragraph).trimLeft();
      return text.startsWith('*') &&
          text.contains('Oo') &&
          text.contains('Hindi');
    }).toList();
    for (
      var index = 0;
      index < questions.length && index < answers.length;
      index++
    ) {
      final answer = answers[index]?.trim() ?? '';
      if (answer.isEmpty) continue;
      final boxes = _checkboxAcs(questions[index]);
      final box = answer == 'Yes'
          ? 0
          : answer == 'No'
          ? 1
          : -1;
      if (box >= 0 && box < boxes.length) _tickAc(boxes[box]);
    }
  }

  /// The tick-box shapes of [paragraph], ordered left to right. Groups and
  /// text boxes are skipped — they are handled by their own paths.
  List<XmlElement> _checkboxAcs(XmlElement paragraph) {
    final result = <XmlElement>[];
    for (final content in paragraph.findAllElements(
      'AlternateContent',
      namespaceUri: _mcNs,
    )) {
      if (content.findAllElements('wgp', namespaceUri: _wpgNs).isNotEmpty) {
        continue;
      }
      final shape = content
          .findAllElements('wsp', namespaceUri: _wpsNs)
          .firstOrNull;
      if (shape == null) continue;
      if (shape.findElements('txbx', namespaceUri: _wpsNs).isNotEmpty) {
        continue;
      }
      final extent = content
          .findAllElements('extent', namespaceUri: _wpNs)
          .firstOrNull;
      final width = int.tryParse(extent?.getAttribute('cx') ?? '') ?? 0;
      if (width <= 0 || width > 150000) continue;
      result.add(content);
    }
    return result..sort((a, b) => _anchorX(a).compareTo(_anchorX(b)));
  }

  void _tickAc(XmlElement content) {
    final shape = content
        .findAllElements('wsp', namespaceUri: _wpsNs)
        .firstOrNull;
    if (shape != null) _tickShape(shape);
    for (final rect in content.findAllElements('rect', namespaceUri: _vNs)) {
      final match = RegExp(r'width:([\d.]+)pt')
          .firstMatch(rect.getAttribute('style') ?? '');
      final width = double.tryParse(match?.group(1) ?? '') ?? 0;
      if (width > 0 && width <= 12) _tickVmlRect(rect);
    }
  }

  /// Puts an X inside a DrawingML tick box (the branch Word 2010+ renders).
  void _tickShape(XmlElement shape) {
    final existing = shape
        .findElements('txbx', namespaceUri: _wpsNs)
        .firstOrNull;
    if (existing != null) {
      final text = existing
          .findAllElements('t', namespaceUri: _wordNs)
          .map((element) => element.innerText)
          .join();
      if (text.trim().isNotEmpty) return;
      existing.remove();
    }
    final bodyPr = shape
        .findElements('bodyPr', namespaceUri: _wpsNs)
        .firstOrNull;
    if (bodyPr != null) {
      // A 7 pt box only fits the X if the text insets are removed and the
      // line is centred.
      _setAttr(bodyPr, 'lIns', '0');
      _setAttr(bodyPr, 'tIns', '0');
      _setAttr(bodyPr, 'rIns', '0');
      _setAttr(bodyPr, 'bIns', '0');
      _setAttr(bodyPr, 'anchor', 'ctr');
    }
    final fragment = XmlDocument.parse(
      '<wps:txbx xmlns:wps="$_wpsNs" xmlns:w="$_wordNs">'
      '<w:txbxContent><w:p><w:pPr><w:spacing w:after="0"/>'
      '<w:jc w:val="center"/></w:pPr>$_tickRun</w:p>'
      '</w:txbxContent></wps:txbx>',
    );
    final txbx = fragment.rootElement..remove();
    final children = shape.children;
    final index = bodyPr == null ? children.length : children.indexOf(bodyPr);
    children.insert(index, txbx);
  }

  /// Puts an X inside the VML fallback copy of a tick box.
  void _tickVmlRect(XmlElement rect) {
    final style = rect.getAttribute('style') ?? '';
    var updated = style.replaceAll('v-text-anchor:top', 'v-text-anchor:middle');
    if (updated == style && !updated.contains('v-text-anchor:')) {
      updated = updated.isEmpty
          ? 'v-text-anchor:middle'
          : '$updated;v-text-anchor:middle';
    }
    if (updated != style) _setAttr(rect, 'style', updated);
    if (rect.findElements('textbox', namespaceUri: _vNs).isNotEmpty) return;
    final fragment = XmlDocument.parse(
      '<v:textbox xmlns:v="$_vNs" xmlns:w="$_wordNs" inset="0,0,0,0">'
      '<w:txbxContent><w:p><w:pPr><w:spacing w:after="0"/>'
      '<w:jc w:val="center"/></w:pPr>$_tickRun</w:p>'
      '</w:txbxContent></v:textbox>',
    );
    final box = fragment.rootElement..remove();
    var index = 0;
    for (final child in rect.childElements) {
      final local = child.name.local;
      final ns = child.name.namespaceUri;
      if ((ns == _vNs &&
              (local == 'fill' || local == 'stroke' || local == 'shadow')) ||
          local == 'lock') {
        index++;
      }
    }
    rect.children.insert(index, box);
  }

  // -------------------------------------------------------------- plumbing --

  /// Replaces the [index]-th run of three or more underscores in [paragraph]
  /// with [value]; blank values leave the printed line untouched.
  ///
  /// The replacement is padded back to the run's width with underscores so
  /// the printed line keeps its original length: labels, absolutely
  /// positioned tick boxes and wrapped lines that flow after the blank stay
  /// exactly where the template put them, with the value written at the
  /// start of the line.
  bool _fillBlank(XmlElement paragraph, int index, String value) {
    if (value.isEmpty) return false;
    final text = _read(paragraph);
    final matches = RegExp(r'_{3,}').allMatches(text.joined).toList();
    if (index >= matches.length) return false;
    final match = matches[index];
    final runLength = match.end - match.start;
    final replacement = value.length < runLength
        ? '$value${'_' * (runLength - value.length)}'
        : value;
    return _splice(text, match.start, match.end, replacement);
  }

  /// Replaces the first `( )` in [paragraph] with `(X)`.
  bool _tickParen(XmlElement paragraph) {
    final text = _read(paragraph);
    final start = text.joined.indexOf('( )');
    if (start < 0) return false;
    return _splice(text, start, start + 3, '(X)');
  }

  /// Writes [value] over the `[start, end)` slice of the joined paragraph
  /// text, across however many text nodes the slice spans.
  bool _splice(_ParagraphText text, int start, int end, String value) {
    var inserted = false;
    for (final span in text.spans) {
      if (end <= span.start || start >= span.end) continue;
      final localStart = start > span.start ? start - span.start : 0;
      final localEnd = end < span.end
          ? end - span.start
          : span.node.value.length;
      span.node.value = span.node.value.replaceRange(
        localStart,
        localEnd,
        inserted ? '' : value,
      );
      inserted = true;
    }
    return inserted;
  }

  _ParagraphText _read(XmlElement paragraph) {
    final buffer = StringBuffer();
    final spans = <_TextSpan>[];
    void walk(XmlElement element) {
      for (final child in element.childElements) {
        final ns = child.name.namespaceUri;
        final local = child.name.local;
        // Shapes and floating text boxes never carry write-in text for the
        // paragraphs targeted here; skip them so their markup stays intact.
        if (ns == _mcNs && local == 'AlternateContent') continue;
        if (ns == _wordNs && (local == 'drawing' || local == 'pict')) continue;
        if (ns == _wordNs && local == 't') {
          final node = child.children.whereType<XmlText>().firstOrNull;
          final value = node?.value ?? '';
          final start = buffer.length;
          buffer.write(value);
          if (node != null) spans.add(_TextSpan(node, start, buffer.length));
        } else if (ns == _wordNs && local == 'tab') {
          // Tabs separate blanks (the name line uses them between fields) but
          // belong to no text node, so they act as splice boundaries.
          buffer.write('\t');
        } else if (child.childElements.isNotEmpty) {
          walk(child);
        }
      }
    }

    walk(paragraph);
    return _ParagraphText(buffer.toString(), spans);
  }

  String _textOf(XmlElement paragraph) => _read(paragraph).joined;

  XmlElement? _firstWhere(
    List<XmlElement> paragraphs,
    bool Function(String text) test,
  ) {
    for (final paragraph in paragraphs) {
      if (test(_textOf(paragraph))) return paragraph;
    }
    return null;
  }

  bool _isBlankLine(String text) =>
      text.isNotEmpty && RegExp(r'^[\s_]+$').hasMatch(text);

  ({String first, String middle, String last}) _resolvedNames(Client client) {
    var first = client.firstName?.trim() ?? '';
    var middle = client.middleName?.trim() ?? '';
    var last = client.lastName?.trim() ?? '';
    if (first.isEmpty || middle.isEmpty || last.isEmpty) {
      final parts = client.fullName
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        first = first.isEmpty ? parts.first : first;
        last = last.isEmpty && parts.length > 1 ? parts.last : last;
        middle = middle.isEmpty && parts.length > 2
            ? parts.sublist(1, parts.length - 1).join(' ')
            : middle;
      }
    }
    final suffix = client.suffix?.trim() ?? '';
    if (suffix.isNotEmpty && !last.contains(suffix)) {
      last = last.isEmpty ? suffix : '$last $suffix';
    }
    return (first: first, middle: middle, last: last);
  }

  int _ageOn(DateTime birth, DateTime moment) {
    var age = moment.year - birth.year;
    if (moment.month < birth.month ||
        (moment.month == birth.month && moment.day < birth.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  double _anchorX(XmlElement content) {
    final offset = content
        .findAllElements('posOffset', namespaceUri: _wpNs)
        .firstOrNull;
    return double.tryParse(offset?.innerText ?? '') ?? 0;
  }

  double _shapeY(XmlElement shape) {
    final offset = shape.findAllElements('off', namespaceUri: _aNs).firstOrNull;
    return double.tryParse(offset?.getAttribute('y') ?? '') ?? 0;
  }

  double _vmlTop(XmlElement rect) {
    final match = RegExp(r'(?:^|;)top:([\d.-]+)')
        .firstMatch(rect.getAttribute('style') ?? '');
    return double.tryParse(match?.group(1) ?? '') ?? 0;
  }

  String _tagKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  void _setAttr(XmlElement element, String name, String value) {
    element.attributes.removeWhere(
      (attribute) =>
          attribute.name.local == name && attribute.name.prefix == null,
    );
    element.setAttribute(name, value);
  }
}

class _ParagraphText {
  const _ParagraphText(this.joined, this.spans);

  final String joined;
  final List<_TextSpan> spans;
}

class _TextSpan {
  const _TextSpan(this.node, this.start, this.end);

  final XmlText node;
  final int start;
  final int end;
}
