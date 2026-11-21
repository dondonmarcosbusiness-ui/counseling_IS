import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/confirm_dialog.dart';
import 'package:counseling_is/core/widgets/status_chip.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/clients/presentation/client_form_dialog.dart';
import 'package:counseling_is/features/clients/presentation/student_sheet_preview_dialog.dart';
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

  Widget _sectionLabel(BuildContext context, String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  List<({String label, String value, IconData icon})> _studentTiles(
    Client client,
  ) {
    return [
      (
        label: 'Phone',
        value: client.phone ?? 'Not provided',
        icon: Icons.phone_outlined,
      ),
      (
        label: 'Email',
        value: client.email ?? 'Not provided',
        icon: Icons.mail_outline,
      ),
      (
        label: 'Date of birth',
        value: client.dateOfBirth == null
            ? 'Not provided'
            : formatDate(client.dateOfBirth!),
        icon: Icons.cake_outlined,
      ),
      (
        label: 'Age',
        value: client.dateOfBirth == null
            ? 'Not provided'
            : '${_ageOf(client.dateOfBirth!)}',
        icon: Icons.hourglass_bottom_outlined,
      ),
      (
        label: 'Registered',
        value: formatDateTime(client.registeredAt),
        icon: Icons.calendar_today_outlined,
      ),
      (
        label: 'Grade and section',
        value: client.gradeSection ?? 'Not provided',
        icon: Icons.school_outlined,
      ),
      (
        label: 'Learner ref. no.',
        value: client.learnerNo ?? 'Not provided',
        icon: Icons.badge_outlined,
      ),
      (
        label: 'Sex',
        value: client.sex ?? 'Not provided',
        icon: Icons.person_outline,
      ),
      (
        label: 'Religion',
        value: client.religion ?? 'Not provided',
        icon: Icons.church_outlined,
      ),
      (
        label: 'Permanent address',
        value: client.address ?? 'Not provided',
        icon: Icons.home_outlined,
      ),
      (
        label: 'Kabilang sa',
        value: client.memberTags ?? 'None recorded',
        icon: Icons.groups_outlined,
      ),
      (
        label: 'Living with',
        value: client.livingWith ?? 'Not provided',
        icon: Icons.family_restroom_outlined,
      ),
      (
        label: 'Monthly family income',
        value: client.familyIncome ?? 'Not provided',
        icon: Icons.payments_outlined,
      ),
      (
        label: "Parents' relationship",
        value: client.parentsStatus == null
            ? 'Not provided'
            : client.parentsStatusDetail == null
            ? client.parentsStatus!
            : '${client.parentsStatus} (${client.parentsStatusDetail})',
        icon: Icons.favorite_outline,
      ),
      (
        label: 'Hobbies / interests',
        value: client.hobbies ?? 'Not provided',
        icon: Icons.sports_baseball_outlined,
      ),
    ];
  }

  int _ageOf(DateTime dateOfBirth) {
    final today = DateTime.now();
    var age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  bool _hasEmergencyContact(Client client) =>
      client.emergencyName != null ||
      client.emergencyContactNo != null ||
      client.emergencyAddress != null ||
      client.emergencyJob != null ||
      client.emergencyRelationship != null;

  bool _hasFamily(Client client) =>
      client.fatherName != null ||
      client.motherName != null ||
      client.guardianName != null;

  List<({String label, String value})> _emergencyTiles(Client client) => [
    (label: 'Name', value: client.emergencyName ?? 'Not provided'),
    (
      label: 'Contact number',
      value: client.emergencyContactNo ?? 'Not provided',
    ),
    (
      label: 'Relationship',
      value: client.emergencyRelationship ?? 'Not provided',
    ),
    (label: 'Occupation', value: client.emergencyJob ?? 'Not provided'),
    (label: 'Address', value: client.emergencyAddress ?? 'Not provided'),
  ];

  List<({String label, String value})> _memberDetails(
    String? name,
    String? age,
    String? job,
    String? workplace,
    String? education, {
    String? relationship,
  }) {
    final details = <({String label, String value})>[
      (label: 'Name', value: name ?? 'Not provided'),
    ];
    if (age != null) details.add((label: 'Age', value: age));
    if (relationship != null) {
      details.add((label: 'Relationship', value: relationship));
    }
    if (job != null) details.add((label: 'Occupation', value: job));
    if (workplace != null) {
      details.add((label: 'Place of work', value: workplace));
    }
    if (education != null) {
      details.add((label: 'Education attained', value: education));
    }
    return details;
  }

  List<({String label, String question, String answer})> _screeningRows(
    Client client,
  ) => [
    if (client.screenNoAppetite != null)
      (
        label: 'Appetite',
        question: 'No appetite for food',
        answer: client.screenNoAppetite!,
      ),
    if (client.screenCriesOften != null)
      (
        label: 'Mood',
        question: 'Often cries',
        answer: client.screenCriesOften!,
      ),
    if (client.screenAbuse != null)
      (
        label: 'Safety',
        question: 'Experiences abuse or harm (sexual / physical)',
        answer: client.screenAbuse!,
      ),
    if (client.screenSelfBlame != null)
      (
        label: 'Self-blame',
        question: 'Often blames self for what happens',
        answer: client.screenSelfBlame!,
      ),
    if (client.screenSuicidalThoughts != null)
      (
        label: 'Risk',
        question: 'Wants to end life',
        answer: client.screenSuicidalThoughts!,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final client = _current;
    final screeningRows = _screeningRows(client);
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
                      for (final tile in _studentTiles(client))
                        SizedBox(
                          width: tileWidth,
                          child: _InfoTile(
                            label: tile.label,
                            value: tile.value,
                            icon: tile.icon,
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (_hasEmergencyContact(client)) ...[
                _sectionLabel(context, 'PERSON TO NOTIFY IN CASE OF EMERGENCY'),
                _labelValueWrap(_emergencyTiles(client)),
              ],
              if (_hasFamily(client)) ...[
                _sectionLabel(context, 'FAMILY'),
                for (final member in [
                  (
                    title: 'Father',
                    details: _memberDetails(
                      client.fatherName,
                      client.fatherAge,
                      client.fatherJob,
                      client.fatherWorkplace,
                      client.fatherEducation,
                    ),
                  ),
                  (
                    title: 'Mother',
                    details: _memberDetails(
                      client.motherName,
                      client.motherAge,
                      client.motherJob,
                      client.motherWorkplace,
                      client.motherEducation,
                    ),
                  ),
                  (
                    title: 'Guardian',
                    details: _memberDetails(
                      client.guardianName,
                      client.guardianAge,
                      client.guardianJob,
                      client.guardianWorkplace,
                      null,
                      relationship: client.guardianRelationship,
                    ),
                  ),
                ])
                  if (member.details.length > 1)
                    _memberCard(member.title, member.details),
              ],
              if (screeningRows.isNotEmpty) ...[
                _sectionLabel(context, 'CONFIDENTIAL WELL-BEING CHECK'),
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
                      for (final row in screeningRows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  row.question,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              StatusChip(
                                label: row.answer,
                                color: row.answer == 'Yes'
                                    ? scheme.error
                                    : scheme.primary,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
          onPressed: _busy
              ? null
              : () => StudentSheetPreviewDialog.show(context, client: _current),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Preview'),
        ),
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

  Widget _labelValueWrap(List<({String label, String value})> entries) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in entries)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entry.value,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _memberCard(
    String title,
    List<({String label, String value})> details,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final detail in details)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      detail.label,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      detail.value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
