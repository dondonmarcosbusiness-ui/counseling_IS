import 'package:counseling_is/core/time/time.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.createdAt,
    this.entityId,
    this.detail,
    this.adminName,
  });

  final int id;
  final String action;
  final String entityType;
  final int? entityId;
  final String? detail;
  final DateTime createdAt;
  final String? adminName;

  static AuditLogEntry fromMap(Map<String, Object?> map) => AuditLogEntry(
    id: map['id'] as int,
    action: map['action'] as String,
    entityType: map['entity_type'] as String? ?? 'system',
    entityId: map['entity_id'] as int?,
    detail: map['detail'] as String?,
    createdAt: parseDbDateTime(map['created_at'] as String)!,
    adminName: map['admin_name'] as String?,
  );
}

class AuditLogRepository {
  AuditLogRepository(this._db);

  final Database _db;

  Future<List<AuditLogEntry>> list({String? searchText}) async {
    final text = searchText?.trim();
    final where = text == null || text.isEmpty
        ? ''
        : "WHERE a.action LIKE ? ESCAPE '\\' "
              "OR a.entity_type LIKE ? ESCAPE '\\' "
              "OR COALESCE(u.full_name, '') LIKE ? ESCAPE '\\'";
    final args = <Object?>[];
    if (text != null && text.isNotEmpty) {
      final escaped = text
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      args.addAll(['%$escaped%', '%$escaped%', '%$escaped%']);
    }
    final rows = await _db.rawQuery(
      'SELECT a.*, u.full_name AS admin_name '
      'FROM audit_logs a LEFT JOIN admins u ON u.id = a.admin_id '
      '$where ORDER BY a.created_at DESC, a.id DESC LIMIT 500',
      args,
    );
    return rows.map(AuditLogEntry.fromMap).toList();
  }
}
