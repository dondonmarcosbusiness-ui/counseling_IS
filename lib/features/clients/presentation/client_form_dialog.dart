import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/validation/validators.dart';
import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/core/widgets/picker_field.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Create/edit dialog for a client. Pops `true` when the record was saved.
class ClientFormDialog extends StatefulWidget {
  const ClientFormDialog({super.key, this.client});

  final Client? client;

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _middleName;
  late final TextEditingController _lastName;
  late final TextEditingController _suffix;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _intakeNotes;
  DateTime? _dateOfBirth;
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.client != null;

  Widget _sectionHeading(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _fieldRow(List<Widget> fields, {List<int>? flexes}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                if (index > 0) const SizedBox(height: AppSpacing.md),
                fields[index],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              if (index > 0) const SizedBox(width: AppSpacing.md),
              Expanded(flex: flexes?[index] ?? 1, child: fields[index]),
            ],
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _firstName = TextEditingController(
      text: client?.firstName ?? client?.fullName ?? '',
    );
    _middleName = TextEditingController(text: client?.middleName ?? '');
    _lastName = TextEditingController(text: client?.lastName ?? '');
    _suffix = TextEditingController(text: client?.suffix ?? '');
    _phone = TextEditingController(text: client?.phone ?? '');
    _email = TextEditingController(text: client?.email ?? '');
    _intakeNotes = TextEditingController(text: client?.intakeNotes ?? '');
    _dateOfBirth = client?.dateOfBirth;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _suffix.dispose();
    _phone.dispose();
    _email.dispose();
    _intakeNotes.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) =>
          Padding(padding: const EdgeInsets.all(AppSpacing.md), child: child!),
    );
    if (picked != null && mounted) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _error = null;
      _saving = true;
    });

    final repo = context.read<ClientRepository>();
    final trimmedPhone = _phone.text.trim();
    final trimmedEmail = _email.text.trim();
    final trimmedNotes = _intakeNotes.text.trim();
    final firstName = _firstName.text.trim();
    final middleName = _middleName.text.trim();
    final lastName = _lastName.text.trim();
    final suffix = _suffix.text.trim();
    final fullName = [
      firstName,
      middleName,
      lastName,
      suffix,
    ].where((part) => part.isNotEmpty).join(' ');
    try {
      if (_isEdit) {
        final old = widget.client!;
        await repo.update(
          Client(
            id: old.id,
            referenceNo: old.referenceNo,
            fullName: fullName,
            firstName: firstName,
            middleName: middleName,
            lastName: lastName,
            suffix: suffix,
            phone: trimmedPhone.isEmpty ? null : trimmedPhone,
            email: trimmedEmail.isEmpty ? null : trimmedEmail,
            dateOfBirth: _dateOfBirth,
            intakeNotes: trimmedNotes.isEmpty ? null : trimmedNotes,
            status: old.status,
            registeredAt: old.registeredAt,
            updatedAt: old.updatedAt,
          ),
        );
      } else {
        await repo.create(
          CreateClientInput(
            fullName: fullName,
            firstName: firstName,
            middleName: middleName,
            lastName: lastName,
            suffix: suffix,
            phone: trimmedPhone.isEmpty ? null : trimmedPhone,
            email: trimmedEmail.isEmpty ? null : trimmedEmail,
            dateOfBirth: _dateOfBirth,
            intakeNotes: trimmedNotes.isEmpty ? null : trimmedNotes,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    final focusedFieldBorder = fieldBorder.copyWith(
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: scheme.surfaceContainerLowest,
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: focusedFieldBorder,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEdit ? 'Edit student' : 'New student'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add student details. First name is required.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeading(context, 'PERSONAL DETAILS'),
                  _fieldRow([
                    AppField(
                      label: 'First name *',
                      child: TextFormField(
                        controller: _firstName,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          hintText: 'First name',
                        ),
                        validator: (value) =>
                            requiredField(value, 'First name'),
                      ),
                    ),
                    AppField(
                      label: 'Middle name',
                      child: TextFormField(
                        controller: _middleName,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          hintText: 'Middle name',
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _fieldRow(
                    [
                      AppField(
                        label: 'Last name',
                        child: TextFormField(
                          controller: _lastName,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            hintText: 'Last name',
                          ),
                        ),
                      ),
                      AppField(
                        label: 'Suffix',
                        child: TextFormField(
                          controller: _suffix,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Jr.',
                          ),
                        ),
                      ),
                    ],
                    flexes: const [2, 1],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _sectionHeading(context, 'CONTACT DETAILS'),
                  _fieldRow([
                    AppField(
                      label: 'Phone',
                      child: TextFormField(
                        controller: _phone,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          hintText: 'Phone number',
                        ),
                        validator: optionalPhone,
                      ),
                    ),
                    AppField(
                      label: 'Email',
                      child: TextFormField(
                        controller: _email,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          hintText: 'Email address',
                        ),
                        validator: optionalEmail,
                      ),
                    ),
                    PickerField(
                      label: 'Date of birth',
                      icon: Icons.cake_outlined,
                      displayValue: _dateOfBirth == null
                          ? 'Not set'
                          : formatDate(_dateOfBirth!),
                      errorText: null,
                      onTap: _saving ? () {} : _pickDateOfBirth,
                      onClear: _dateOfBirth == null || _saving
                          ? null
                          : () => setState(() => _dateOfBirth = null),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  AppField(
                    label: 'Intake notes',
                    child: SizedBox(
                      height: 104,
                      child: TextFormField(
                        controller: _intakeNotes,
                        enabled: !_saving,
                        textAlignVertical: TextAlignVertical.top,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        decoration: const InputDecoration(
                          hintText: 'Add relevant background or intake notes',
                          alignLabelWithHint: true,
                          contentPadding: EdgeInsets.all(14),
                        ),
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
            onPressed: _saving ? null : _save,
            child: Text(_isEdit ? 'Save changes' : 'Create student'),
          ),
        ],
      ),
    );
  }
}
