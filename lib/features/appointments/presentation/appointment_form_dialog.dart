import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/core/widgets/picker_field.dart';
import 'package:counseling_is/features/appointments/data/appointment_repository.dart';
import 'package:counseling_is/features/appointments/domain/appointment.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const List<int> _baseDurations = [15, 30, 45, 60, 90, 120];

/// Create/edit dialog for an appointment. Pops `true` when saved.
class AppointmentFormDialog extends StatefulWidget {
  const AppointmentFormDialog({super.key, this.appointment});

  final Appointment? appointment;

  @override
  State<AppointmentFormDialog> createState() => _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends State<AppointmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _purpose = TextEditingController();
  final _notes = TextEditingController();
  List<Client> _clients = [];
  bool _clientsLoading = true;
  int? _clientId;
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _durationMinutes = 60;
  AppointmentStatus _status = AppointmentStatus.scheduled;
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    final appointment = widget.appointment;
    if (appointment != null) {
      _clientId = appointment.clientId;
      _date = DateTime(
        appointment.startsAt.year,
        appointment.startsAt.month,
        appointment.startsAt.day,
      );
      _time = TimeOfDay(
        hour: appointment.startsAt.hour,
        minute: appointment.startsAt.minute,
      );
      _durationMinutes = appointment.duration.inMinutes;
      _purpose.text = appointment.purpose ?? '';
      _notes.text = appointment.notes ?? '';
      _status = appointment.status;
    }
    _loadClients();
  }

  @override
  void dispose() {
    _purpose.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final repo = context.read<ClientRepository>();
      var list = await repo.search(
        const ClientQuery(status: ClientStatus.active),
      );
      final appointment = widget.appointment;
      if (appointment != null &&
          !list.any((c) => c.id == appointment.clientId)) {
        try {
          list = [...list, await repo.getById(appointment.clientId)];
        } on AppException {
          // Client record vanished; keep the rest of the list.
        }
      }
      if (mounted) {
        setState(() {
          _clients = list;
          _clientsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _clientsLoading = false;
          _error = 'Could not load the student list.';
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  List<int> get _durationOptions {
    final options = {..._baseDurations, _durationMinutes}.toList()..sort();
    return options;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _error = null;
      _saving = true;
    });

    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final end = start.add(Duration(minutes: _durationMinutes));
    final repo = context.read<AppointmentRepository>();
    try {
      final existing = widget.appointment;
      if (existing == null) {
        await repo.create(
          CreateAppointmentInput(
            clientId: _clientId!,
            startsAt: start,
            endsAt: end,
            purpose: _purpose.text,
            notes: _notes.text,
          ),
        );
      } else {
        await repo.update(
          Appointment(
            id: existing.id,
            clientId: _clientId!,
            startsAt: start,
            endsAt: end,
            purpose: _purpose.text,
            status: _status,
            notes: _notes.text,
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
      title: Text(_isEdit ? 'Edit appointment' : 'New appointment'),
      content: SizedBox(
        width: 540,
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
                        : (value) => setState(() => _clientId = value),
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: PickerField(
                        label: 'Date *',
                        icon: Icons.calendar_today_outlined,
                        displayValue: formatDate(_date),
                        onTap: _saving ? () {} : _pickDate,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PickerField(
                        label: 'Start time *',
                        icon: Icons.schedule_outlined,
                        displayValue: _formatTime(_time),
                        onTap: _saving ? () {} : _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppDropdownFormField<int>(
                  initialValue: _durationMinutes,
                  isExpanded: true,
                  menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
                  decoration: const InputDecoration(labelText: 'Duration *'),
                  items: _durationOptions
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text('$m minutes'),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _durationMinutes = value ?? 60),
                ),
                const SizedBox(height: AppSpacing.md),
                AppField(
                  label: 'Purpose',
                  child: TextFormField(
                    controller: _purpose,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      hintText: 'Enter appointment purpose',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppField(
                  label: 'Notes',
                  child: TextFormField(
                    controller: _notes,
                    enabled: !_saving,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add appointment notes',
                    ),
                  ),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppDropdownFormField<AppointmentStatus>(
                    initialValue: _status,
                    isExpanded: true,
                    menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: AppointmentStatus.values
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.label)),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _status = value ?? _status),
                  ),
                ],
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
          child: Text(_isEdit ? 'Save changes' : 'Create appointment'),
        ),
      ],
    );
  }

  String _formatTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
