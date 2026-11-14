import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/time.dart';

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
  final ClientStatus status;
  final DateTime registeredAt;
  final DateTime updatedAt;

  bool get isArchived => status == ClientStatus.archived;

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
