import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/time.dart';

/// Choice lists mirrored from the Individual Student Information Sheet so the
/// New student dialog offers the same options as the paper form.
const List<String> kSexOptions = [
  'Male',
  'Female',
  'Gay',
  'Lesbian',
  'Bisexual',
  'Transgender',
  'Prefer not to say',
  'Other',
];

/// "Kabilang sa" — the groups the learner belongs to.
const List<String> kMemberTagOptions = ['4Ps', 'PWD', 'IP', 'Left-handed'];

/// "Kanino ka kasalukuyang nakatira?"
const List<String> kLivingWithOptions = [
  'Parents',
  'Relatives',
  'Sibling',
  'Other',
];

/// "Buwanan na kita ng Pamilya (combined)".
const List<String> kFamilyIncomeOptions = [
  'Below ₱10,000',
  '₱10,001 – ₱20,000',
  '₱20,001 – ₱30,000',
  'Above ₱30,000',
];

/// "Relasyon ng iyong mga magulang".
const List<String> kParentsStatusOptions = [
  'Married and living together',
  'Married but separated',
  'Both with partners',
  'Father/mother with another partner',
  'Both without partners',
  'Not married',
  'Deceased',
];

/// "Edukasyong Natapos".
const List<String> kEducationOptions = [
  'Elementary Graduate',
  'High School Graduate',
  'College Units',
  'College Graduate',
  'Graduate Units',
  'Post-Graduate',
];

/// "Oo / Hindi" answers to the Section III screening questions.
const List<String> kYesNoOptions = ['Yes', 'No'];

class Client {
  const Client({
    this.id,
    required this.referenceNo,
    required this.fullName,
    this.firstName,
    this.middleName,
    this.lastName,
    this.suffix,
    this.phone,
    this.email,
    this.dateOfBirth,
    this.intakeNotes,
    this.gradeSection,
    this.learnerNo,
    this.sex,
    this.religion,
    this.address,
    this.memberTags,
    this.hobbies,
    this.emergencyName,
    this.emergencyContactNo,
    this.emergencyAddress,
    this.emergencyJob,
    this.emergencyRelationship,
    this.fatherName,
    this.fatherAge,
    this.fatherJob,
    this.fatherWorkplace,
    this.fatherEducation,
    this.motherName,
    this.motherAge,
    this.motherJob,
    this.motherWorkplace,
    this.motherEducation,
    this.guardianName,
    this.guardianAge,
    this.guardianJob,
    this.guardianWorkplace,
    this.guardianRelationship,
    this.livingWith,
    this.familyIncome,
    this.parentsStatus,
    this.parentsStatusDetail,
    this.screenNoAppetite,
    this.screenCriesOften,
    this.screenAbuse,
    this.screenSelfBlame,
    this.screenSuicidalThoughts,
    this.status = ClientStatus.active,
    required this.registeredAt,
    required this.updatedAt,
  });

  final int? id;
  final String referenceNo;
  final String fullName;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? suffix;
  final String? phone;
  final String? email;
  final DateTime? dateOfBirth;
  final String? intakeNotes;
  final String? gradeSection;
  final String? learnerNo;
  final String? sex;
  final String? religion;
  final String? address;
  final String? memberTags;
  final String? hobbies;
  final String? emergencyName;
  final String? emergencyContactNo;
  final String? emergencyAddress;
  final String? emergencyJob;
  final String? emergencyRelationship;
  final String? fatherName;
  final String? fatherAge;
  final String? fatherJob;
  final String? fatherWorkplace;
  final String? fatherEducation;
  final String? motherName;
  final String? motherAge;
  final String? motherJob;
  final String? motherWorkplace;
  final String? motherEducation;
  final String? guardianName;
  final String? guardianAge;
  final String? guardianJob;
  final String? guardianWorkplace;
  final String? guardianRelationship;
  final String? livingWith;
  final String? familyIncome;
  final String? parentsStatus;
  final String? parentsStatusDetail;
  final String? screenNoAppetite;
  final String? screenCriesOften;
  final String? screenAbuse;
  final String? screenSelfBlame;
  final String? screenSuicidalThoughts;
  final ClientStatus status;
  final DateTime registeredAt;
  final DateTime updatedAt;

  bool get isArchived => status == ClientStatus.archived;

  /// The "Kabilang sa" ticks as individual tags.
  List<String> get memberTagList => memberTags == null || memberTags!.isEmpty
      ? const []
      : memberTags!
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();

