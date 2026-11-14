import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/time.dart';

class Intervention {
  const Intervention({
    this.id,
    required this.clientId,
    this.clientName,
    this.caseId,
    this.caseRef,
    required this.title,
    required this.type,
    this.customType,
    this.participantIds = const [],
    this.participantLabel,
    this.description,
    this.goal,
    required this.status,
    required this.startDate,
    this.targetDate,
    this.completedAt,
    this.outcome,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int clientId;
  final String? clientName;
  final int? caseId;
  final String? caseRef;
  final String title;
  final String type;
  final String? customType;
  final List<int> participantIds;
  final String? participantLabel;
  final String? description;
  final String? goal;
  final InterventionStatus status;
  final DateTime startDate;
  final DateTime? targetDate;
  final DateTime? completedAt;
  final String? outcome;
  final DateTime createdAt;
  final DateTime updatedAt;

  static Intervention fromMap(Map<String, Object?> map) => Intervention(
    id: map['id'] as int,
    clientId: map['client_id'] as int,
    clientName: map['client_name'] as String?,
    caseId: map['case_id'] as int?,
    caseRef: map['case_ref'] as String?,
    title: map['title'] as String,
    type: map['intervention_type'] as String,
    customType: map['custom_type'] as String?,
    participantIds:
        (map['participant_ids'] as String?)
            ?.split(',')
            .where((value) => value.isNotEmpty)
            .map(int.parse)
            .toList() ??
        [map['client_id'] as int],
    participantLabel: map['participant_label'] as String?,
    description: map['description'] as String?,
    goal: map['goal'] as String?,
    status: InterventionStatus.fromDb(map['status'] as String),
    startDate: parseDbDate(map['start_date'] as String)!,
    targetDate: parseDbDate(map['target_date'] as String?),
    completedAt: parseDbDate(map['completed_at'] as String?),
    outcome: map['outcome'] as String?,
    createdAt: parseDbDateTime(map['created_at'] as String)!,
    updatedAt: parseDbDateTime(map['updated_at'] as String)!,
  );
}

enum InterventionStatus {
  planned('planned', 'Planned'),
  inProgress('in_progress', 'In progress'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const InterventionStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static InterventionStatus fromDb(String value) {
    for (final status in values) {
      if (status.dbValue == value) return status;
    }
    throw ValidationException('Unknown intervention status: $value');
  }
}
