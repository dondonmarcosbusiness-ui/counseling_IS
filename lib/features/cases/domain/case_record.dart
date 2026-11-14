import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/time/time.dart';

class CaseRecord {
  const CaseRecord({
    this.id,
    required this.caseRef,
    required this.clientId,
    required this.openedAt,
    this.status = CaseStatus.open,
    this.summary,
    this.followUpDate,
    this.closedAt,
    this.closureNotes,
    required this.createdAt,
    required this.updatedAt,
    this.clientName,
  });

  final int? id;
  final String caseRef;
  final int clientId;

  /// Calendar date the case was opened (no time of day).
  final DateTime openedAt;
  final CaseStatus status;
  final String? summary;
  final DateTime? followUpDate;
  final DateTime? closedAt;
  final String? closureNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Populated by list queries that join `clients`; never persisted.
  final String? clientName;

  bool get isOpen => status != CaseStatus.closed;

  Map<String, Object?> toMap() {
    if (id == null) {
      throw StateError('CaseRecord.id must be set before writing');
    }
    return {
      'id': id,
      'case_ref': caseRef,
      'client_id': clientId,
      'opened_at': dateToDb(openedAt),
      'status': status.dbValue,
      'summary': summary,
      'follow_up_date':
          followUpDate == null ? null : dateToDb(followUpDate!),
      'closed_at': closedAt == null ? null : dateToDb(closedAt!),
      'closure_notes': closureNotes,
      'created_at': dateTimeToDb(createdAt),
      'updated_at': dateTimeToDb(updatedAt),
    };
  }

  static CaseRecord fromMap(Map<String, Object?> map) {
    return CaseRecord(
      id: map['id'] as int?,
      caseRef: map['case_ref'] as String,
      clientId: map['client_id'] as int,
      openedAt: parseDbDate(map['opened_at'] as String) ?? DateTime.now(),
      status: CaseStatus.fromDb(map['status'] as String),
      summary: map['summary'] as String?,
      followUpDate: parseDbDate(map['follow_up_date'] as String?),
      closedAt: parseDbDate(map['closed_at'] as String?),
      closureNotes: map['closure_notes'] as String?,
      createdAt: parseDbDateTime(map['created_at'] as String) ?? DateTime.now(),
      updatedAt: parseDbDateTime(map['updated_at'] as String) ?? DateTime.now(),
      clientName: map['client_name'] as String?,
    );
  }

  CaseRecord copyWith({
    int? id,
    String? caseRef,
    int? clientId,
    DateTime? openedAt,
    CaseStatus? status,
    String? summary,
    bool clearSummary = false,
    DateTime? followUpDate,
    bool clearFollowUpDate = false,
    DateTime? closedAt,
    bool clearClosedAt = false,
    String? closureNotes,
    bool clearClosureNotes = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? clientName,
  }) {
    return CaseRecord(
      id: id ?? this.id,
      caseRef: caseRef ?? this.caseRef,
      clientId: clientId ?? this.clientId,
      openedAt: openedAt ?? this.openedAt,
      status: status ?? this.status,
      summary: clearSummary ? null : (summary ?? this.summary),
      followUpDate:
          clearFollowUpDate ? null : (followUpDate ?? this.followUpDate),
      closedAt: clearClosedAt ? null : (closedAt ?? this.closedAt),
      closureNotes:
          clearClosureNotes ? null : (closureNotes ?? this.closureNotes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      clientName: clientName ?? this.clientName,
    );
  }
}

enum CaseStatus {
  open('open', 'Open'),
  inProgress('in_progress', 'In progress'),
  closed('closed', 'Closed');

  const CaseStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static CaseStatus fromDb(String value) {
    for (final status in values) {
      if (status.dbValue == value) return status;
    }
    throw ValidationException('Unknown case status: $value');
  }
}