  Map<String, Object?> toMap() {
    if (id == null) {
      throw StateError('Client.id must be set before writing');
    }
    return {
      'id': id,
      'reference_no': referenceNo,
      'full_name': fullName,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'suffix': suffix,
      'phone': phone,
      'email': email,
      'date_of_birth': dateOfBirth == null ? null : dateToDb(dateOfBirth!),
      'intake_notes': intakeNotes,
      'grade_section': gradeSection,
      'learner_no': learnerNo,
      'sex': sex,
      'religion': religion,
      'address': address,
      'member_tags': memberTags,
      'hobbies': hobbies,
      'emergency_name': emergencyName,
      'emergency_contact_no': emergencyContactNo,
      'emergency_address': emergencyAddress,
      'emergency_job': emergencyJob,
      'emergency_relationship': emergencyRelationship,
      'father_name': fatherName,
      'father_age': fatherAge,
      'father_job': fatherJob,
      'father_workplace': fatherWorkplace,
      'father_education': fatherEducation,
      'mother_name': motherName,
      'mother_age': motherAge,
      'mother_job': motherJob,
      'mother_workplace': motherWorkplace,
      'mother_education': motherEducation,
      'guardian_name': guardianName,
      'guardian_age': guardianAge,
      'guardian_job': guardianJob,
      'guardian_workplace': guardianWorkplace,
      'guardian_relationship': guardianRelationship,
      'living_with': livingWith,
      'family_income': familyIncome,
      'parents_status': parentsStatus,
      'parents_status_detail': parentsStatusDetail,
      'screen_no_appetite': screenNoAppetite,
      'screen_cries_often': screenCriesOften,
      'screen_abuse': screenAbuse,
      'screen_self_blame': screenSelfBlame,
      'screen_suicidal_thoughts': screenSuicidalThoughts,
      'status': status.dbValue,
      'registered_at': dateTimeToDb(registeredAt),
      'updated_at': dateTimeToDb(updatedAt),
    };
  }

