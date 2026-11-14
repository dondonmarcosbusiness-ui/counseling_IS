import 'dart:io';

import 'package:counseling_is/core/errors/app_exception.dart';

class WordPrintPreview {
  const WordPrintPreview();

  static const _registryKeys = [
    r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE',
    r'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE',
    r'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE',
  ];

  Future<void> open(String documentPath) async {
    if (Platform.isMacOS) {
      await _openWithDefaultApp(documentPath);
      return;
    }

    if (!Platform.isWindows) {
      throw AppException(
        'Microsoft Word print preview is only available on Windows.',
      );
    }

    final wordPath = await _findWordPath();
    if (wordPath == null) {
      throw AppException(
        'Microsoft Word was not found. Install Word to preview this form.',
      );
    }

    await Process.start(wordPath, [
      '/n',
      '/mFilePrintPreview',
      documentPath,
    ], mode: ProcessStartMode.detached);
  }

  Future<void> _openWithDefaultApp(String documentPath) async {
    try {
      await Process.start(
        'open',
        [documentPath],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {
      throw AppException(
        'The form was exported, but it could not be opened automatically. '
        'Open the saved file from its folder to preview it.',
      );
    }
  }

  Future<String?> _findWordPath() async {
    for (final key in _registryKeys) {
      final result = await Process.run('reg.exe', ['query', key, '/ve']);
      if (result.exitCode != 0) continue;

      final output = '${result.stdout}\n${result.stderr}';
      final match = RegExp(
        r'REG_SZ\s+(.+?)\s*$',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(output);
      final path = match?.group(1)?.trim();
      if (path != null && path.isNotEmpty && File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }
}
