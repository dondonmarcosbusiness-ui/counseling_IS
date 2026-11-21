import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/core/widgets/picker_field.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:counseling_is/features/interventions/data/intervention_repository.dart';
import 'package:counseling_is/features/interventions/domain/intervention.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InterventionFormDialog extends StatefulWidget {
  const InterventionFormDialog({super.key, this.intervention});

  final Intervention? intervention;

  @override
  State<InterventionFormDialog> createState() => _InterventionFormDialogState();
}

class _InterventionFormDialogState extends State<InterventionFormDialog> {
  static const _types = [
    'Individual counseling',
    'Group counseling',
    'Group dynamics',
    'Parent conference',
    'Referral',
    'Behavior support',
    'Academic support',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _goal = TextEditingController();
  final _outcome = TextEditingController();
  final _customType = TextEditingController();
  final _participantSearch = TextEditingController();
  List<Client> _clients = [];
  final Set<int> _selectedClientIds = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _type = _types.first;
  InterventionStatus _status = InterventionStatus.planned;
  DateTime _startDate = DateTime.now();
  DateTime? _targetDate;

  bool get _isEdit => widget.intervention != null;
  static const _groupTypes = {'Group counseling', 'Group dynamics'};

  bool get _isGroup => _groupTypes.contains(_type);
  bool get _isOther => _type == 'Other';

  @override
  void initState() {
    super.initState();
    final intervention = widget.intervention;
    if (intervention != null) {
      _selectedClientIds.addAll(
        intervention.participantIds.isEmpty
            ? [intervention.clientId]
            : intervention.participantIds,
      );
      _title.text = intervention.title;
      _type = intervention.type;
      _customType.text = intervention.customType ?? '';
      _description.text = intervention.description ?? '';
      _goal.text = intervention.goal ?? '';
      _outcome.text = intervention.outcome ?? '';
      _status = intervention.status;
      _startDate = intervention.startDate;
      _targetDate = intervention.targetDate;
    }
    _loadClients();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _goal.dispose();
    _outcome.dispose();
    _customType.dispose();
    _participantSearch.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final repo = context.read<ClientRepository>();
      var clients = await repo.search(
        const ClientQuery(status: ClientStatus.active),
      );
      final record = widget.intervention;
      if (record != null) {
        for (final id in _selectedClientIds) {
          if (!clients.any((client) => client.id == id)) {
            clients = [...clients, await repo.getById(id)];
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _loading = false;
      });
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load students for the intervention.';
        });
      }
    }
  }

  void _selectClient(int? value) {
    setState(() {
      _selectedClientIds
        ..clear()
        ..addAll([?value]);
      _error = null;
    });
  }

  Future<void> _selectGroupClients(FormFieldState<List<int>> field) async {
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (context) {
        final draft = Set<int>.of(_selectedClientIds);
        var query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final normalizedQuery = query.trim().toLowerCase();
            final filteredClients = _clients.where((client) {
              return client.fullName.toLowerCase().contains(normalizedQuery) ||
                  client.referenceNo.toLowerCase().contains(normalizedQuery);
            });
            return AlertDialog(
              title: const Text('Select learners'),
              content: SizedBox(
                width: 420,
                height: 360,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search learners',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setDialogState(() => query = value),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: filteredClients.isEmpty
                          ? const Center(child: Text('No matching learners.'))
                          : ListView(
                              children: [
                                for (final client in filteredClients)
                                  CheckboxListTile(
                                    value: draft.contains(client.id),
                                    title: Text(
                                      client.isArchived
                                          ? '${client.fullName} (archived)'
                                          : client.fullName,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    onChanged: (checked) {
                                      setDialogState(() {
                                        if (checked == true) {
                                          draft.add(client.id!);
                                        } else {
                                          draft.remove(client.id);
                                        }
                                      });
                                    },
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, draft),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedClientIds
        ..clear()
        ..addAll(selected);
      _error = null;
    });
    field.didChange(_selectedClientIds.toList());
  }

  Widget _learnerField() {
    if (!_isGroup) {
      return AppDropdownFormField<int>(
        initialValue: _selectedClientIds.isEmpty
            ? null
            : _selectedClientIds.first,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Learner *'),
        items: [
          for (final client in _clients)
            DropdownMenuItem(
              value: client.id,
              child: Text(
                client.isArchived
                    ? '${client.fullName} (archived)'
                    : client.fullName,
              ),
            ),
        ],
        validator: (value) => value == null ? 'Select a learner' : null,
        onChanged: _saving ? null : _selectClient,
      );
    }

    return FormField<List<int>>(
      key: const ValueKey('group-learners'),
      initialValue: _selectedClientIds.toList(),
      validator: (value) =>
          value == null || value.isEmpty ? 'Select at least one learner' : null,
      builder: (field) {
        final selectedNames = _clients
            .where((client) => _selectedClientIds.contains(client.id))
            .map((client) => client.fullName)
            .toList();
        return AppField(
          label: 'Learners *',
          labelTrailing: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            onPressed: _saving ? null : () => _selectGroupClients(field),
            icon: const Icon(Icons.people_outline),
            label: const Text('Select learners'),
          ),
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              constraints: const BoxConstraints(minHeight: 50),
              errorText: field.errorText,
            ),
            isEmpty: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedNames.isEmpty)
                  const Text('No learners selected')
                else
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final name in selectedNames)
                        Chip(label: Text(name)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDate({required bool target}) async {
    final initial = target ? (_targetDate ?? _startDate) : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (target) {
        _targetDate = picked;
      } else {
        _startDate = picked;
        if (_targetDate != null && _targetDate!.isBefore(picked)) {
          _targetDate = null;
        }
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final participantIds = _selectedClientIds.toList();
    if (participantIds.isEmpty) return;
    final clientId = participantIds.first;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = context.read<InterventionRepository>();
    try {
      final existing = widget.intervention;
      if (existing == null) {
        await repo.create(
          CreateInterventionInput(
            clientId: clientId,
            participantIds: participantIds,
            title: _title.text,
            type: _type,
            customType: _isOther ? _customType.text : null,
            description: _description.text,
            goal: _goal.text,
            startDate: _startDate,
            targetDate: _targetDate,
          ),
        );
      } else {
        await repo.update(
          Intervention(
            id: existing.id,
            clientId: clientId,
            caseId: existing.caseId,
            participantIds: participantIds,
            title: _title.text.trim(),
            type: _type,
            customType: _isOther ? _customType.text : null,
            description: _description.text,
            goal: _goal.text,
            status: _status,
            startDate: _startDate,
            targetDate: _targetDate,
            outcome: _outcome.text,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
          ),
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit intervention' : 'New intervention'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_loading)
                  const LinearProgressIndicator()
                else
                  _learnerField(),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Intervention title *',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppDropdownFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type *'),
                  items: [
                    for (final type in _types)
                      DropdownMenuItem(value: type, child: Text(type)),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              if (_isGroup &&
                                  !_groupTypes.contains(value) &&
                                  _selectedClientIds.length > 1) {
                                final primary = _selectedClientIds.first;
                                _selectedClientIds
                                  ..clear()
                                  ..add(primary);
                              }
                              _type = value;
                            });
                          }
                        },
                ),
                if (_isOther) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _customType,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Specify intervention type *',
                    ),
                    validator: (value) =>
                        _isOther && (value == null || value.trim().isEmpty)
                        ? 'Enter the intervention type'
                        : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description / activities',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _goal,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Goal'),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: PickerField(
                        label: 'Start date *',
                        icon: Icons.calendar_today_outlined,
                        displayValue: formatDate(_startDate),
                        onTap: _saving ? () {} : () => _pickDate(target: false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PickerField(
                        label: 'Target date',
                        icon: Icons.event_outlined,
                        displayValue: _targetDate == null
                            ? 'Not set'
                            : formatDate(_targetDate!),
                        onClear: _targetDate == null || _saving
                            ? null
                            : () => setState(() => _targetDate = null),
                        onTap: _saving ? () {} : () => _pickDate(target: true),
                      ),
                    ),
                  ],
                ),
                if (_isEdit) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppDropdownFormField<InterventionStatus>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final status in InterventionStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _status = value);
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _outcome,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Outcome / progress notes',
                    ),
                  ),
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
          onPressed: _saving || _loading ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
