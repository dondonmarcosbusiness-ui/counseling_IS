import 'package:counseling_is/core/time/time.dart';

class SessionRecord {
  const SessionRecord({
    this.id,
    required this.clientId,
    this.appointmentId,
    required this.sessionDate,
    required this.notes,
    this.followUpActions,
    this.nextRecommendedDate,
    required this.createdAt,
    required this.updatedAt,
    this.clientName,
  });

  final int? id;
  final int clientId;
  final int? appointmentId;

  /// Calendar date of the session (no time of day).
  final DateTime sessionDate;

  /// Confidential counseling notes; must never be shown on dashboards or
  /// ordinary client lists.
  final String notes;
  final String? followUpActions;
  final DateTime? nextRecommendedDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Populated by list queries that join `clients`; never persisted.
  final String? clientName;

  Map<String, Object?> toMap() {
    if (id == null) {
      throw StateError('SessionRecord.id must be set before writing');
    }
    return {
      'id': id,
      'client_id': clientId,
      'appointment_id': appointmentId,
      'session_date': dateToDb(sessionDate),
      'notes': notes,
      'follow_up_actions': followUpActions,
      'next_recommended_date': nextRecommendedDate == null
          ? null
          : dateToDb(nextRecommendedDate!),
      'created_at': dateTimeToDb(createdAt),
      'updated_at': dateTimeToDb(updatedAt),
    };
  }

  static SessionRecord fromMap(Map<String, Object?> map) {
    return SessionRecord(
      id: map['id'] as int?,
      clientId: map['client_id'] as int,
      appointmentId: map['appointment_id'] as int?,
      sessionDate: parseDbDate(map['session_date'] as String) ?? DateTime.now(),
      notes: map['notes'] as String,
      followUpActions: map['follow_up_actions'] as String?,
      nextRecommendedDate: parseDbDate(map['next_recommended_date'] as String?),
      createdAt: parseDbDateTime(map['created_at'] as String) ?? DateTime.now(),
      updatedAt: parseDbDateTime(map['updated_at'] as String) ?? DateTime.now(),
      clientName: map['client_name'] as String?,
    );
  }
}
