import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_info.dart';
import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/session_controller.dart';
import 'features/permissions/permissions_controller.dart';
import 'features/settings/settings_controller.dart';
import 'routing/app_router.dart';
import 'routing/app_routes.dart';

class WebErpApp extends StatelessWidget {
  const WebErpApp({
    super.key,
    required this.database,
    required this.settings,
    required this.session,
    required this.permissions,
  });

  final AppDatabase database;
  final SettingsController settings;
  final SessionController session;
  final PermissionsController permissions;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<SessionController>.value(value: session),
        ChangeNotifierProvider<PermissionsController>.value(value: permissions),
      ],
      child: const _ErpMaterialApp(),
    );
  }
}

class _ErpMaterialApp extends StatefulWidget {
  const _ErpMaterialApp();

  @override
  State<_ErpMaterialApp> createState() => _ErpMaterialAppState();
}

class _ErpMaterialAppState extends State<_ErpMaterialApp> {
  late final AppRouterDelegate _routerDelegate;
  late final PlatformRouteInformationProvider _routeInformationProvider;

  @override
  void initState() {
    super.initState();
    final String initialLocation =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final Uri initialUri = Uri.parse(
      initialLocation.isEmpty ? '/' : initialLocation,
    );

    _routeInformationProvider = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: initialUri),
    );
    _routerDelegate = AppRouterDelegate(
      initialLocation: AppRoutes.fromUri(initialUri),
    );
  }

  @override
  void dispose() {
    _routeInformationProvider.dispose();
    _routerDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = context.select<SettingsController, ThemeMode>(
      (SettingsController controller) => controller.themeMode,
    );

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerDelegate: _routerDelegate,
      routeInformationParser: const AppRouteInformationParser(),
      routeInformationProvider: _routeInformationProvider,
    );
  }
}
