import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_erp/core/database/app_database.dart';
import 'package:web_erp/core/inventory/inventory_models.dart';

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

  test('creates the phase 0 schema with default settings', () async {
    expect(database.fileName, inMemoryDatabasePath);
    expect(await database.schemaVersion(), 5);
    expect(await database.readSetting('company_name'), 'شركتي');
    expect(await database.readSetting('currency'), 'USD');
    expect(await database.readSetting('missing_key'), isNull);
  });

  test('writes and reads settings', () async {
    await database.writeSettings(<String, String>{
      'company_name': 'GrowFit',
      'currency': 'EGP',
    });

    expect(await database.readSetting('company_name'), 'GrowFit');

    final Map<String, String> all = await database.readSettings();
    expect(all['currency'], 'EGP');
    expect(all['company_name'], 'GrowFit');
    expect(all.length, 3);
  });

  test('overwrites a single setting without losing the others', () async {
    await database.writeSetting('currency', 'EUR');

    final Map<String, String> all = await database.readSettings();
    expect(all['currency'], 'EUR');
    expect(all['company_name'], 'شركتي');
    expect(all.length, 3);
  });

  test('reports a healthy overview of the created tables', () async {
    final DatabaseOverview overview = await database.overview();

    expect(overview.isHealthy, isTrue);
    expect(overview.integrity.toLowerCase(), 'ok');
    expect(overview.schemaVersion, 5);
    expect(
      overview.tables.map((TableStat table) => table.name),
      contains('app_settings'),
    );
    expect(
      overview.tables.map((TableStat table) => table.name),
      contains('users'),
    );
    expect(
      overview.tables.map((TableStat table) => table.name),
      contains('role_permissions'),
    );
    expect(
      overview.tables.map((TableStat table) => table.name),
      contains('user_sessions'),
    );
    expect(
      overview.tables.map((TableStat table) => table.name),
      contains('categories'),
    );
    expect(
      overview.tables.map((TableStat table) => table.name),
      contains('units'),
    );
    expect(
      overview.tables.map((TableStat table) => table.name),
      contains('products'),
    );
    expect(
      overview.tables.map((TableStat table) => table.name),
      contains('stock_movements'),
    );
    expect(overview.totalRows, greaterThanOrEqualTo(3));
  });

  test('migrates a phase 0 database to the current schema', () async {
    final String path =
        'web_erp_migrate_${DateTime.now().millisecondsSinceEpoch}.db';

    final Database phase0 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (Database db, int version) async {
          await db.execute(
            'CREATE TABLE app_settings ('
            'setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL)',
          );
          await db.insert('app_settings', <String, Object>{
            'setting_key': 'company_name',
            'setting_value': 'Phase0 Co',
          });
        },
      ),
    );
    await phase0.close();

    final AppDatabase upgraded = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );

    expect(await upgraded.schemaVersion(), 5);
    expect(await upgraded.readSetting('company_name'), 'Phase0 Co');
    expect(await upgraded.countUsers(), greaterThan(0));
    expect((await upgraded.listPermissions()).length, greaterThan(0));
    expect(
      await upgraded.authenticate(
        email: 'admin@growfit.erp',
        password: 'Admin@1234',
      ),
      isNotNull,
    );
    expect((await upgraded.listCategories()).length, greaterThan(0));
    expect((await upgraded.listUnits()).length, greaterThan(0));
    expect(
      (await upgraded.listProducts(const ProductQuery())).total,
      greaterThan(0),
    );

    await upgraded.close();
    await databaseFactoryFfi.deleteDatabase(path);
  });

  test('keeps data when reopening the same database file', () async {
    final String path =
        'web_erp_test_${DateTime.now().millisecondsSinceEpoch}.db';
    final AppDatabase first = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    await first.writeSetting('company_name', 'Reopened Co');
    await first.close();

    final AppDatabase second = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    expect(await second.readSetting('company_name'), 'Reopened Co');
    await second.close();

    await databaseFactoryFfi.deleteDatabase(path);
  });
}
