import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/core/time/display_format.dart';
import 'package:counseling_is/core/validation/validators.dart';
import 'package:counseling_is/core/widgets/app_dropdown.dart';
import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:counseling_is/core/widgets/error_banner.dart';
import 'package:counseling_is/core/widgets/picker_field.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/domain/client.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Create/edit dialog for a student, laid out like the Individual Student
/// Information Sheet. Pops `true` when the record was saved.
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
  late final TextEditingController _gradeSection;
  late final TextEditingController _learnerNo;
  late final TextEditingController _religion;
  late final TextEditingController _address;
  late final TextEditingController _hobbies;
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyContactNo;
  late final TextEditingController _emergencyAddress;
  late final TextEditingController _emergencyJob;
  late final TextEditingController _emergencyRelationship;
  late final TextEditingController _fatherName;
  late final TextEditingController _fatherAge;
  late final TextEditingController _fatherJob;
  late final TextEditingController _fatherWorkplace;
  late final TextEditingController _motherName;
  late final TextEditingController _motherAge;
  late final TextEditingController _motherJob;
  late final TextEditingController _motherWorkplace;
  late final TextEditingController _guardianName;
  late final TextEditingController _guardianAge;
  late final TextEditingController _guardianJob;
  late final TextEditingController _guardianWorkplace;
  late final TextEditingController _guardianRelationship;
  late final TextEditingController _parentsStatusDetail;
  final Set<String> _memberTags = {};
  DateTime? _dateOfBirth;
  String? _sex;
  String? _fatherEducation;
  String? _motherEducation;
  String? _livingWith;
  String? _familyIncome;
  String? _parentsStatus;
  String? _screenNoAppetite;
  String? _screenCriesOften;
  String? _screenAbuse;
  String? _screenSelfBlame;
  String? _screenSuicidalThoughts;
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.client != null;

  Widget _sectionHeading(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _groupHeading(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
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

  Widget _input(
    String label,
    TextEditingController controller, {
    String? hint,
    String? Function(String? value)? validator,
  }) {
    return AppField(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        decoration: InputDecoration(hintText: hint),
        validator: validator,
      ),
    );
  }

  Widget _dropdown(
    String? label,
    String? value,
    List<String> options,
    void Function(String? value) onChanged, {
    String? hint,
  }) {
    return AppDropdownFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: hint == null ? null : Text(hint),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: _saving ? null : onChanged,
    );
  }

  Widget _yesNoRow(
    String label,
    String? value,
    void Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 150,
            child: _dropdown(
              null,
              value,
              kYesNoOptions,
              onChanged,
              hint: 'Not answered',
            ),
          ),
        ],
      ),
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
    _gradeSection = TextEditingController(text: client?.gradeSection ?? '');
    _learnerNo = TextEditingController(text: client?.learnerNo ?? '');
    _religion = TextEditingController(text: client?.religion ?? '');
    _address = TextEditingController(text: client?.address ?? '');
    _hobbies = TextEditingController(text: client?.hobbies ?? '');
    _emergencyName = TextEditingController(text: client?.emergencyName ?? '');
    _emergencyContactNo = TextEditingController(
      text: client?.emergencyContactNo ?? '',
    );
    _emergencyAddress = TextEditingController(
      text: client?.emergencyAddress ?? '',
    );
    _emergencyJob = TextEditingController(text: client?.emergencyJob ?? '');
    _emergencyRelationship = TextEditingController(
      text: client?.emergencyRelationship ?? '',
    );
    _fatherName = TextEditingController(text: client?.fatherName ?? '');
    _fatherAge = TextEditingController(text: client?.fatherAge ?? '');
    _fatherJob = TextEditingController(text: client?.fatherJob ?? '');
    _fatherWorkplace = TextEditingController(
      text: client?.fatherWorkplace ?? '',
    );
    _motherName = TextEditingController(text: client?.motherName ?? '');
    _motherAge = TextEditingController(text: client?.motherAge ?? '');
    _motherJob = TextEditingController(text: client?.motherJob ?? '');
    _motherWorkplace = TextEditingController(
      text: client?.motherWorkplace ?? '',
    );
    _guardianName = TextEditingController(text: client?.guardianName ?? '');
    _guardianAge = TextEditingController(text: client?.guardianAge ?? '');
    _guardianJob = TextEditingController(text: client?.guardianJob ?? '');
    _guardianWorkplace = TextEditingController(
      text: client?.guardianWorkplace ?? '',
    );
    _guardianRelationship = TextEditingController(
      text: client?.guardianRelationship ?? '',
    );
    _parentsStatusDetail = TextEditingController(
      text: client?.parentsStatusDetail ?? '',
    );
    _memberTags.addAll(client?.memberTagList ?? const []);
    _dateOfBirth = client?.dateOfBirth;
    _sex = client?.sex;
    _fatherEducation = client?.fatherEducation;
    _motherEducation = client?.motherEducation;
    _livingWith = client?.livingWith;
    _familyIncome = client?.familyIncome;
    _parentsStatus = client?.parentsStatus;
    _screenNoAppetite = client?.screenNoAppetite;
    _screenCriesOften = client?.screenCriesOften;
    _screenAbuse = client?.screenAbuse;
    _screenSelfBlame = client?.screenSelfBlame;
    _screenSuicidalThoughts = client?.screenSuicidalThoughts;
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
    _gradeSection.dispose();
    _learnerNo.dispose();
    _religion.dispose();
    _address.dispose();
    _hobbies.dispose();
    _emergencyName.dispose();
    _emergencyContactNo.dispose();
    _emergencyAddress.dispose();
    _emergencyJob.dispose();
    _emergencyRelationship.dispose();
    _fatherName.dispose();
    _fatherAge.dispose();
    _fatherJob.dispose();
    _fatherWorkplace.dispose();
    _motherName.dispose();
    _motherAge.dispose();
    _motherJob.dispose();
    _motherWorkplace.dispose();
    _guardianName.dispose();
    _guardianAge.dispose();
    _guardianJob.dispose();
    _guardianWorkplace.dispose();
    _guardianRelationship.dispose();
    _parentsStatusDetail.dispose();
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

  String? get _age {
    final dateOfBirth = _dateOfBirth;
    if (dateOfBirth == null) return null;
    final today = DateTime.now();
    var age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }
    return '$age';
  }

  String _text(TextEditingController controller) => controller.text.trim();

  String? _nullable(TextEditingController controller) {
    final value = _text(controller);
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _error = null;
      _saving = true;
    });

    final repo = context.read<ClientRepository>();
    final firstName = _text(_firstName);
    final middleName = _text(_middleName);
    final lastName = _text(_lastName);
    final suffix = _text(_suffix);
    final fullName = [
      firstName,
      middleName,
      lastName,
      suffix,
    ].where((part) => part.isNotEmpty).join(' ');
    final memberTags = _memberTags.toList().join(', ');
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
            phone: _nullable(_phone),
            email: _nullable(_email),
            dateOfBirth: _dateOfBirth,
            intakeNotes: _nullable(_intakeNotes),
            gradeSection: _nullable(_gradeSection),
            learnerNo: _nullable(_learnerNo),
            sex: _sex,
            religion: _nullable(_religion),
            address: _nullable(_address),
            memberTags: memberTags.isEmpty ? null : memberTags,
            hobbies: _nullable(_hobbies),
            emergencyName: _nullable(_emergencyName),
            emergencyContactNo: _nullable(_emergencyContactNo),
            emergencyAddress: _nullable(_emergencyAddress),
            emergencyJob: _nullable(_emergencyJob),
            emergencyRelationship: _nullable(_emergencyRelationship),
            fatherName: _nullable(_fatherName),
            fatherAge: _nullable(_fatherAge),
            fatherJob: _nullable(_fatherJob),
            fatherWorkplace: _nullable(_fatherWorkplace),
            fatherEducation: _fatherEducation,
            motherName: _nullable(_motherName),
            motherAge: _nullable(_motherAge),
            motherJob: _nullable(_motherJob),
            motherWorkplace: _nullable(_motherWorkplace),
            motherEducation: _motherEducation,
            guardianName: _nullable(_guardianName),
            guardianAge: _nullable(_guardianAge),
            guardianJob: _nullable(_guardianJob),
            guardianWorkplace: _nullable(_guardianWorkplace),
            guardianRelationship: _nullable(_guardianRelationship),
            livingWith: _livingWith,
            familyIncome: _familyIncome,
            parentsStatus: _parentsStatus,
            parentsStatusDetail: _nullable(_parentsStatusDetail),
            screenNoAppetite: _screenNoAppetite,
            screenCriesOften: _screenCriesOften,
            screenAbuse: _screenAbuse,
            screenSelfBlame: _screenSelfBlame,
            screenSuicidalThoughts: _screenSuicidalThoughts,
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
            phone: _nullable(_phone),
            email: _nullable(_email),
            dateOfBirth: _dateOfBirth,
            intakeNotes: _nullable(_intakeNotes),
            gradeSection: _nullable(_gradeSection),
            learnerNo: _nullable(_learnerNo),
            sex: _sex,
            religion: _nullable(_religion),
            address: _nullable(_address),
            memberTags: memberTags.isEmpty ? null : memberTags,
            hobbies: _nullable(_hobbies),
            emergencyName: _nullable(_emergencyName),
            emergencyContactNo: _nullable(_emergencyContactNo),
            emergencyAddress: _nullable(_emergencyAddress),
            emergencyJob: _nullable(_emergencyJob),
            emergencyRelationship: _nullable(_emergencyRelationship),
            fatherName: _nullable(_fatherName),
            fatherAge: _nullable(_fatherAge),
            fatherJob: _nullable(_fatherJob),
            fatherWorkplace: _nullable(_fatherWorkplace),
            fatherEducation: _fatherEducation,
            motherName: _nullable(_motherName),
            motherAge: _nullable(_motherAge),
            motherJob: _nullable(_motherJob),
            motherWorkplace: _nullable(_motherWorkplace),
            motherEducation: _motherEducation,
            guardianName: _nullable(_guardianName),
            guardianAge: _nullable(_guardianAge),
            guardianJob: _nullable(_guardianJob),
            guardianWorkplace: _nullable(_guardianWorkplace),
            guardianRelationship: _nullable(_guardianRelationship),
            livingWith: _livingWith,
            familyIncome: _familyIncome,
            parentsStatus: _parentsStatus,
            parentsStatusDetail: _nullable(_parentsStatusDetail),
            screenNoAppetite: _screenNoAppetite,
            screenCriesOften: _screenCriesOften,
            screenAbuse: _screenAbuse,
            screenSelfBlame: _screenSelfBlame,
            screenSuicidalThoughts: _screenSuicidalThoughts,
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
              'Individual Student Information Sheet — '
              'first name is required, the rest can be added later.',
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
                  _sectionHeading(context, 'I. PERSONAL INFORMATION'),
                  _fieldRow([
                    _input(
                      'First name *',
                      _firstName,
                      hint: 'First name',
                      validator: (value) => requiredField(value, 'First name'),
                    ),
                    _input('Middle name', _middleName, hint: 'Middle name'),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _fieldRow(
                    [
                      _input('Last name', _lastName, hint: 'Last name'),
                      _input('Suffix', _suffix, hint: 'e.g. Jr.'),
                    ],
                    flexes: const [2, 1],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _fieldRow([
                    _input(
                      'Grade and section',
                      _gradeSection,
                      hint: 'e.g. Grade 9 – Sampaguita',
                    ),
                    _input(
                      'Learner reference no.',
                      _learnerNo,
                      hint: 'LRN / student no.',
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _fieldRow([
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
                    _dropdown('Sex', _sex, kSexOptions, (value) {
                      setState(() => _sex = value);
                    }),
                    AppField(
                      label: 'Age',
                      child: TextFormField(
                        key: ValueKey<String?>(_age),
                        readOnly: true,
                        enabled: !_saving,
                        initialValue: _age,
                        decoration: const InputDecoration(
                          hintText: 'Set date of birth',
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _fieldRow([
                    _input('Religion', _religion, hint: 'Religion'),
                    _input(
                      'Permanent address',
                      _address,
                      hint: 'House no., street, barangay, town',
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  AppField(
                    label: 'Kabilang sa (select all that apply)',
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final tag in kMemberTagOptions)
                          FilterChip(
                            label: Text(tag),
                            selected: _memberTags.contains(tag),
                            onSelected: _saving
                                ? null
                                : (selected) {
                                    setState(() {
                                      if (selected) {
                                        _memberTags.add(tag);
                                      } else {
                                        _memberTags.remove(tag);
                                      }
                                    });
                                  },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _input(
                    'Hobbies / interests',
                    _hobbies,
                    hint: 'What do you like to do in your free time?',
                  ),

                  _sectionHeading(context, 'CONTACT DETAILS'),
                  _fieldRow([
                    _input(
                      'Phone',
                      _phone,
                      hint: 'Phone number',
                      validator: optionalPhone,
                    ),
                    _input(
                      'Email',
                      _email,
                      hint: 'Email address',
                      validator: optionalEmail,
                    ),
                  ]),

                  _sectionHeading(
                    context,
                    'PERSON TO NOTIFY IN CASE OF EMERGENCY',
                  ),
                  _fieldRow([
                    _input('Name', _emergencyName, hint: 'Full name'),
                    _input(
                      'Contact number',
                      _emergencyContactNo,
                      hint: 'Contact number',
                      validator: optionalPhone,
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _fieldRow([
                    _input('Occupation', _emergencyJob, hint: 'Occupation'),
                    _input(
                      'Relationship',
                      _emergencyRelationship,
                      hint: 'e.g. Mother',
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _input(
                    'Address',
                    _emergencyAddress,
                    hint: 'Residence / workplace address',
                  ),

                  _sectionHeading(context, 'II. FAMILY'),
                  _groupHeading(context, 'Father'),
                  _fieldRow([
                    _input('Father name', _fatherName, hint: 'Full name'),
                    _input('Age', _fatherAge, hint: 'Age'),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _fieldRow([
                    _input('Occupation', _fatherJob, hint: 'Occupation'),
                    _input(
                      'Place of work',
                      _fatherWorkplace,
                      hint: 'Where they work',
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _dropdown(
                    'Education attained',
                    _fatherEducation,
                    kEducationOptions,
                    (value) => setState(() => _fatherEducation = value),
                    hint: 'Select one',
                  ),
                  _groupHeading(context, 'Mother'),
                  _fieldRow([
                    _input('Mother name', _motherName, hint: 'Full name'),
                    _input('Age', _motherAge, hint: 'Age'),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _fieldRow([
                    _input('Occupation', _motherJob, hint: 'Occupation'),
                    _input(
                      'Place of work',
                      _motherWorkplace,
                      hint: 'Where they work',
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _dropdown(
                    'Education attained',
                    _motherEducation,
                    kEducationOptions,
                    (value) => setState(() => _motherEducation = value),
                    hint: 'Select one',
                  ),
                  _groupHeading(
                    context,
                    'Guardian (if not living with parents)',
                  ),
                  _fieldRow([
                    _input('Guardian name', _guardianName, hint: 'Full name'),
                    _input('Age', _guardianAge, hint: 'Age'),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _fieldRow([
                    _input(
                      'Relationship',
                      _guardianRelationship,
                      hint: 'Relationship to student',
                    ),
                    _input('Occupation', _guardianJob, hint: 'Occupation'),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _input(
                    'Place of work',
                    _guardianWorkplace,
                    hint: 'Where they work',
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  _fieldRow([
                    _dropdown(
                      'Living with',
                      _livingWith,
                      kLivingWithOptions,
                      (value) => setState(() => _livingWith = value),
                      hint: 'Select one',
                    ),
                    _dropdown(
                      'Monthly family income',
                      _familyIncome,
                      kFamilyIncomeOptions,
                      (value) => setState(() => _familyIncome = value),
                      hint: 'Select one',
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _dropdown(
                    "Parents' relationship",
                    _parentsStatus,
                    kParentsStatusOptions,
                    (value) => setState(() => _parentsStatus = value),
                    hint: 'Select one',
                  ),
                  if (_parentsStatus == 'Deceased') ...[
                    const SizedBox(height: AppSpacing.md),
                    _input(
                      'Specify',
                      _parentsStatusDetail,
                      hint: 'Which parent is deceased?',
                    ),
                  ],

                  _sectionHeading(
                    context,
                    'III. CONFIDENTIAL WELL-BEING CHECK',
                  ),
                  Text(
                    'Record the student’s answers as given. Answers here are '
                    'kept confidential and are used only to guide the '
                    'care-center response.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _yesNoRow(
                    'I have no appetite for food.',
                    _screenNoAppetite,
                    (value) => setState(() => _screenNoAppetite = value),
                  ),
                  _yesNoRow(
                    'I often cry.',
                    _screenCriesOften,
                    (value) => setState(() => _screenCriesOften = value),
                  ),
                  _yesNoRow(
                    'I experience abuse or harm (sexual / physical).',
                    _screenAbuse,
                    (value) => setState(() => _screenAbuse = value),
                  ),
                  _yesNoRow(
                    'I often blame myself for what happens.',
                    _screenSelfBlame,
                    (value) => setState(() => _screenSelfBlame = value),
                  ),
                  _yesNoRow(
                    'I want to end my life.',
                    _screenSuicidalThoughts,
                    (value) => setState(() => _screenSuicidalThoughts = value),
                  ),

                  _sectionHeading(context, 'INTAKE NOTES'),
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
