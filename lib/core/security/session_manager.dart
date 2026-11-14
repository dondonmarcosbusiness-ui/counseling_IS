import 'dart:async';

import 'package:flutter/foundation.dart';

class SessionManager extends ChangeNotifier {
  SessionManager({required this.onLock, this.idleTimeout = defaultIdleTimeout});

  static const defaultIdleTimeout = Duration(minutes: 15);

  Duration idleTimeout;
  void Function() onLock;

  Timer? _timer;
  bool _locked = true;

  bool get isLocked => _locked;

  void unlock() {
    _locked = false;
    _restartTimer();
    notifyListeners();
  }

  void lock() {
    _timer?.cancel();
    _timer = null;
    if (_locked) return;
    _locked = true;
    notifyListeners();
    onLock();
  }

  void noteActivity() {
    if (!_locked) _restartTimer();
  }

  void updateTimeout(Duration value) {
    idleTimeout = value;
    if (!_locked) _restartTimer();
    notifyListeners();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(idleTimeout, lock);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
