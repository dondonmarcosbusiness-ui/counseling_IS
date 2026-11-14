import 'dart:convert';

import 'package:counseling_is/core/time/time.dart';

class FormSubmission {
  const FormSubmission({
    this.id,
    required this.formId,
    required this.data,
    this.clientId,
    this.clientName,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String formId;
  final Map<String, Object?> data;
  final int? clientId;
  final String? clientName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    if (id == null) {
      throw StateError('FormSubmission.id must be set before writing');
    }
    return {
      'id': id,
      'form_id': formId,
      'client_id': clientId,
      'form_data': jsonEncode(data),
      'created_at': dateTimeToDb(createdAt),
      'updated_at': dateTimeToDb(updatedAt),
    };
  }

  static FormSubmission fromMap(Map<String, Object?> map) {
    final decoded = jsonDecode(map['form_data'] as String) as Map;
    return FormSubmission(
      id: map['id'] as int?,
      formId: map['form_id'] as String,
      data: Map<String, Object?>.from(decoded),
      clientId: map['client_id'] as int?,
      clientName: map['client_name'] as String?,
      createdAt: parseDbDateTime(map['created_at'] as String) ?? DateTime.now(),
      updatedAt: parseDbDateTime(map['updated_at'] as String) ?? DateTime.now(),
    );
  }
}
