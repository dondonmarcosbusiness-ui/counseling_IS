import 'dart:async';

import 'package:counseling_is/core/errors/app_exception.dart';
import 'package:counseling_is/core/security/session_manager.dart';
import 'package:counseling_is/core/validation/validators.dart' as validators;
import 'package:counseling_is/features/auth/data/auth_repository.dart';
import 'package:flutter/foundation.dart';

enum AuthStatus { unknown, needsSetup, unauthenticated, authenticated, locked }

class AuthController extends ChangeNotifier {
  AuthController(
    this._repo, {
    SessionManager? session,
    this.maxFailedAttempts = 5,
    this.throttleDelay = const Duration(seconds: 30),
  }) : session =
           session ??
           SessionManager(onLock: () {}, idleTimeout: idleTimeoutDefault) {
    this.session.onLock = _handleAutoLock;
  }

  static const idleTimeoutDefault = SessionManager.defaultIdleTimeout;

  final AuthRepository _repo;
  final SessionManager session;
  final int maxFailedAttempts;
  final Duration throttleDelay;

  AuthStatus _status = AuthStatus.unknown;
  AdminAccount? _admin;
  String? _errorMessage;
  int _failedAttempts = 0;
  DateTime? _throttleUntil;

  AuthStatus get status => _status;
  AdminAccount? get admin => _admin;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> init() async {
    final hasAdmin = await _repo.hasAdmin();
    _status = hasAdmin ? AuthStatus.unauthenticated : AuthStatus.needsSetup;
    notifyListeners();
  }

  Future<String?> setup({
    required String username,
    required String fullName,
    required String password,
    required String confirmPassword,
  }) async {
    _errorMessage = null;
    final usernameError = validators.username(username);
    if (usernameError != null) return _fail(usernameError);
    if (fullName.trim().isEmpty) return _fail('Full name is required');
    final passwordError = validators.passwordStrength(password);
    if (passwordError != null) return _fail(passwordError);
    if (password != confirmPassword) {
      return _fail('Passwords do not match');
    }
    try {
      final admin = await _repo.createAdmin(
        username: username.trim(),
        fullName: fullName.trim(),
        password: password,
      );
      _admin = admin;
      _status = AuthStatus.authenticated;
      session.unlock();
      notifyListeners();
      return null;
    } on DuplicateException catch (e) {
      return _fail(e.message);
    } on AppException catch (e) {
      return _fail(e.message);
    }
  }

  Future<String?> login(String username, String password) async {
    _errorMessage = null;
    if (username.trim().isEmpty) return _fail('Username is required');
    if (password.isEmpty) return _fail('Password is required');

    final throttleError = _checkThrottle();
    if (throttleError != null) return throttleError;

    final admin = await _repo.verifyCredentials(username, password);
    if (admin == null) {
      _failedAttempts++;
      if (_failedAttempts >= maxFailedAttempts) {
        _throttleUntil = DateTime.now().add(throttleDelay);
        final attempts = _failedAttempts;
        _failedAttempts = 0;
        return _fail(
          'Too many failed attempts. Try again in '
          '${throttleDelay.inSeconds} seconds. '
          '($attempts failed attempts recorded.)',
        );
      }
      final remaining = maxFailedAttempts - _failedAttempts;
      return _fail(
        'Invalid username or password. $remaining attempt(s) remaining.',
      );
    }

    _failedAttempts = 0;
    _throttleUntil = null;
    _admin = admin;
    _status = AuthStatus.authenticated;
    session.unlock();
    notifyListeners();
    return null;
  }

  Future<String?> unlock(String password) async {
    _errorMessage = null;
    if (_admin == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'Session expired. Please sign in again.';
    }
    final admin = await _repo.verifyCredentials(_admin!.username, password);
    if (admin == null) {
      return _fail('Incorrect password');
    }
    _admin = admin;
    _status = AuthStatus.authenticated;
    session.unlock();
    notifyListeners();
    return null;
  }

  void logout() {
    _status = AuthStatus.unauthenticated;
    session.lock();
    _admin = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _errorMessage = null;
    final admin = _admin;
    if (admin == null) return _fail('Not signed in');
    final strengthError = validators.passwordStrength(newPassword);
    if (strengthError != null) return _fail(strengthError);
    if (newPassword != confirmPassword) {
      return _fail('Passwords do not match');
    }

    try {
      await _repo.changePassword(
        adminId: admin.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } on AppException catch (e) {
      return _fail(e.message);
    }
  }

  Future<String?> createManagedAdmin({
    required String username,
    required String fullName,
    required String password,
    required String confirmPassword,
  }) async {
    final current = _admin;
    if (current == null) return _fail('Not signed in');
    final usernameError = validators.username(username);
    if (usernameError != null) return _fail(usernameError);
    if (fullName.trim().isEmpty) return _fail('Full name is required');
    final passwordError = validators.passwordStrength(password);
    if (passwordError != null) return _fail(passwordError);
    if (password != confirmPassword) {
      return _fail('Passwords do not match');
    }
    try {
      await _repo.createAdmin(
        username: username.trim(),
        fullName: fullName.trim(),
        password: password,
        createdByAdminId: current.id,
      );
      return null;
    } on AppException catch (error) {
      return _fail(error.message);
    }
  }

  Future<List<AdminAccount>> listManagedAdmins() => _repo.listAdmins();

  Future<String?> setManagedAdminActive({
    required int adminId,
    required bool isActive,
  }) async {
    final current = _admin;
    if (current == null) return _fail('Not signed in');
    try {
      await _repo.setAdminActive(
        adminId: adminId,
        isActive: isActive,
        requestingAdminId: current.id,
      );
      return null;
    } on AppException catch (error) {
      return _fail(error.message);
    }
  }

  void noteActivity() => session.noteActivity();

  String? _checkThrottle() {
    final until = _throttleUntil;
    if (until == null) return null;
    final now = DateTime.now();
    if (now.isBefore(until)) {
      final seconds = until.difference(now).inSeconds + 1;
      _errorMessage =
          'Too many failed attempts. Try again in $seconds seconds.';
      notifyListeners();
      return _errorMessage;
    }
    _throttleUntil = null;
    return null;
  }

  void _handleAutoLock() {
    if (_status == AuthStatus.authenticated) {
      _status = AuthStatus.locked;
      _errorMessage = null;
      notifyListeners();
    }
  }

  String _fail(String message) {
    _errorMessage = message;
    notifyListeners();
    return message;
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }
}
