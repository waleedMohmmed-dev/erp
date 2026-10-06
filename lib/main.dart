import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'bootstrap_error_app.dart';
import 'core/database/app_database.dart';
import 'features/auth/session_controller.dart';
import 'features/permissions/permissions_controller.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrap();
}

Future<void> _bootstrap() async {
  try {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AppDatabase database = await AppDatabase.open();
    final SettingsController settings = SettingsController(
      database: database,
      preferences: preferences,
    );
    await settings.load();
    final SessionController session = SessionController(
      database: database,
      preferences: preferences,
    );
    await session.restore();
    final PermissionsController permissions = PermissionsController(
      database: database,
    );
    await permissions.load();
    runApp(
      WebErpApp(
        database: database,
        settings: settings,
        session: session,
        permissions: permissions,
      ),
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace),
    );
    runApp(BootstrapErrorApp(error: error, onRetry: _bootstrap));
  }
}