  static Client fromMap(Map<String, Object?> map) {
    return Client(
      id: map['id'] as int?,
      referenceNo: map['reference_no'] as String,
      fullName: map['full_name'] as String,
      firstName: map['first_name'] as String?,
      middleName: map['middle_name'] as String?,
      lastName: map['last_name'] as String?,
      suffix: map['suffix'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      dateOfBirth: parseDbDate(map['date_of_birth'] as String?),
      intakeNotes: map['intake_notes'] as String?,
      gradeSection: map['grade_section'] as String?,
      learnerNo: map['learner_no'] as String?,
      sex: map['sex'] as String?,
      religion: map['religion'] as String?,
      address: map['address'] as String?,
      memberTags: map['member_tags'] as String?,
      hobbies: map['hobbies'] as String?,
      emergencyName: map['emergency_name'] as String?,
      emergencyContactNo: map['emergency_contact_no'] as String?,
      emergencyAddress: map['emergency_address'] as String?,
      emergencyJob: map['emergency_job'] as String?,
      emergencyRelationship: map['emergency_relationship'] as String?,
      fatherName: map['father_name'] as String?,
      fatherAge: map['father_age'] as String?,
      fatherJob: map['father_job'] as String?,
      fatherWorkplace: map['father_workplace'] as String?,
      fatherEducation: map['father_education'] as String?,
      motherName: map['mother_name'] as String?,
      motherAge: map['mother_age'] as String?,
      motherJob: map['mother_job'] as String?,
      motherWorkplace: map['mother_workplace'] as String?,
      motherEducation: map['mother_education'] as String?,
      guardianName: map['guardian_name'] as String?,
      guardianAge: map['guardian_age'] as String?,
      guardianJob: map['guardian_job'] as String?,
      guardianWorkplace: map['guardian_workplace'] as String?,
      guardianRelationship: map['guardian_relationship'] as String?,
      livingWith: map['living_with'] as String?,
      familyIncome: map['family_income'] as String?,
      parentsStatus: map['parents_status'] as String?,
      parentsStatusDetail: map['parents_status_detail'] as String?,
      screenNoAppetite: map['screen_no_appetite'] as String?,
      screenCriesOften: map['screen_cries_often'] as String?,
      screenAbuse: map['screen_abuse'] as String?,
      screenSelfBlame: map['screen_self_blame'] as String?,
      screenSuicidalThoughts: map['screen_suicidal_thoughts'] as String?,
      status: ClientStatus.fromDb(map['status'] as String),
      registeredAt:
          parseDbDateTime(map['registered_at'] as String) ?? DateTime.now(),
      updatedAt: parseDbDateTime(map['updated_at'] as String) ?? DateTime.now(),
    );
  }

  Client copyWith({
    int? id,
    String? referenceNo,
    String? fullName,
    String? firstName,
    String? middleName,
    String? lastName,
    String? suffix,
    String? phone,
    String? email,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? intakeNotes,
    bool clearIntakeNotes = false,
    String? gradeSection,
    String? learnerNo,
    String? sex,
    String? religion,
    String? address,
    String? memberTags,
    String? hobbies,
    String? emergencyName,
    String? emergencyContactNo,
    String? emergencyAddress,
    String? emergencyJob,
    String? emergencyRelationship,
    String? fatherName,
    String? fatherAge,
    String? fatherJob,
    String? fatherWorkplace,
    String? fatherEducation,
    String? motherName,
    String? motherAge,
    String? motherJob,
    String? motherWorkplace,
    String? motherEducation,
    String? guardianName,
    String? guardianAge,
    String? guardianJob,
    String? guardianWorkplace,
    String? guardianRelationship,
    String? livingWith,
    String? familyIncome,
    String? parentsStatus,
    String? parentsStatusDetail,
    String? screenNoAppetite,
    String? screenCriesOften,
    String? screenAbuse,
    String? screenSelfBlame,
    String? screenSuicidalThoughts,
    ClientStatus? status,
    DateTime? registeredAt,
    DateTime? updatedAt,
  }) {
    return Client(
      id: id ?? this.id,
      referenceNo: referenceNo ?? this.referenceNo,
      fullName: fullName ?? this.fullName,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      suffix: suffix ?? this.suffix,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      intakeNotes: clearIntakeNotes ? null : (intakeNotes ?? this.intakeNotes),
      gradeSection: gradeSection ?? this.gradeSection,
      learnerNo: learnerNo ?? this.learnerNo,
      sex: sex ?? this.sex,
      religion: religion ?? this.religion,
      address: address ?? this.address,
      memberTags: memberTags ?? this.memberTags,
      hobbies: hobbies ?? this.hobbies,
      emergencyName: emergencyName ?? this.emergencyName,
      emergencyContactNo: emergencyContactNo ?? this.emergencyContactNo,
      emergencyAddress: emergencyAddress ?? this.emergencyAddress,
      emergencyJob: emergencyJob ?? this.emergencyJob,
      emergencyRelationship:
          emergencyRelationship ?? this.emergencyRelationship,
      fatherName: fatherName ?? this.fatherName,
      fatherAge: fatherAge ?? this.fatherAge,
      fatherJob: fatherJob ?? this.fatherJob,
      fatherWorkplace: fatherWorkplace ?? this.fatherWorkplace,
      fatherEducation: fatherEducation ?? this.fatherEducation,
      motherName: motherName ?? this.motherName,
      motherAge: motherAge ?? this.motherAge,
      motherJob: motherJob ?? this.motherJob,
      motherWorkplace: motherWorkplace ?? this.motherWorkplace,
      motherEducation: motherEducation ?? this.motherEducation,
      guardianName: guardianName ?? this.guardianName,
      guardianAge: guardianAge ?? this.guardianAge,
      guardianJob: guardianJob ?? this.guardianJob,
      guardianWorkplace: guardianWorkplace ?? this.guardianWorkplace,
      guardianRelationship: guardianRelationship ?? this.guardianRelationship,
      livingWith: livingWith ?? this.livingWith,
      familyIncome: familyIncome ?? this.familyIncome,
      parentsStatus: parentsStatus ?? this.parentsStatus,
      parentsStatusDetail: parentsStatusDetail ?? this.parentsStatusDetail,
      screenNoAppetite: screenNoAppetite ?? this.screenNoAppetite,
      screenCriesOften: screenCriesOften ?? this.screenCriesOften,
      screenAbuse: screenAbuse ?? this.screenAbuse,
      screenSelfBlame: screenSelfBlame ?? this.screenSelfBlame,
      screenSuicidalThoughts:
          screenSuicidalThoughts ?? this.screenSuicidalThoughts,
      status: status ?? this.status,
      registeredAt: registeredAt ?? this.registeredAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum ClientStatus {
  active('active'),
  archived('archived');

  const ClientStatus(this.dbValue);

  final String dbValue;

  static ClientStatus fromDb(String value) {
    for (final status in values) {
      if (status.dbValue == value) return status;
    }
    throw ValidationException('Unknown client status: $value');
  }
}
