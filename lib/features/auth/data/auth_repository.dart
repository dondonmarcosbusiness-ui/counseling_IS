import 'package:counseling_is/core/audit/audit_logger.dart';
import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/security/password_hasher.dart';
import 'package:counseling_is/core/time/time.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.username,
    required this.fullName,
    required this.isActive,
  });

  final int id;
  final String username;
  final String fullName;
  final bool isActive;

  static AdminAccount fromMap(Map<String, Object?> map) => AdminAccount(
    id: map['id'] as int,
    username: map['username'] as String,
    fullName: map['full_name'] as String,
    isActive: (map['is_active'] as int) == 1,
  );
}

class AuthRepository {
  AuthRepository(this._db, {PasswordHasher? hasher, AuditLogger? auditLogger})
    : _hasher = hasher ?? PasswordHasher(),
      _audit = auditLogger ?? AuditLogger(_db);

  final Database _db;
  final PasswordHasher _hasher;
  final AuditLogger _audit;

  Future<bool> hasAdmin() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM admins WHERE is_active = 1',
    );
    return ((rows.first['c'] as int?) ?? 0) > 0;
  }

  Future<AdminAccount> createAdmin({
    required String username,
    required String fullName,
    required String password,
    int? createdByAdminId,
  }) async {
    final trimmedUsername = username.trim();
    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) throw ValidationException('Full name is required');

    final hash = await _hasher.hash(password);
    final id = await _db.transaction((txn) async {
      final existing = await txn.query(
        'admins',
        columns: ['id'],
        where: 'username = ?',
        whereArgs: [trimmedUsername],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw DuplicateException('Username is already taken');
      }
      final id = await txn.insert('admins', {
        'username': trimmedUsername,
        'password_hash': hash,
        'full_name': trimmedName,
        'created_at': nowUtcIso(),
        'is_active': 1,
      });
      await _audit.record(
        action: 'created',
        entityType: 'admin_account',
        entityId: id,
        actorId: createdByAdminId ?? _audit.currentAdminId ?? id,
        executor: txn,
      );
      return id;
    });
    return AdminAccount(
      id: id,
      username: trimmedUsername,
      fullName: trimmedName,
      isActive: true,
    );
  }

  Future<AdminAccount?> verifyCredentials(
    String username,
    String password,
  ) async {
    final rows = await _db.query(
      'admins',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final storedHash = row['password_hash'] as String;
    final ok = await _hasher.verify(password, storedHash);
    if (!ok) return null;
    await _db.transaction((txn) async {
      await txn.update(
        'admins',
        {'last_login_at': nowUtcIso()},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      await _audit.record(
        action: 'signed_in',
        entityType: 'admin_account',
        entityId: row['id'] as int,
        actorId: row['id'] as int,
        executor: txn,
      );
    });
    return AdminAccount.fromMap(row);
  }

  Future<List<AdminAccount>> listAdmins() async {
    final rows = await _db.query(
      'admins',
      columns: ['id', 'username', 'full_name', 'is_active'],
      orderBy: 'is_active DESC, full_name COLLATE NOCASE ASC',
    );
    return rows.map(AdminAccount.fromMap).toList();
  }

  Future<void> setAdminActive({
    required int adminId,
    required bool isActive,
    required int requestingAdminId,
  }) async {
    if (!isActive && adminId == requestingAdminId) {
      throw ValidationException(
        'You cannot deactivate the account you are signed in with',
      );
    }
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'admins',
        columns: ['is_active'],
        where: 'id = ?',
        whereArgs: [adminId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw NotFoundException('Administrator account not found');
      }
      final wasActive = (rows.single['is_active'] as int) == 1;
      if (wasActive == isActive) return;
      if (!isActive) {
        final count = await txn.rawQuery(
          'SELECT COUNT(*) AS c FROM admins WHERE is_active = 1',
        );
        if (((count.single['c'] as int?) ?? 0) <= 1) {
          throw ValidationException(
            'At least one active administrator account is required',
          );
        }
      }
      await txn.update(
        'admins',
        {'is_active': isActive ? 1 : 0},
        where: 'id = ?',
        whereArgs: [adminId],
      );
      await _audit.record(
        action: isActive ? 'activated' : 'deactivated',
        entityType: 'admin_account',
        entityId: adminId,
        actorId: requestingAdminId,
        executor: txn,
      );
    });
  }

  Future<void> changePassword({
    required int adminId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final rows = await _db.query(
      'admins',
      where: 'id = ? AND is_active = 1',
      whereArgs: [adminId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw NotFoundException('Administrator account not found');
    }
    final storedHash = rows.single['password_hash'] as String;
    final ok = await _hasher.verify(currentPassword, storedHash);
    if (!ok) {
      throw ValidationException('Current password is incorrect');
    }
    final newHash = await _hasher.hash(newPassword);
    await _db.transaction((txn) async {
      await txn.update(
        'admins',
        {'password_hash': newHash},
        where: 'id = ?',
        whereArgs: [adminId],
      );
      await _audit.record(
        action: 'password_changed',
        entityType: 'admin_account',
        entityId: adminId,
        actorId: adminId,
        executor: txn,
      );
    });
  }
}
