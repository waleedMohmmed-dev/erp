import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_erp/core/database/app_database.dart';
import 'package:web_erp/features/settings/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SettingsController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    controller = SettingsController(
      database: database,
      preferences: await SharedPreferences.getInstance(),
    );
    await controller.load();
  });

  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  test('loads defaults from the database', () {
    expect(controller.themeMode, ThemeMode.system);
    expect(controller.companyName, 'شركتي');
    expect(controller.currency, 'USD');
  });

  test('persists the theme mode in shared preferences', () async {
    await controller.setThemeMode(ThemeMode.dark);

    expect(controller.themeMode, ThemeMode.dark);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(SettingsController.themeModeKey), 'dark');
  });

  test('ignores redundant theme changes', () async {
    int notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setThemeMode(ThemeMode.system);

    expect(notifications, 0);
  });

  test('saves the company profile into the database', () async {
    await controller.setCompanyProfile(name: ' GrowFit ', currencyCode: 'egp');

    expect(controller.companyName, 'GrowFit');
    expect(controller.currency, 'EGP');
    expect(await database.readSetting('company_name'), 'GrowFit');
    expect(await database.readSetting('currency'), 'EGP');
  });

  test('rejects an empty company name', () {
    expect(
      controller.setCompanyProfile(name: '   ', currencyCode: 'USD'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('rejects an empty currency', () {
    expect(
      controller.setCompanyProfile(name: 'GrowFit', currencyCode: ' '),
      throwsA(isA<ArgumentError>()),
    );
  });
}
