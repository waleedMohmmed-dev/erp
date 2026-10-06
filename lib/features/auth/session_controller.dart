import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_user.dart';
import '../../core/database/app_database.dart';

class SessionController extends ChangeNotifier {
  SessionController({required this.database, required this.preferences});

  final AppDatabase database;
  final SharedPreferences preferences;

  static const String tokenKey = 'auth.session_token';

  AuthUser? _user;
  String? _token;
  bool _restoring = true;
  bool _busy = false;

  AuthUser? get user => _user;
  String? get token => _token;
  bool get restoring => _restoring;
  bool get busy => _busy;
  bool get isAuthenticated => _user != null;

  Future<void> restore() async {
    try {
      _token = preferences.getString(tokenKey);
      _user = await database.sessionUser(_token);
      if (_user == null && _token != null) {
        _token = null;
        await preferences.remove(tokenKey);
      }
      await database.deleteExpiredSessions();
    } catch (_) {
      _user = null;
      _token = null;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<String?> login({
    required String email,
    required String password,
    bool remember = true,
  }) async {
    if (_busy) {
      return null;
    }
    _busy = true;
    notifyListeners();

    try {
      final AuthUser? user = await database.authenticate(
        email: email,
        password: password,
      );
      if (user == null) {
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      }

      final String token = await database.createSession(user.id);
      _token = token;
      _user = user;
      _restoring = false;

      if (remember) {
        await preferences.setString(tokenKey, token);
      } else {
        await preferences.remove(tokenKey);
      }

      notifyListeners();
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final String? current = _token;
    _user = null;
    _token = null;
    await preferences.remove(tokenKey);
    notifyListeners();

    if (current != null) {
      try {
        await database.deleteSession(current);
      } catch (_) {
        return;
      }
    }
  }
}
