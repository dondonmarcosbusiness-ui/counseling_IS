import 'dart:io' show Platform, Process, ProcessStartMode, exit;

import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/widgets/confirm_dialog.dart';
import 'package:counseling_is/features/backup/data/backup_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Create consistent database backups and restore them by replacing the
/// live database file (the app restarts after a restore).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String? _lastCreatedPath;

  Future<void> _createBackup() async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'SQLite database', extensions: ['db']),
      ],
      suggestedName:
          'counseling-backup-${DateTime.now().toIso8601String().split('T').first}.db',
    );
    if (location == null || !mounted) return;

    setState(() {
      _busy = true;
    });
    try {
      final path = await context.read<BackupService>().createBackup(
        location.path,
      );
      if (!mounted) return;
      setState(() {
        _lastCreatedPath = path;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Backup saved to $path')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_messageOf(error))));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'SQLite database', extensions: ['db']),
      ],
    );
    if (file == null || !mounted) return;

    setState(() {
      _busy = true;
    });
    try {
      final service = context.read<BackupService>();
      final info = await service.validateBackup(file.path);
      if (!mounted) return;

      final confirmed = await showConfirmDialog(
        context,
        title: 'Restore this backup?',
        message:
            'The current database will be replaced with:\n\n'
            '${file.path}\n\n'
            'Backup contents: ${info.clients} students, '
            '${info.appointments} appointments, '
            '${info.sessions} sessions, ${info.cases} cases '
            '(schema version ${info.schemaVersion}).\n\n'
            'This cannot be undone. The application will restart '
            'when the restore finishes.',
        confirmLabel: 'Restore and restart',
        destructive: true,
      );
      if (!confirmed || !mounted) return;

      await service.restoreFrom(file.path);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore complete'),
          content: const Text(
            'The database has been restored. The application will '
            'now restart to load the restored data.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Restart now'),
            ),
          ],
        ),
      );
      await _restartApp();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_messageOf(error))));
    } finally {
      if (mounted && _busy) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _restartApp() async {
    try {
      await Process.start(
        Platform.resolvedExecutable,
        const <String>[],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } catch (_) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Restart required'),
            content: const Text(
              'The database has been restored. The application could not '
              'restart itself. Close and reopen it to load the restored '
              'data.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      exit(0);
    }
  }

  String _messageOf(Object error) {
    if (error is AppException) return error.message;
    return 'The operation failed.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup and Restore',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Protect your data with regular backups.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_busy) const LinearProgressIndicator(),
          if (_busy) const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.save_outlined,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Create a backup',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Writes a consistent copy of the entire database '
                              'to a file you choose. The application keeps '
                              'running while the backup is created. Backups '
                              'are not encrypted — store them securely.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: _busy ? null : _createBackup,
                                  icon: const Icon(Icons.save_alt),
                                  label: const Text('Create backup…'),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                if (_lastCreatedPath != null)
                                  Expanded(
                                    child: Text(
                                      'Last backup: $_lastCreatedPath',
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.settings_backup_restore,
                                  color: scheme.error,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Restore from a backup',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Replaces the current database with a backup '
                              'file. Anything saved after that backup was '
                              'created will be lost. The application '
                              'restarts when the restore is complete.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _restoreBackup,
                              icon: const Icon(Icons.folder_open_outlined),
                              label: const Text('Choose backup to restore…'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.error,
                                side: BorderSide(color: scheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Recommended: create a backup before major '
                                'changes and store copies outside this '
                                'computer.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
