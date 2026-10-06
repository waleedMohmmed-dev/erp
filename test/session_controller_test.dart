import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_erp/core/auth/user_role.dart';
import 'package:web_erp/core/database/app_database.dart';
import 'package:web_erp/features/auth/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SharedPreferences preferences;
  late SessionController session;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    preferences = await SharedPreferences.getInstance();
    session = SessionController(database: database, preferences: preferences);
    await session.restore();
  });

  tearDown(() async {
    session.dispose();
    await database.close();
  });

  test('starts signed out after restoring', () {
    expect(session.restoring, isFalse);
    expect(session.isAuthenticated, isFalse);
    expect(session.user, isNull);
  });

  test('signs in and remembers the account', () async {
    final String? error = await session.login(
      email: 'accountant@growfit.erp',
      password: 'Account@1234',
    );

    expect(error, isNull);
    expect(session.isAuthenticated, isTrue);
    expect(session.user!.role, UserRole.accountant);
    expect(session.token, isNotNull);
    expect(preferences.getString(SessionController.tokenKey), session.token);
  });

  test('reports invalid credentials without opening a session', () async {
    final String? error = await session.login(
      email: 'accountant@growfit.erp',
      password: 'wrong-password',
    );

    expect(error, 'البريد الإلكتروني أو كلمة المرور غير صحيحة');
    expect(session.isAuthenticated, isFalse);
    expect(session.token, isNull);
    expect(preferences.getString(SessionController.tokenKey), isNull);
  });

  test('restores the session from the stored token', () async {
    await session.login(email: 'sales@growfit.erp', password: 'Sales@1234');

    final SessionController restored = SessionController(
      database: database,
      preferences: preferences,
    );
    await restored.restore();

    expect(restored.isAuthenticated, isTrue);
    expect(restored.user!.email, 'sales@growfit.erp');
    expect(restored.user!.role, UserRole.sales);

    restored.dispose();
  });

  test(
    'keeps a signed in guest out of preferences when remember is off',
    () async {
      final String? error = await session.login(
        email: 'store@growfit.erp',
        password: 'Store@1234',
        remember: false,
      );

      expect(error, isNull);
      expect(session.isAuthenticated, isTrue);
      expect(preferences.getString(SessionController.tokenKey), isNull);
    },
  );

  test('logout clears the user, the token and the stored session', () async {
    await session.login(email: 'manager@growfit.erp', password: 'Manager@1234');
    final String token = session.token!;

    await session.logout();

    expect(session.isAuthenticated, isFalse);
    expect(session.token, isNull);
    expect(preferences.getString(SessionController.tokenKey), isNull);
    expect(await database.sessionUser(token), isNull);
  });

  test('an expired stored token is ignored on restore', () async {
    final user = (await database.authenticate(
      email: 'admin@growfit.erp',
      password: 'Admin@1234',
    ))!;
    final String token = await database.createSession(
      user.id,
      ttl: const Duration(seconds: -1),
    );
    await preferences.setString(SessionController.tokenKey, token);

    final SessionController restored = SessionController(
      database: database,
      preferences: preferences,
    );
    await restored.restore();

    expect(restored.isAuthenticated, isFalse);
    expect(preferences.getString(SessionController.tokenKey), isNull);

    restored.dispose();
  });
}
