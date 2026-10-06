import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({required this.database, required this.preferences});

  final AppDatabase database;
  final SharedPreferences preferences;

  static const String themeModeKey = 'ui.theme_mode';
  static const String companyNameKey = 'company_name';
  static const String currencyKey = 'currency';

  ThemeMode themeMode = ThemeMode.system;
  String companyName = 'شركتي';
  String currency = 'USD';

  Future<void> load() async {
    themeMode = ThemeMode.values.firstWhere(
      (ThemeMode mode) => mode.name == preferences.getString(themeModeKey),
      orElse: () => ThemeMode.system,
    );

    final Map<String, String> settings = await database.readSettings();
    companyName = settings[companyNameKey] ?? companyName;
    currency = settings[currencyKey] ?? currency;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == themeMode) {
      return;
    }
    themeMode = mode;
    notifyListeners();
    await preferences.setString(themeModeKey, mode.name);
  }

  Future<void> setCompanyProfile({
    required String name,
    required String currencyCode,
  }) async {
    final String trimmedName = name.trim();
    final String trimmedCurrency = currencyCode.trim().toUpperCase();

    if (trimmedName.isEmpty) {
      throw ArgumentError('اسم الشركة لا يمكن أن يكون فارغاً');
    }
    if (trimmedCurrency.isEmpty) {
      throw ArgumentError('العملة لا يمكن أن تكون فارغة');
    }
    if (trimmedCurrency.length > 6) {
      throw ArgumentError('رمز العملة طويل جداً');
    }

    await database.writeSettings(<String, String>{
      companyNameKey: trimmedName,
      currencyKey: trimmedCurrency,
    });

    companyName = trimmedName;
    currency = trimmedCurrency;
    notifyListeners();
  }
}
