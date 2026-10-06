import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_erp/core/auth/auth_user.dart';
import 'package:web_erp/core/auth/password_hasher.dart';
import 'package:web_erp/core/auth/permission_action.dart';
import 'package:web_erp/core/auth/permission_defaults.dart';
import 'package:web_erp/core/auth/seed_users.dart';
import 'package:web_erp/core/auth/user_role.dart';
import 'package:web_erp/core/database/app_database.dart';
import 'package:web_erp/routing/app_routes.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('seeds one account per role', () async {
    expect(await database.countUsers(), SeedUsers.all.length);

    final List<AuthUser> users = await database.listUsers();
    expect(users.map((AuthUser user) => user.role), contains(UserRole.admin));
    expect(users.map((AuthUser user) => user.role), contains(UserRole.manager));
    expect(
      users.map((AuthUser user) => user.role),
      contains(UserRole.accountant),
    );
    expect(
      users.map((AuthUser user) => user.role),
      contains(UserRole.storekeeper),
    );
    expect(users.map((AuthUser user) => user.role), contains(UserRole.sales));
  });

  test('authenticates a seeded account', () async {
    final AuthUser? user = await database.authenticate(
      email: 'Admin@Growfit.ERP ',
      password: 'Admin@1234',
    );

    expect(user, isNotNull);
    expect(user!.role, UserRole.admin);
    expect(user.fullName, 'محمد إبراهيم');
    expect(user.isActive, isTrue);
    expect(user.lastLoginAt, isNotNull);
  });

  test('rejects a wrong password and an unknown email', () async {
    expect(
      await database.authenticate(email: 'admin@growfit.erp', password: 'nope'),
      isNull,
    );
    expect(
      await database.authenticate(
        email: 'ghost@growfit.erp',
        password: 'Admin@1234',
      ),
      isNull,
    );
  });

  test('hashes passwords with a unique salt', () {
    final String saltA = PasswordHasher.randomSalt();
    final String saltB = PasswordHasher.randomSalt();

    expect(saltA, isNot(saltB));
    expect(PasswordHasher.hash('Admin@1234', saltA), isNot('Admin@1234'));
    expect(
      PasswordHasher.hash('Admin@1234', saltA),
      PasswordHasher.hash('Admin@1234', saltA),
    );
    expect(
      PasswordHasher.hash('Admin@1234', saltA),
      isNot(PasswordHasher.hash('Admin@1234', saltB)),
    );
    expect(
      PasswordHasher.verify(
        password: 'Admin@1234',
        salt: saltA,
        expectedHash: PasswordHasher.hash('Admin@1234', saltA),
      ),
      isTrue,
    );
    expect(
      PasswordHasher.verify(
        password: 'wrong',
        salt: saltA,
        expectedHash: PasswordHasher.hash('Admin@1234', saltA),
      ),
      isFalse,
    );
  });

  test('creates and validates a session token', () async {
    final AuthUser user = (await database.authenticate(
      email: 'store@growfit.erp',
      password: 'Store@1234',
    ))!;

    final String token = await database.createSession(user.id);
    final AuthUser? restored = await database.sessionUser(token);

    expect(restored, isNotNull);
    expect(restored!.id, user.id);
    expect(restored.role, UserRole.storekeeper);

    await database.deleteSession(token);
    expect(await database.sessionUser(token), isNull);
  });

  test('ignores expired session tokens', () async {
    final AuthUser user = (await database.authenticate(
      email: 'sales@growfit.erp',
      password: 'Sales@1234',
    ))!;

    final String token = await database.createSession(
      user.id,
      ttl: const Duration(seconds: -1),
    );

    expect(await database.sessionUser(token), isNull);
    await database.deleteExpiredSessions();
  });

  group('role permissions', () {
    test('admin and manager open every page', () {
      for (final String path in AppRoutes.all.where(
        (String path) => path != AppRoutes.login,
      )) {
        expect(UserRole.admin.canAccess(path), isTrue, reason: path);
        expect(UserRole.manager.canAccess(path), isTrue, reason: path);
      }
    });

    test('accountant, storekeeper and sales are limited', () {
      expect(UserRole.accountant.canAccess(AppRoutes.reports), isTrue);
      expect(UserRole.accountant.canAccess(AppRoutes.inventory), isTrue);
      expect(UserRole.accountant.canAccess(AppRoutes.users), isFalse);
      expect(UserRole.accountant.canAccess(AppRoutes.permissions), isFalse);

      expect(UserRole.storekeeper.canAccess(AppRoutes.inventory), isTrue);
      expect(UserRole.storekeeper.canAccess(AppRoutes.purchases), isTrue);
      expect(UserRole.storekeeper.canAccess(AppRoutes.settings), isFalse);
      expect(UserRole.storekeeper.canAccess(AppRoutes.users), isFalse);

      expect(UserRole.sales.canAccess(AppRoutes.sales), isTrue);
      expect(UserRole.sales.canAccess(AppRoutes.partners), isTrue);
      expect(UserRole.sales.canAccess(AppRoutes.inventory), isFalse);
      expect(UserRole.sales.canAccess(AppRoutes.settings), isFalse);
      expect(UserRole.sales.canAccess(AppRoutes.users), isFalse);
    });

    test('every role reaches the dashboard and the login page', () {
      for (final UserRole role in UserRole.values) {
        expect(role.canAccess(AppRoutes.dashboard), isTrue, reason: role.id);
        expect(role.canAccess(AppRoutes.login), isTrue, reason: role.id);
      }
    });

    test('actions are granted per role and page', () {
      expect(
        PermissionDefaults.can(
          UserRole.accountant,
          AppRoutes.inventory,
          PermissionAction.create,
        ),
        isFalse,
      );
      expect(
        PermissionDefaults.can(
          UserRole.accountant,
          AppRoutes.partners,
          PermissionAction.edit,
        ),
        isTrue,
      );
      expect(
        PermissionDefaults.can(
          UserRole.storekeeper,
          AppRoutes.inventory,
          PermissionAction.delete,
        ),
        isTrue,
      );
      expect(
        PermissionDefaults.can(
          UserRole.sales,
          AppRoutes.sales,
          PermissionAction.create,
        ),
        isTrue,
      );
      expect(
        PermissionDefaults.can(
          UserRole.sales,
          AppRoutes.sales,
          PermissionAction.delete,
        ),
        isFalse,
      );
      expect(
        PermissionDefaults.can(
          UserRole.manager,
          AppRoutes.users,
          PermissionAction.create,
        ),
        isTrue,
      );
      expect(
        PermissionDefaults.can(
          UserRole.manager,
          AppRoutes.users,
          PermissionAction.delete,
        ),
        isFalse,
      );
      expect(
        PermissionDefaults.can(
          UserRole.admin,
          AppRoutes.permissions,
          PermissionAction.delete,
        ),
        isTrue,
      );
    });
  });
}
