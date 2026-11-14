import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/validation/validators.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/core/widgets/picker_field.dart';
import 'package:counseling_is/features/appointments/data/appointment_repository.dart';
import 'package:counseling_is/features/appointments/domain/appointment.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/sessions/data/session_repository.dart';
import 'package:counseling_is/features/sessions/domain/session_record.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Create/edit dialog for a counseling session. Pops `true` when saved.
class SessionFormDialog extends StatefulWidget {
  const SessionFormDialog({super.key, this.session});

  final SessionRecord? session;

  @override
  State<SessionFormDialog> createState() => _SessionFormDialogState();
}

class _SessionFormDialogState extends State<SessionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _followUpActions = TextEditingController();
  List<Client> _clients = [];
  bool _clientsLoading = true;
  List<Appointment> _appointments = [];
  int? _clientId;
  int? _appointmentId;
  DateTime _sessionDate = DateTime.now();
  DateTime? _nextRecommendedDate;
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.session != null;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    if (session != null) {
      _clientId = session.clientId;
      _appointmentId = session.appointmentId;
      _sessionDate = session.sessionDate;
      _nextRecommendedDate = session.nextRecommendedDate;
      _notes.text = session.notes;
      _followUpActions.text = session.followUpActions ?? '';
    }
    _loadClients();
  }

  @override
  void dispose() {
    _notes.dispose();
    _followUpActions.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final repo = context.read<ClientRepository>();
      var list = await repo.search(
        const ClientQuery(status: ClientStatus.active),
      );
      final session = widget.session;
      if (session != null && !list.any((c) => c.id == session.clientId)) {
        try {
          list = [...list, await repo.getById(session.clientId)];
        } on AppException {
          // Keep whatever we have if the linked client vanished.
        }
      }
      if (mounted) {
        setState(() {
          _clients = list;
          _clientsLoading = false;
        });
      }
      await _loadAppointments();
    } catch (_) {
      if (mounted) {
        setState(() {
          _clientsLoading = false;
          _error = 'Could not load the student list.';
        });
      }
    }
  }

  Future<void> _loadAppointments() async {
    final clientId = _clientId;
    if (clientId == null) {
      if (mounted) setState(() => _appointments = []);
      return;
    }
    try {
      final rows = await context.read<AppointmentRepository>().list(
        AppointmentQuery(
          timeFilter: AppointmentTimeFilter.all,
          clientId: clientId,
        ),
      );
      if (mounted) setState(() => _appointments = rows);
    } catch (_) {
      if (mounted) setState(() => _appointments = []);
    }
  }

  Future<void> _pickSessionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _sessionDate = picked;
        if (_nextRecommendedDate != null &&
            _nextRecommendedDate!.isBefore(picked)) {
          _nextRecommendedDate = null;
        }
      });
    }
  }

  Future<void> _pickNextRecommended() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextRecommendedDate ?? _sessionDate,
      firstDate: _sessionDate,
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _nextRecommendedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _error = null;
      _saving = true;
    });

    final repo = context.read<SessionRepository>();
    try {
      final existing = widget.session;
      if (existing == null) {
        await repo.create(
          CreateSessionInput(
            clientId: _clientId!,
            appointmentId: _appointmentId,
            sessionDate: _sessionDate,
            notes: _notes.text,
            followUpActions: _followUpActions.text,
            nextRecommendedDate: _nextRecommendedDate,
          ),
        );
      } else {
        await repo.update(
          SessionRecord(
            id: existing.id,
            clientId: _clientId!,
            appointmentId: _appointmentId,
            sessionDate: _sessionDate,
            notes: _notes.text,
            followUpActions: _followUpActions.text,
            nextRecommendedDate: _nextRecommendedDate,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
      return;
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Session details' : 'New session'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_clientsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text('Loading students…'),
                  )
                else
                  AppDropdownFormField<int>(
                    initialValue: _clientId,
                    isExpanded: true,
                    menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
                    decoration: const InputDecoration(labelText: 'Student *'),
                    items: _clients
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.isArchived
                                  ? '${c.fullName} (archived)'
                                  : c.fullName,
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Select a student' : null,
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _clientId = value;
                              _appointmentId = null;
                            });
                            _loadAppointments();
                          },
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PickerField(
                        label: 'Session date *',
                        icon: Icons.calendar_today_outlined,
                        displayValue: formatDate(_sessionDate),
                        onTap: _saving ? () {} : _pickSessionDate,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PickerField(
                        label: 'Next recommended date',
                        icon: Icons.event_repeat_outlined,
                        displayValue: _nextRecommendedDate == null
                            ? 'Not set'
                            : formatDate(_nextRecommendedDate!),
                        onClear: _nextRecommendedDate == null || _saving
                            ? null
                            : () => setState(() => _nextRecommendedDate = null),
                        onTap: _saving ? () {} : _pickNextRecommended,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppDropdownFormField<int?>(
                  initialValue: _appointmentId,
                  isExpanded: true,
                  menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
                  decoration: const InputDecoration(
                    labelText: 'Linked appointment',
                    helperText:
                        'Optional — link when this session came '
                        'from a scheduled appointment.',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No linked appointment'),
                    ),
                    for (final a in _appointments)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${formatDateTime(a.startsAt)} · '
                          '${a.status.label}',
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _appointmentId = value),
                ),
                const SizedBox(height: AppSpacing.md),
                AppField(
                  label: 'Session notes *',
                  child: TextFormField(
                    controller: _notes,
                    enabled: !_saving,
                    maxLines: 5,
                    minLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Enter session notes',
                      helperText:
                          'Confidential — shown only inside '
                          'Counseling Sessions, never on lists or '
                          'the dashboard.',
                    ),
                    validator: (value) => requiredField(value, 'Session notes'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppField(
                  label: 'Follow-up actions',
                  child: TextFormField(
                    controller: _followUpActions,
                    enabled: !_saving,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add follow-up actions',
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ErrorBanner(message: _error!),
                ],
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
          onPressed: (_saving || _clientsLoading) ? null : _save,
          child: Text(_isEdit ? 'Save changes' : 'Create session'),
        ),
      ],
    );
  }
}
