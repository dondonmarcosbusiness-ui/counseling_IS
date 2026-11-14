import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/core/widgets/picker_field.dart';
import 'package:counseling_is/features/cases/data/case_repository.dart';
import 'package:counseling_is/features/cases/domain/case_record.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Create/edit dialog for a case record. Pops `true` when saved.
class CaseFormDialog extends StatefulWidget {
  const CaseFormDialog({super.key, this.caseRecord});

  final CaseRecord? caseRecord;

  @override
  State<CaseFormDialog> createState() => _CaseFormDialogState();
}

class _CaseFormDialogState extends State<CaseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _summary = TextEditingController();
  final _closureNotes = TextEditingController();
  List<Client> _clients = [];
  bool _clientsLoading = true;
  int? _clientId;
  DateTime _openedAt = DateTime.now();
  CaseStatus _status = CaseStatus.open;
  DateTime? _followUpDate;
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.caseRecord != null;

  @override
  void initState() {
    super.initState();
    final record = widget.caseRecord;
    if (record != null) {
      _clientId = record.clientId;
      _openedAt = record.openedAt;
      _status = record.status;
      _followUpDate = record.followUpDate;
      _summary.text = record.summary ?? '';
      _closureNotes.text = record.closureNotes ?? '';
    }
    _loadClients();
  }

  @override
  void dispose() {
    _summary.dispose();
    _closureNotes.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final repo = context.read<ClientRepository>();
      var list = await repo.search(
        const ClientQuery(status: ClientStatus.active),
      );
      final record = widget.caseRecord;
      if (record != null && !list.any((c) => c.id == record.clientId)) {
        try {
          list = [...list, await repo.getById(record.clientId)];
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _clientsLoading = false;
          _error = 'Could not load the student list.';
        });
      }
    }
  }

  Future<void> _pickOpenedAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _openedAt,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _openedAt = picked;
        if (_followUpDate != null && _followUpDate!.isBefore(picked)) {
          _followUpDate = null;
        }
      });
    }
  }

  Future<void> _pickFollowUp() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? _openedAt,
      firstDate: _openedAt,
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _followUpDate = picked);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _error = null;
      _saving = true;
    });

    final repo = context.read<CaseRepository>();
    try {
      final existing = widget.caseRecord;
      if (existing == null) {
        await repo.create(
          CreateCaseInput(
            clientId: _clientId!,
            openedAt: _openedAt,
            summary: _summary.text,
            followUpDate: _followUpDate,
          ),
        );
      } else {
        await repo.update(
          CaseRecord(
            id: existing.id,
            caseRef: existing.caseRef,
            clientId: _clientId!,
            openedAt: _openedAt,
            status: _status,
            summary: _summary.text,
            followUpDate: _followUpDate,
            closedAt: existing.closedAt,
            closureNotes: _status == CaseStatus.closed
                ? _closureNotes.text
                : null,
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
      title: Text(_isEdit ? 'Edit case' : 'New case'),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PickerField(
                        label: 'Opened date *',
                        icon: Icons.calendar_today_outlined,
                        displayValue: formatDate(_openedAt),
                        onTap: _saving ? () {} : _pickOpenedAt,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PickerField(
                        label: 'Follow-up date',
                        icon: Icons.event_repeat_outlined,
                        displayValue: _followUpDate == null
                            ? 'Not set'
                            : formatDate(_followUpDate!),
                        onClear: _followUpDate == null || _saving
                            ? null
                            : () => setState(() => _followUpDate = null),
                        onTap: _saving ? () {} : _pickFollowUp,
                      ),
                    ),
                  ],
                ),
                if (_isEdit) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppDropdownFormField<CaseStatus>(
                    initialValue: _status,
                    isExpanded: true,
                    menuMaxHeight: AppDropdownDefaults.menuMaxHeight,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      helperText: _status == CaseStatus.closed
                          ? 'Closing date is recorded automatically on save.'
                          : null,
                    ),
                    items: CaseStatus.values
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
                const SizedBox(height: AppSpacing.md),
                AppField(
                  label: 'Summary',
                  child: TextFormField(
                    controller: _summary,
                    enabled: !_saving,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add a brief case summary',
                    ),
                  ),
                ),
                if (_isEdit && _status == CaseStatus.closed) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppField(
                    label: 'Closure notes',
                    child: TextFormField(
                      controller: _closureNotes,
                      enabled: !_saving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Add closure notes',
                      ),
                    ),
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
          child: Text(_isEdit ? 'Save changes' : 'Create case'),
        ),
      ],
    );
  }
}
