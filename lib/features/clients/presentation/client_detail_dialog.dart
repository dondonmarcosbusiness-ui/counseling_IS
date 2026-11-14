import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/confirm_dialog.dart';
import 'package:counseling_is/core/widgets/status_chip.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/clients/presentation/client_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Read-only client details with edit / archive / restore actions.
/// Pops `true` when any change was made.
class ClientDetailDialog extends StatefulWidget {
  const ClientDetailDialog({super.key, required this.client});

  final Client client;

  @override
  State<ClientDetailDialog> createState() => _ClientDetailDialogState();
}

class _ClientDetailDialogState extends State<ClientDetailDialog> {
  late Client _current;
  bool _changed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _current = widget.client;
  }

  Future<void> _reload() async {
    final fresh = await context.read<ClientRepository>().getById(_current.id!);
    if (mounted) setState(() => _current = fresh);
  }

  Future<void> _edit() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ClientFormDialog(client: _current),
    );
    if (saved == true) {
      _changed = true;
      await _reload();
    }
  }

  Future<void> _toggleArchive() async {
    final archiving = !_current.isArchived;
    final confirmed = await showConfirmDialog(
      context,
      title: archiving ? 'Archive student' : 'Restore student',
      message: archiving
          ? 'Archived students stop appearing on new-record forms, but all '
                'existing history is kept. You can restore them at any time.'
          : 'This student will become active again and can be selected on '
                'new records.',
      confirmLabel: archiving ? 'Archive' : 'Restore',
      destructive: archiving,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final repo = context.read<ClientRepository>();
    try {
      if (archiving) {
        await repo.archive(_current.id!);
      } else {
        await repo.restore(_current.id!);
      }
      _changed = true;
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final client = _current;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: const Icon(Icons.person_outline, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  client.referenceNo,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          StatusChip(
            label: client.isArchived ? 'Archived' : 'Active',
            color: client.isArchived ? scheme.tertiary : scheme.primary,
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'STUDENT DETAILS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = constraints.maxWidth < 440
                      ? constraints.maxWidth
                      : (constraints.maxWidth - AppSpacing.sm) / 2;
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      SizedBox(
                        width: tileWidth,
                        child: _InfoTile(
                          label: 'Phone',
                          value: client.phone ?? 'Not provided',
                          icon: Icons.phone_outlined,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _InfoTile(
                          label: 'Email',
                          value: client.email ?? 'Not provided',
                          icon: Icons.mail_outline,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _InfoTile(
                          label: 'Date of birth',
                          value: client.dateOfBirth == null
                              ? 'Not provided'
                              : formatDate(client.dateOfBirth!),
                          icon: Icons.cake_outlined,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _InfoTile(
                          label: 'Registered',
                          value: formatDateTime(client.registeredAt),
                          icon: Icons.calendar_today_outlined,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (client.intakeNotes != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notes_outlined,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Intake notes',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(client.intakeNotes!),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _toggleArchive,
          style: client.isArchived
              ? null
              : OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error),
                ),
          icon: Icon(
            client.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
            size: 18,
          ),
          label: Text(client.isArchived ? 'Restore' : 'Archive'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _edit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
