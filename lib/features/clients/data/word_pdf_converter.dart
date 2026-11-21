import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:counseling_is/core/errors/app_exception.dart';

/// Converts .docx bytes to PDF with the locally installed Microsoft Word, so
/// the result keeps the document's exact layout, fonts and graphics.
///
/// Word is driven headlessly through a PowerShell COM script; the caller
/// decides how to fall back when Word is unavailable.
class WordPdfConverter {
  const WordPdfConverter();

  /// Whether Microsoft Word is registered on this machine.
  static Future<bool> isAvailable() async {
    if (!Platform.isWindows) return false;
    for (final key in _registryKeys) {
      final result = await Process.run('reg', ['query', key]);
      if (result.exitCode == 0) return true;
    }
    return false;
  }

  static const _registryKeys = [
    r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE',
    r'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE',
    r'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE',
  ];

  /// Writes [docxBytes] to a temporary file and returns the PDF Word makes
  /// from it. Throws [AppException] when Word is missing or fails.
  Future<Uint8List> convert(
    Uint8List docxBytes, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (!Platform.isWindows) {
      throw AppException(
        'Converting the sheet with Microsoft Word requires Windows.',
      );
    }
    final directory = await Directory.systemTemp.createTemp('sheet_docx_');
    try {
      final separator = Platform.pathSeparator;
      final docxPath = '$directory${separator}sheet.docx';
      final pdfPath = '$directory${separator}sheet.pdf';
      await File(docxPath).writeAsBytes(docxBytes, flush: true);
      await _exportWithWord(docxPath, pdfPath, timeout);
      final pdf = File(pdfPath);
      if (!await pdf.exists()) {
        throw AppException('Microsoft Word did not produce a PDF.');
      }
      final bytes = await pdf.readAsBytes();
      if (bytes.isEmpty) {
        throw AppException('Microsoft Word produced an empty PDF.');
      }
      return bytes;
    } finally {
      try {
        await directory.delete(recursive: true);
      } catch (_) {
        // A lingering temp folder must not fail the export.
      }
    }
  }

  Future<void> _exportWithWord(
    String docxPath,
    String pdfPath,
    Duration timeout,
  ) async {
    final script =
        '''
\$word = New-Object -ComObject Word.Application
\$word.Visible = \$false
\$word.DisplayAlerts = 0
\$word.Options.SaveNormalPrompt = \$false
try {
  \$doc = \$word.Documents.Open('${_escape(docxPath)}', \$false, \$true)
  \$doc.ExportAsFixedFormat('${_escape(pdfPath)}', 17)
  \$doc.Close(0)
} finally {
  \$word.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject(\$word) | Out-Null
}
''';
    final process = await Process.start('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-EncodedCommand',
      _encodeCommand(script),
    ]);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    final int exitCode;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      throw AppException('Microsoft Word took too long to convert the sheet.');
    }
    if (exitCode == 0) return;
    final details =
        ((await errors).trim().isEmpty
                ? (await output).trim()
                : (await errors).trim())
            .replaceAll(RegExp(r'\s+'), ' ');
    final hint = details.isEmpty
        ? ''
        : ': ${details.length > 220 ? details.substring(0, 220) : details}';
    throw AppException('Microsoft Word could not convert the sheet$hint');
  }

  String _escape(String path) => path.replaceAll("'", "''");

  /// PowerShell's `-EncodedCommand` expects Base64 of UTF-16LE.
  String _encodeCommand(String script) {
    final bytes = <int>[];
    for (final unit in script.codeUnits) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    }
    return base64.encode(bytes);
  }
}
