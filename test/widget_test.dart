import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_erp/app.dart';
import 'package:web_erp/core/auth/permission_action.dart';
import 'package:web_erp/core/auth/seed_users.dart';
import 'package:web_erp/core/database/app_database.dart';
import 'package:web_erp/core/widgets/no_access_page.dart';
import 'package:web_erp/features/auth/login_page.dart';
import 'package:web_erp/features/auth/session_controller.dart';
import 'package:web_erp/features/permissions/permissions_controller.dart';
import 'package:web_erp/features/settings/settings_controller.dart';
import 'package:web_erp/routing/app_router.dart';
import 'package:web_erp/routing/app_routes.dart';
import 'package:web_erp/shell/side_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SettingsController settings;
  late SessionController session;
  late PermissionsController permissions;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    settings = SettingsController(
      database: database,
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.load();
    session = SessionController(
      database: database,
      preferences: await SharedPreferences.getInstance(),
    );
    await session.restore();
    permissions = PermissionsController(database: database);
    await permissions.load();
  });

  tearDown(() async {
    session.dispose();
    settings.dispose();
    permissions.dispose();
    await database.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      WebErpApp(
        database: database,
        settings: settings,
        session: session,
        permissions: permissions,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signInAsAdmin() {
    return session.login(
      email: SeedUsers.all.first.email,
      password: SeedUsers.all.first.password,
    );
  }

  Finder menuItem(String label) =>
      find.descendant(of: find.byType(SideMenu), matching: find.text(label));

  testWidgets('shows the login page without a session', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      find.text('أدخل بيانات حسابك للوصول إلى مساحة العمل'),
      findsOneWidget,
    );
    expect(
      find.text('حالة مساحة العمل المقروءة من قاعدة البيانات المحلية'),
      findsNothing,
    );
  });

  testWidgets('rejects a wrong password and then signs in', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'admin@growfit.erp',
    );
    await tester.enterText(find.byType(TextField).at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(
      find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة'),
      findsOneWidget,
    );
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'Admin@1234');
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(
      find.text('حالة مساحة العمل المقروءة من قاعدة البيانات المحلية'),
      findsOneWidget,
    );
    expect(session.isAuthenticated, isTrue);
  });

  testWidgets('boots into the dashboard with the desktop shell', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);

    expect(find.text('لوحة التحكم'), findsWidgets);
    expect(
      find.text('حالة مساحة العمل المقروءة من قاعدة البيانات المحلية'),
      findsOneWidget,
    );
    expect(menuItem('المخزون'), findsOneWidget);
    expect(menuItem('المبيعات'), findsOneWidget);
    expect(find.text('قاعدة محلية'), findsOneWidget);

    await tester.ensureVisible(find.text('خارطة طريق المشروع'));
    expect(find.text('الأساس'), findsOneWidget);
  });

  testWidgets('navigates between menu destinations', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);

    await tester.tap(menuItem('المخزون'));
    await tester.pumpAndSettle();
    expect(find.text('بروتين مصل اللبن 1 كجم'), findsOneWidget);
    expect(find.text('عرض 1–8 من 8 منتج'), findsOneWidget);
    expect(
      find.text('المنتجات والتصنيفات والوحدات وحركات المخزون'),
      findsWidgets,
    );

    await tester.tap(menuItem('المبيعات'));
    await tester.pumpAndSettle();
    expect(find.text('فواتير المبيعات'), findsOneWidget);
    expect(find.text('لا توجد فواتير مطابقة للبحث'), findsOneWidget);
    expect(find.text('فاتورة جديدة'), findsOneWidget);

    await tester.tap(menuItem('لوحة التحكم'));
    await tester.pumpAndSettle();
    expect(
      find.text('حالة مساحة العمل المقروءة من قاعدة البيانات المحلية'),
      findsOneWidget,
    );
  });

  testWidgets('filters the menu for the signed in role', (
    WidgetTester tester,
  ) async {
    await session.login(email: 'sales@growfit.erp', password: 'Sales@1234');
    await pumpApp(tester);

    expect(menuItem('المبيعات'), findsOneWidget);
    expect(menuItem('الشركاء'), findsOneWidget);
    expect(menuItem('المخزون'), findsNothing);
    expect(menuItem('المشتريات'), findsNothing);
    expect(menuItem('التقارير'), findsNothing);
    expect(menuItem('الإعدادات'), findsNothing);
    expect(find.text('ياسر سمير'), findsOneWidget);
    expect(find.text('مندوب مبيعات'), findsOneWidget);
  });

  testWidgets('shows user and permission management to the admin', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);

    expect(menuItem('المستخدمون'), findsOneWidget);
    expect(menuItem('الصلاحيات'), findsOneWidget);

    await tester.tap(menuItem('المستخدمون'));
    await tester.pumpAndSettle();

    expect(find.text('إضافة مستخدم'), findsOneWidget);
    expect(find.text('admin@growfit.erp'), findsOneWidget);
    expect(find.text('sales@growfit.erp'), findsOneWidget);
  });

  testWidgets('hides management pages from the sales role', (
    WidgetTester tester,
  ) async {
    await session.login(email: 'sales@growfit.erp', password: 'Sales@1234');
    await pumpApp(tester);

    expect(menuItem('المستخدمون'), findsNothing);
    expect(menuItem('الصلاحيات'), findsNothing);
  });

  testWidgets('creates a user from the users page', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);

    await tester.tap(menuItem('المستخدمون'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'إضافة مستخدم'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(3));
    await tester.enterText(find.byType(TextField).at(0), 'مستخدم تجريبي');
    await tester.enterText(find.byType(TextField).at(1), 'trial@growfit.erp');
    await tester.enterText(find.byType(TextField).at(2), 'Trial123');

    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('trial@growfit.erp'), findsOneWidget);
    expect(await database.countUsers(), 6);
    expect(
      await database.authenticate(
        email: 'trial@growfit.erp',
        password: 'Trial123',
      ),
      isNotNull,
    );
  });

  testWidgets('toggles a permission in the matrix', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);

    await tester.tap(menuItem('الصلاحيات'));
    await tester.pumpAndSettle();

    expect(find.text('جدول الإجراءات'), findsOneWidget);
    expect(
      permissions.can('manager', AppRoutes.reports, PermissionAction.create),
      isFalse,
    );

    final Finder cell = find.byKey(
      const ValueKey<String>('perm|${AppRoutes.reports}|create'),
    );
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    await tester.pumpAndSettle();

    expect(
      permissions.can('manager', AppRoutes.reports, PermissionAction.create),
      isTrue,
    );
    expect(
      permissions.can('manager', AppRoutes.reports, PermissionAction.view),
      isTrue,
    );

    final PermissionsController reloaded = PermissionsController(
      database: database,
    );
    await reloaded.load();
    expect(
      reloaded.can('manager', AppRoutes.reports, PermissionAction.create),
      isTrue,
    );
    reloaded.dispose();
  });

  testWidgets('locks the permission matrix for non admins', (
    WidgetTester tester,
  ) async {
    await session.login(email: 'manager@growfit.erp', password: 'Manager@1234');
    await pumpApp(tester);

    await tester.tap(menuItem('الصلاحيات'));
    await tester.pumpAndSettle();

    expect(
      find.text('للقراءة فقط — تعديل الصلاحيات متاح لمدير النظام'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'استعادة الافتراضي'),
      findsNothing,
    );

    final List<Checkbox> boxes = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .toList();
    expect(boxes, isNotEmpty);
    expect(boxes.every((Checkbox box) => box.onChanged == null), isTrue);
  });

  testWidgets('shows the settings page read only without edit rights', (
    WidgetTester tester,
  ) async {
    await session.login(
      email: 'accountant@growfit.erp',
      password: 'Account@1234',
    );
    await pumpApp(tester);

    await tester.tap(menuItem('الإعدادات'));
    await tester.pumpAndSettle();

    expect(find.textContaining('للقراءة فقط: دورك الحالي'), findsOneWidget);

    final Finder save = find.widgetWithText(FilledButton, 'حفظ');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('blocks a page the role cannot open', (
    WidgetTester tester,
  ) async {
    await session.login(email: 'store@growfit.erp', password: 'Store@1234');

    final AppRouterDelegate delegate = AppRouterDelegate(
      initialLocation: AppRoutes.settings,
    );
    final PlatformRouteInformationProvider provider =
        PlatformRouteInformationProvider(
          initialRouteInformation: RouteInformation(
            uri: Uri.parse(AppRoutes.settings),
          ),
        );
    addTearDown(delegate.dispose);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<PermissionsController>.value(
            value: permissions,
          ),
        ],
        child: MaterialApp.router(
          routerDelegate: delegate,
          routeInformationParser: const AppRouteInformationParser(),
          routeInformationProvider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NoAccessPage), findsOneWidget);
    expect(find.text('ليس لديك صلاحية'), findsOneWidget);
    expect(find.textContaining('دورك الحالي: أمين مخزن'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'فتح لوحة التحكم'));
    await tester.pumpAndSettle();

    expect(delegate.path, AppRoutes.dashboard);
  });

  testWidgets('signs out from the account menu', (WidgetTester tester) async {
    await signInAsAdmin();
    await pumpApp(tester);

    expect(find.byType(LoginPage), findsNothing);

    await tester.tap(find.byTooltip('الحساب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(session.isAuthenticated, isFalse);
  });

  testWidgets('switches theme from the top bar menu', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);

    expect(settings.themeMode, ThemeMode.system);

    await tester.tap(find.byTooltip('المظهر'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ListTile, 'داكن'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
  });

  testWidgets('persists the company profile from the settings page', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);

    await tester.tap(menuItem('الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('ملف الشركة'), findsOneWidget);

    final Finder companyName = find.widgetWithText(TextField, 'شركتي');
    expect(companyName, findsOneWidget);

    await tester.enterText(companyName, 'GrowFit');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(settings.companyName, 'GrowFit');
    expect(await database.readSetting('company_name'), 'GrowFit');
    expect(
      find.text('تم حفظ الإعدادات في قاعدة البيانات المحلية'),
      findsOneWidget,
    );
  });

  testWidgets('shows the not found page for an unknown route', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();

    final AppRouterDelegate delegate = AppRouterDelegate(
      initialLocation: '/missing',
    );
    final PlatformRouteInformationProvider provider =
        PlatformRouteInformationProvider(
          initialRouteInformation: RouteInformation(uri: Uri.parse('/missing')),
        );
    addTearDown(delegate.dispose);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<PermissionsController>.value(
            value: permissions,
          ),
        ],
        child: MaterialApp.router(
          routerDelegate: delegate,
          routeInformationParser: const AppRouteInformationParser(),
          routeInformationProvider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الصفحة غير موجودة'), findsOneWidget);
    expect(find.text('مسار غير معروف'), findsOneWidget);

    await tester.tap(find.text('فتح لوحة التحكم'));
    await tester.pumpAndSettle();

    expect(delegate.path, AppRoutes.dashboard);
  });
}
