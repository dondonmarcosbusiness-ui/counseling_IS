import 'package:counseling_is/core/time/time.dart';

class CaseTimelineEvent {
  const CaseTimelineEvent({
    required this.id,
    required this.caseId,
    required this.occurredAt,
    required this.eventType,
    required this.title,
    this.description,
    this.adminName,
  });

  final int id;
  final int caseId;
  final DateTime occurredAt;
  final String eventType;
  final String title;
  final String? description;
  final String? adminName;

  static CaseTimelineEvent fromMap(Map<String, Object?> map) =>
      CaseTimelineEvent(
        id: map['id'] as int,
        caseId: map['case_id'] as int,
        occurredAt: parseDbDateTime(map['occurred_at'] as String)!,
        eventType: map['event_type'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        adminName: map['admin_name'] as String?,
      );
}
