import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/core/widgets/list_states.dart';
import 'package:counseling_is/core/widgets/picker_field.dart';
import 'package:counseling_is/features/cases/data/case_repository.dart';
import 'package:counseling_is/features/cases/domain/case_record.dart';
import 'package:counseling_is/features/cases/domain/case_timeline_event.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CaseTimelineDialog extends StatefulWidget {
  const CaseTimelineDialog({
    super.key,
    required this.caseRecord,
    this.showDisciplinaryOnly = false,
  });

  final CaseRecord caseRecord;
  final bool showDisciplinaryOnly;

  @override
  State<CaseTimelineDialog> createState() => _CaseTimelineDialogState();
}

class _CaseTimelineDialogState extends State<CaseTimelineDialog> {
  late Future<List<CaseTimelineEvent>> _future;
  late bool _disciplinaryOnly;

  @override
  void initState() {
    super.initState();
    _disciplinaryOnly = widget.showDisciplinaryOnly;
    _future = _load();
  }

  Future<List<CaseTimelineEvent>> _load() =>
      context.read<CaseRepository>().timeline(widget.caseRecord.id!);

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _addEvent() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CaseTimelineEntryDialog(
        caseId: widget.caseRecord.id!,
        disciplinaryOnly: _disciplinaryOnly,
      ),
    );
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Case history — ${widget.caseRecord.caseRef}'),
      content: SizedBox(
        width: 650,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('Case history'),
                  selected: !_disciplinaryOnly,
                  onSelected: (_) {
                    if (_disciplinaryOnly) {
                      setState(() => _disciplinaryOnly = false);
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Disciplinary timeline'),
                  selected: _disciplinaryOnly,
                  onSelected: (_) {
                    if (!_disciplinaryOnly) {
                      setState(() => _disciplinaryOnly = true);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: FutureBuilder<List<CaseTimelineEvent>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return LoadErrorState(onRetry: _refresh);
                  }
                  final events = snapshot.data!
                      .where(
                        (event) =>
                            !_disciplinaryOnly ||
                            event.eventType == 'disciplinary_action',
                      )
                      .toList();
                  if (events.isEmpty) {
                    return EmptyListState(
                      icon: _disciplinaryOnly
                          ? Icons.gavel_outlined
                          : Icons.timeline_outlined,
                      title: _disciplinaryOnly
                          ? 'No disciplinary events yet'
                          : 'No history yet',
                      message: _disciplinaryOnly
                          ? 'Disciplinary events recorded for this case will '
                                'appear here.'
                          : 'Case updates and timeline entries will appear '
                                'here.',
                    );
                  }
                  return ListView.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return ListTile(
                        leading: Icon(_timelineIcon(event.eventType), size: 18),
                        title: Text(event.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_timelineEventLabel(event.eventType)} · '
                              '${formatDateTime(event.occurredAt)} · '
                              '${event.adminName ?? 'Former account'}',
                            ),
                            if (event.description != null)
                              Text(event.description!),
                          ],
                        ),
                        isThreeLine: event.description != null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _addEvent,
          icon: Icon(_disciplinaryOnly ? Icons.gavel_outlined : Icons.add),
          label: Text(
            _disciplinaryOnly ? 'Add disciplinary event' : 'Add event',
          ),
        ),
      ],
    );
  }
}

class _CaseTimelineEntryDialog extends StatefulWidget {
  const _CaseTimelineEntryDialog({
    required this.caseId,
    required this.disciplinaryOnly,
  });

  final int caseId;
  final bool disciplinaryOnly;

  @override
  State<_CaseTimelineEntryDialog> createState() =>
      _CaseTimelineEntryDialogState();
}

class _CaseTimelineEntryDialogState extends State<_CaseTimelineEntryDialog> {
  static const _types = [
    'Counseling',
    'Disciplinary action',
    'Intervention',
    'Referral',
    'Follow-up',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late String _type;
  DateTime _date = DateTime.now();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.disciplinaryOnly ? _types[1] : _types.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<CaseRepository>().recordTimelineEvent(
        caseId: widget.caseId,
        occurredAt: _date,
        eventType: _type.toLowerCase().replaceAll(' ', '_'),
        title: _title.text,
        description: _description.text,
      );
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The timeline event could not be saved.';
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.disciplinaryOnly
            ? 'Add disciplinary timeline event'
            : 'Add case timeline event',
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                PickerField(
                  label: 'Event date',
                  icon: Icons.calendar_today_outlined,
                  displayValue: formatDate(_date),
                  onTap: _saving ? () {} : _pickDate,
                ),
                const SizedBox(height: AppSpacing.md),
                if (!widget.disciplinaryOnly) ...[
                  AppDropdownFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Event type'),
                    items: [
                      for (final type in _types)
                        DropdownMenuItem(value: type, child: Text(type)),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _type = value);
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: widget.disciplinaryOnly
                        ? 'Disciplinary action *'
                        : 'Title *',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: widget.disciplinaryOnly
                        ? 'Details / outcome (avoid unnecessary sensitive detail)'
                        : 'Notes (avoid unnecessary sensitive detail)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save event'),
        ),
      ],
    );
  }
}

String _timelineEventLabel(String eventType) {
  final label = eventType.replaceAll('_', ' ').trim();
  if (label.isEmpty) return 'Other';
  return '${label[0].toUpperCase()}${label.substring(1)}';
}

IconData _timelineIcon(String eventType) => switch (eventType) {
  'disciplinary_action' => Icons.gavel_outlined,
  'case_opened' => Icons.folder_open_outlined,
  'case_updated' => Icons.edit_note_outlined,
  'counseling' => Icons.chat_bubble_outline,
  'intervention' => Icons.task_alt_outlined,
  'referral' => Icons.forward_to_inbox_outlined,
  'follow_up' => Icons.event_available_outlined,
  'follow_up_completed' => Icons.check_circle_outline,
  _ => Icons.circle_outlined,
};
