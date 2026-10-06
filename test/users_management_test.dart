import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_erp/core/auth/auth_user.dart';
import 'package:web_erp/core/auth/user_role.dart';
import 'package:web_erp/core/database/app_database.dart';

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

  Future<AuthUser> admin() async {
    final AuthUser? user = await database.findUserByEmail('admin@growfit.erp');
    return user!;
  }

  test('creates a normalized user that can sign in', () async {
    final AuthUser created = await database.createUser(
      email: '  NewUser@Growfit.ERP ',
      password: 'Secret12',
      fullName: '  مستخدم جديد  ',
      role: UserRole.sales,
    );

    expect(created.email, 'newuser@growfit.erp');
    expect(created.fullName, 'مستخدم جديد');
    expect(created.role, UserRole.sales);
    expect(created.isActive, isTrue);
    expect(await database.countUsers(), 6);

    final AuthUser? signedIn = await database.authenticate(
      email: 'newuser@growfit.erp',
      password: 'Secret12',
    );
    expect(signedIn, isNotNull);
    expect(signedIn!.id, created.id);
  });

  test('rejects a duplicate email regardless of casing', () async {
    expect(
      () => database.createUser(
        email: 'SALES@growfit.erp',
        password: 'Secret12',
        fullName: 'مستخدم آخر',
        role: UserRole.sales,
      ),
      throwsA(
        isA<AppRuleException>().having(
          (AppRuleException error) => error.message,
          'message',
          'البريد الإلكتروني مستخدم بالفعل',
        ),
      ),
    );
  });

  test('validates the email, the name and the password', () async {
    expect(
      () => database.createUser(
        email: 'not-an-email',
        password: 'Secret12',
        fullName: 'مستخدم',
        role: UserRole.sales,
      ),
      throwsA(isA<AppRuleException>()),
    );
    expect(
      () => database.createUser(
        email: 'ok@growfit.erp',
        password: '123',
        fullName: 'مستخدم',
        role: UserRole.sales,
      ),
      throwsA(isA<AppRuleException>()),
    );
    expect(
      () => database.createUser(
        email: 'ok@growfit.erp',
        password: 'Secret12',
        fullName: '   ',
        role: UserRole.sales,
      ),
      throwsA(isA<AppRuleException>()),
    );
    expect(await database.countUsers(), 5);
  });

  test('updating a user keeps the password when none is given', () async {
    final AuthUser user = await database.createUser(
      email: 'keeper@growfit.erp',
      password: 'Secret12',
      fullName: 'أمين',
      role: UserRole.storekeeper,
    );

    final String token = await database.createSession(user.id);

    await database.updateUser(
      id: user.id,
      fullName: 'أمين المخزن',
      role: UserRole.manager,
    );

    final AuthUser? updated = await database.userById(user.id);
    expect(updated!.fullName, 'أمين المخزن');
    expect(updated.role, UserRole.manager);

    expect(await database.sessionUser(token), isNotNull);
    expect(
      await database.authenticate(
        email: 'keeper@growfit.erp',
        password: 'Secret12',
      ),
      isNotNull,
    );
  });

  test('changing the password revokes open sessions', () async {
    final AuthUser user = await database.createUser(
      email: 'change@growfit.erp',
      password: 'Secret12',
      fullName: 'يغيّر',
      role: UserRole.sales,
    );
    final String token = await database.createSession(user.id);

    await database.updateUser(id: user.id, password: 'NewPass45');

    expect(await database.sessionUser(token), isNull);
    expect(
      await database.authenticate(
        email: 'change@growfit.erp',
        password: 'Secret12',
      ),
      isNull,
    );
    expect(
      await database.authenticate(
        email: 'change@growfit.erp',
        password: 'NewPass45',
      ),
      isNotNull,
    );
  });

  test('protects the last active admin', () async {
    final AuthUser me = await admin();

    expect(
      () => database.updateUser(id: me.id, isActive: false),
      throwsA(
        isA<AppRuleException>().having(
          (AppRuleException error) => error.message,
          'message',
          'لا يمكن تعطيل أو تغيير دور آخر مدير نظام',
        ),
      ),
    );
    expect(
      () => database.updateUser(id: me.id, role: UserRole.manager),
      throwsA(isA<AppRuleException>()),
    );
    expect(
      () => database.deleteUser(me.id),
      throwsA(
        isA<AppRuleException>().having(
          (AppRuleException error) => error.message,
          'message',
          'لا يمكن حذف آخر مدير نظام',
        ),
      ),
    );

    final AuthUser second = await database.createUser(
      email: 'admin2@growfit.erp',
      password: 'Secret12',
      fullName: 'مدير آخر',
      role: UserRole.admin,
    );
    expect(await database.activeAdminCount(), 2);

    await database.updateUser(id: second.id, isActive: false);
    expect(await database.activeAdminCount(), 1);
  });

  test('deleting a user removes their sessions', () async {
    final AuthUser user = await database.createUser(
      email: 'gone@growfit.erp',
      password: 'Secret12',
      fullName: 'محذوف',
      role: UserRole.sales,
    );
    final String token = await database.createSession(user.id);

    await database.deleteUser(user.id);

    expect(await database.userById(user.id), isNull);
    expect(await database.sessionUser(token), isNull);
    expect(await database.countUsers(), 5);
    expect(
      () => database.deleteUser(user.id),
      throwsA(isA<AppRuleException>()),
    );
  });

  test('inactive users cannot sign in', () async {
    final AuthUser user = await database.createUser(
      email: 'blocked@growfit.erp',
      password: 'Secret12',
      fullName: 'موقوف',
      role: UserRole.sales,
      isActive: false,
    );

    expect(
      await database.authenticate(
        email: 'blocked@growfit.erp',
        password: 'Secret12',
      ),
      isNull,
    );

    await database.updateUser(id: user.id, isActive: true);
    expect(
      await database.authenticate(
        email: 'blocked@growfit.erp',
        password: 'Secret12',
      ),
      isNotNull,
    );
  });
}
