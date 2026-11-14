import 'package:counseling_is/core/time/time.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AuditLogger {
  AuditLogger(this._db, {int? Function()? currentAdminId})
    : _currentAdminId = currentAdminId ?? _noAdmin;

  final Database _db;
  final int? Function() _currentAdminId;

  int? get currentAdminId => _currentAdminId();

  Future<void> record({
    required String action,
    required String entityType,
    int? entityId,
    int? actorId,
    String? detail,
    DatabaseExecutor? executor,
  }) async {
    await (executor ?? _db).insert('audit_logs', {
      'admin_id': actorId ?? _currentAdminId(),
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'detail': detail,
      'created_at': nowUtcIso(),
    });
  }

  static int? _noAdmin() => null;
}
