import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/time.dart';

class Appointment {
  const Appointment({
    this.id,
    required this.clientId,
    required this.startsAt,
    required this.endsAt,
    this.purpose,
    this.status = AppointmentStatus.scheduled,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.clientName,
  });

  final int? id;
  final int clientId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? purpose;
  final AppointmentStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Populated by list queries that join `clients`; never persisted.
  final String? clientName;

  Duration get duration => endsAt.difference(startsAt);

  bool get isCancelled => status == AppointmentStatus.cancelled;

  Map<String, Object?> toMap() {
    if (id == null) {
      throw StateError('Appointment.id must be set before writing');
    }
    return {
      'id': id,
      'client_id': clientId,
      'starts_at': dateTimeToDb(startsAt),
      'ends_at': dateTimeToDb(endsAt),
      'purpose': purpose,
      'status': status.dbValue,
      'notes': notes,
      'created_at': dateTimeToDb(createdAt),
      'updated_at': dateTimeToDb(updatedAt),
    };
  }

  static Appointment fromMap(Map<String, Object?> map) {
    return Appointment(
      id: map['id'] as int?,
      clientId: map['client_id'] as int,
      startsAt: parseDbDateTime(map['starts_at'] as String) ?? DateTime.now(),
      endsAt: parseDbDateTime(map['ends_at'] as String) ?? DateTime.now(),
      purpose: map['purpose'] as String?,
      status: AppointmentStatus.fromDb(map['status'] as String),
      notes: map['notes'] as String?,
      createdAt: parseDbDateTime(map['created_at'] as String) ?? DateTime.now(),
      updatedAt: parseDbDateTime(map['updated_at'] as String) ?? DateTime.now(),
      clientName: map['client_name'] as String?,
    );
  }
}

enum AppointmentStatus {
  scheduled('scheduled', 'Scheduled'),
  completed('completed', 'Completed'),
  missed('missed', 'Missed'),
  cancelled('cancelled', 'Cancelled');

  const AppointmentStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AppointmentStatus fromDb(String value) {
    for (final status in values) {
      if (status.dbValue == value) return status;
    }
    throw ValidationException('Unknown appointment status: $value');
  }
}

enum AppointmentTimeFilter {
  upcoming,
  today,
  past,
  all,
}
