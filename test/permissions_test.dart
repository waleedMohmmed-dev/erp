import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_erp/core/auth/permission_action.dart';
import 'package:web_erp/core/auth/permission_defaults.dart';
import 'package:web_erp/core/auth/user_role.dart';
import 'package:web_erp/core/database/app_database.dart';
import 'package:web_erp/features/permissions/permissions_controller.dart';
import 'package:web_erp/routing/app_routes.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late PermissionsController permissions;

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    permissions = PermissionsController(database: database);
    await permissions.load();
  });

  tearDown(() async {
    permissions.dispose();
    await database.close();
  });

  test('seeds the default matrix into the database', () async {
    final List<PermissionGrant> rows = await database.listPermissions();

    expect(rows.length, PermissionDefaults.seedRows().length);
    expect(rows.every((PermissionGrant row) => row.allowed), isTrue);
    expect(
      rows.map((PermissionGrant row) => row.role),
      contains(UserRole.storekeeper.id),
    );
  });

  test('serves the default grants for each role', () {
    expect(
      permissions.can('sales', AppRoutes.dashboard, PermissionAction.view),
      isTrue,
    );
    expect(
      permissions.can('sales', AppRoutes.settings, PermissionAction.view),
      isFalse,
    );
    expect(
      permissions.can(
        'storekeeper',
        AppRoutes.inventory,
        PermissionAction.delete,
      ),
      isTrue,
    );
    expect(
      permissions.can('manager', AppRoutes.users, PermissionAction.create),
      isTrue,
    );
    expect(
      permissions.can('manager', AppRoutes.users, PermissionAction.delete),
      isFalse,
    );
    expect(
      permissions.can('sales', '/unknown-page', PermissionAction.view),
      isFalse,
    );
  });

  test('keeps the admin role fully privileged', () async {
    await permissions.set(
      role: UserRole.admin.id,
      resource: AppRoutes.settings,
      action: PermissionAction.edit,
      allowed: false,
    );

    expect(
      permissions.can('admin', AppRoutes.settings, PermissionAction.edit),
      isTrue,
    );
    expect(
      permissions.can('admin', AppRoutes.permissions, PermissionAction.delete),
      isTrue,
    );

    expect(
      () => database.setPermission(
        role: UserRole.admin.id,
        resource: AppRoutes.settings,
        action: PermissionAction.edit.id,
        allowed: false,
      ),
      throwsA(isA<AppRuleException>()),
    );
  });

  test('granting an action implies the view action', () async {
    expect(
      permissions.can('sales', AppRoutes.reports, PermissionAction.view),
      isFalse,
    );

    await permissions.set(
      role: 'sales',
      resource: AppRoutes.reports,
      action: PermissionAction.edit,
      allowed: true,
    );

    expect(
      permissions.can('sales', AppRoutes.reports, PermissionAction.view),
      isTrue,
    );

    final List<PermissionGrant> rows = await database.listPermissions();
    expect(
      rows
          .where(
            (PermissionGrant row) =>
                row.role == 'sales' &&
                row.resource == AppRoutes.reports &&
                row.action == PermissionAction.view.id,
          )
          .length,
      1,
    );
  });

  test('keeps view while another action is granted', () async {
    await permissions.set(
      role: 'sales',
      resource: AppRoutes.partners,
      action: PermissionAction.edit,
      allowed: true,
    );

    await permissions.set(
      role: 'sales',
      resource: AppRoutes.partners,
      action: PermissionAction.view,
      allowed: false,
    );

    expect(
      permissions.can('sales', AppRoutes.partners, PermissionAction.view),
      isTrue,
    );
    expect(
      permissions.can('sales', AppRoutes.partners, PermissionAction.edit),
      isTrue,
    );
  });

  test('persists changes across reloads', () async {
    await permissions.set(
      role: 'sales',
      resource: AppRoutes.inventory,
      action: PermissionAction.view,
      allowed: true,
    );

    final PermissionsController reloaded = PermissionsController(
      database: database,
    );
    await reloaded.load();
    expect(
      reloaded.can('sales', AppRoutes.inventory, PermissionAction.view),
      isTrue,
    );

    await reloaded.set(
      role: 'sales',
      resource: AppRoutes.inventory,
      action: PermissionAction.view,
      allowed: false,
    );

    final PermissionsController again = PermissionsController(
      database: database,
    );
    await again.load();
    expect(
      again.can('sales', AppRoutes.inventory, PermissionAction.view),
      isFalse,
    );

    reloaded.dispose();
    again.dispose();
  });

  test('reset restores the default matrix', () async {
    await permissions.set(
      role: 'sales',
      resource: AppRoutes.settings,
      action: PermissionAction.view,
      allowed: true,
    );
    expect(
      permissions.can('sales', AppRoutes.settings, PermissionAction.view),
      isTrue,
    );

    await permissions.resetToDefaults();

    expect(
      permissions.can('sales', AppRoutes.settings, PermissionAction.view),
      isFalse,
    );
    expect(
      permissions.can('sales', AppRoutes.sales, PermissionAction.create),
      isTrue,
    );
    expect(
      (await database.listPermissions()).length,
      PermissionDefaults.seedRows().length,
    );
  });
}
