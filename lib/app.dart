import 'package:counseling_is/core/audit/audit_log_repository.dart';
import 'package:counseling_is/core/audit/audit_log_screen.dart';
import 'package:counseling_is/core/audit/audit_logger.dart';
import 'package:counseling_is/core/theme/app_theme.dart';
import 'package:counseling_is/features/appointments/data/appointment_repository.dart';
import 'package:counseling_is/features/appointments/presentation/appointments_screen.dart';
import 'package:counseling_is/features/auth/application/auth_controller.dart';
import 'package:counseling_is/features/auth/presentation/admin_management_screen.dart';
import 'package:counseling_is/features/auth/presentation/lock_screen.dart';
import 'package:counseling_is/features/auth/presentation/login_screen.dart';
import 'package:counseling_is/features/auth/presentation/setup_screen.dart';
import 'package:counseling_is/features/backup/data/backup_service.dart';
import 'package:counseling_is/features/backup/presentation/backup_screen.dart';
import 'package:counseling_is/features/calendar/presentation/guidance_calendar_screen.dart';
import 'package:counseling_is/features/clients/data/client_repository.dart';
import 'package:counseling_is/features/clients/presentation/clients_screen.dart';
import 'package:counseling_is/features/dashboard/data/stats_repository.dart';
import 'package:counseling_is/features/dashboard/presentation/dashboard_screen.dart';
import 'package:counseling_is/features/forms/data/form_submission_repository.dart';
import 'package:counseling_is/features/forms/domain/counseling_form.dart';
import 'package:counseling_is/features/forms/domain/form_submission.dart';
import 'package:counseling_is/features/forms/presentation/forms_screen.dart';
import 'package:counseling_is/features/interventions/data/intervention_repository.dart';
import 'package:counseling_is/features/interventions/presentation/interventions_screen.dart';
import 'package:counseling_is/features/reports/data/report_repository.dart';
import 'package:counseling_is/features/reports/presentation/reports_screen.dart';
import 'package:counseling_is/features/sessions/data/session_repository.dart';
import 'package:counseling_is/features/sessions/presentation/sessions_screen.dart';
import 'package:counseling_is/features/settings/data/settings_repository.dart';
import 'package:counseling_is/features/settings/presentation/settings_screen.dart';
import 'package:counseling_is/shell/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CounselingApp extends StatefulWidget {
  const CounselingApp({
    super.key,
    required this.authController,
    required this.db,
    required this.dbPath,
  });

  final AuthController authController;
  final Database db;
  final String dbPath;

  @override
  State<CounselingApp> createState() => _CounselingAppState();
}

class _CounselingAppState extends State<CounselingApp> {
  late final GoRouter _router;
  late final AuditLogger _auditLogger = AuditLogger(
    widget.db,
    currentAdminId: () => widget.authController.admin?.id,
  );
  late final StatsRepository _statsRepository = StatsRepository(widget.db);
  late final ClientRepository _clientRepository = ClientRepository(
    widget.db,
    auditLogger: _auditLogger,
  );
  late final AppointmentRepository _appointmentRepository =
      AppointmentRepository(widget.db, auditLogger: _auditLogger);
  late final SessionRepository _sessionRepository = SessionRepository(
    widget.db,
    auditLogger: _auditLogger,
  );
  late final FormSubmissionRepository _formSubmissionRepository =
      FormSubmissionRepository(widget.db, auditLogger: _auditLogger);
  late final InterventionRepository _interventionRepository =
      InterventionRepository(widget.db, auditLogger: _auditLogger);
  late final AuditLogRepository _auditLogRepository = AuditLogRepository(
    widget.db,
  );
  late final ReportRepository _reportRepository = ReportRepository(widget.db);
  late final SettingsRepository _settingsRepository = SettingsRepository(
    widget.db,
  );
  late final BackupService _backupService = BackupService(
    widget.db,
    widget.dbPath,
  );

  @override
  void initState() {
    super.initState();
    _router = _buildRouter(widget.authController);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  static GoRouter _buildRouter(AuthController auth) {
    return GoRouter(
      initialLocation: '/dashboard',
      refreshListenable: auth,
      redirect: (context, state) {
        final status = auth.status;
        final path = state.matchedLocation;
        final onAuthRoute =
            path == '/login' || path == '/setup' || path == '/lock';

        switch (status) {
          case AuthStatus.unknown:
            return null;
          case AuthStatus.needsSetup:
            return path == '/setup' ? null : '/setup';
          case AuthStatus.unauthenticated:
            return path == '/login' ? null : '/login';
          case AuthStatus.locked:
            return path == '/lock' ? null : '/lock';
          case AuthStatus.authenticated:
            if (onAuthRoute) return '/dashboard';
            return null;
        }
      },
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
        GoRoute(path: '/lock', builder: (_, _) => const LockScreen()),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const DashboardScreen(),
            ),
            GoRoute(path: '/clients', builder: (_, _) => const ClientsScreen()),
            GoRoute(
              path: '/appointments',
              builder: (_, _) => const AppointmentsScreen(),
            ),
            GoRoute(
              path: '/calendar',
              builder: (_, _) => const GuidanceCalendarScreen(),
            ),
            GoRoute(
              path: '/sessions',
              builder: (_, _) => const SessionsScreen(),
            ),
            GoRoute(
              path: '/interventions',
              builder: (_, _) => const InterventionsScreen(),
            ),
            GoRoute(
              path: '/forms',
              builder: (_, _) => const Scaffold(body: FormsScreen()),
              routes: [
                GoRoute(
                  path: ':formId',
                  builder: (context, state) {
                    final form = counselingFormById(
                      state.pathParameters['formId']!,
                    );
                    if (form == null) {
                      return const Scaffold(
                        body: Center(child: Text('Form not found.')),
                      );
                    }
                    final extra = state.extra;
                    return CounselingFormPage(
                      form: form,
                      submission: extra is FormSubmission ? extra : null,
                    );
                  },
                ),
              ],
            ),
            GoRoute(path: '/backup', builder: (_, _) => const BackupScreen()),
            GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
            GoRoute(
              path: '/audit-log',
              builder: (_, _) => const AuditLogScreen(),
            ),
            GoRoute(
              path: '/users',
              builder: (_, _) => const AdminManagementScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(
          value: widget.authController,
        ),
        Provider<StatsRepository>.value(value: _statsRepository),
        Provider<ClientRepository>.value(value: _clientRepository),
        Provider<AppointmentRepository>.value(value: _appointmentRepository),
        Provider<SessionRepository>.value(value: _sessionRepository),
        Provider<FormSubmissionRepository>.value(
          value: _formSubmissionRepository,
        ),
        Provider<InterventionRepository>.value(value: _interventionRepository),
        Provider<AuditLogRepository>.value(value: _auditLogRepository),
        Provider<ReportRepository>.value(value: _reportRepository),
        Provider<SettingsRepository>.value(value: _settingsRepository),
        Provider<BackupService>.value(value: _backupService),
        Provider<String>.value(value: widget.dbPath),
      ],
      child: MaterialApp.router(
        title: 'Counseling IS',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: _router,
      ),
    );
  }
}
