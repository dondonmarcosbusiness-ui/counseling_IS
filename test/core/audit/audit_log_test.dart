import 'package:counseling_is/core/audit/audit_log_repository.dart';
import 'package:counseling_is/core/audit/audit_logger.dart';
import 'package:counseling_is/core/security/password_hasher.dart';
import 'package:counseling_is/features/auth/data/auth_repository.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/forms/data/form_submission_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_db.dart';

void main() {
  late Database db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() async => db.close());

  test(
    'records account-attributed actions without personal record details',
    () async {
      final admin =
          await AuthRepository(
            db,
            hasher: PasswordHasher(logRounds: 4),
          ).createAdmin(
            username: 'admin',
            fullName: 'Site Administrator',
            password: 'Password123',
          );
      final logger = AuditLogger(db, currentAdminId: () => admin.id);
      final client = await ClientRepository(
        db,
        auditLogger: logger,
      ).create(const CreateClientInput(fullName: 'Private Learner Name'));
      await FormSubmissionRepository(db, auditLogger: logger).create(
        formId: 'child_protection_intake',
        clientId: client.id,
        data: const {'factual_account': 'PRIVATE INTAKE DISCLOSURE'},
      );

      final entries = await AuditLogRepository(db).list(searchText: 'client');
      expect(entries, hasLength(1));
      expect(entries.single.adminName, 'Site Administrator');
      expect(entries.single.entityId, client.id);
      expect(entries.single.action, 'created');
      expect(entries.single.detail, isNull);
      expect(entries.single.entityType, 'client');
      final formEntries = await AuditLogRepository(db)
          .list(searchText: 'form_submission');
      expect(formEntries, hasLength(1));
      expect(formEntries.single.detail, isNull);
      expect(formEntries.single.action, 'created');
    },
  );
}
