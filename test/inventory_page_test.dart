import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_erp/app.dart';
import 'package:web_erp/core/database/app_database.dart';
import 'package:web_erp/core/inventory/inventory_models.dart';
import 'package:web_erp/features/auth/session_controller.dart';
import 'package:web_erp/features/permissions/permissions_controller.dart';
import 'package:web_erp/features/settings/settings_controller.dart';
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
    return session.login(email: 'admin@growfit.erp', password: 'Admin@1234');
  }

  Finder menuItem(String label) =>
      find.descendant(of: find.byType(SideMenu), matching: find.text(label));

  Future<void> openInventory(WidgetTester tester) async {
    await tester.tap(menuItem('المخزون'));
    await tester.pumpAndSettle();
  }

  Finder dialogFields() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  testWidgets('shows seeded products with stock badges and pagination', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);
    await openInventory(tester);

    expect(find.text('إضافة منتج'), findsOneWidget);
    expect(find.text('بروتين مصل اللبن 1 كجم'), findsOneWidget);
    expect(find.text('عرض 1–8 من 8 منتج'), findsOneWidget);

    final Finder table = find.byType(DataTable);
    expect(
      find.descendant(of: table, matching: find.text('نفد')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: table, matching: find.text('منخفض')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: table, matching: find.text('متوفر')),
      findsNWidgets(5),
    );
    expect(find.text('صفحة 1 من 1'), findsOneWidget);
  });

  testWidgets('filters products by search and switches tabs', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);
    await openInventory(tester);

    await tester.enterText(find.byType(TextField).first, 'بروتين');
    await tester.pumpAndSettle();

    expect(find.text('بروتين مصل اللبن 1 كجم'), findsOneWidget);
    expect(find.text('مياه معدنية 1.5 ل'), findsNothing);
    expect(find.text('عرض 1–1 من 1 منتج'), findsOneWidget);

    await tester.tap(find.text('التصنيفات'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة تصنيف'), findsOneWidget);
    expect(find.text('مشروبات'), findsWidgets);

    await tester.tap(find.text('الوحدات'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة وحدة'), findsOneWidget);
    expect(find.text('قطعة'), findsWidgets);

    await tester.tap(find.text('حركات المخزون'));
    await tester.pumpAndSettle();
    expect(find.text('رصيد افتتاحي'), findsWidgets);
    expect(find.text('عرض 1–7 من 7 حركة'), findsOneWidget);
  });

  testWidgets('adjusts a product stock through the dialog', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);
    await openInventory(tester);

    await tester.enterText(find.byType(TextField).first, 'بروتين');
    await tester.pumpAndSettle();

    final Finder adjust = find.byTooltip('تعديل الرصيد');
    await tester.ensureVisible(adjust);
    await tester.pumpAndSettle();
    await tester.tap(adjust);
    await tester.pumpAndSettle();

    expect(find.text('تعديل رصيد المنتج'), findsOneWidget);
    expect(dialogFields(), findsNWidgets(2));

    await tester.enterText(dialogFields().at(0), '99');
    await tester.enterText(dialogFields().at(1), 'جرد تجريبي');
    await tester.pumpAndSettle();
    expect(find.text('الرصيد بعد التعديل: 99'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('تم تعديل رصيد المنتج'), findsOneWidget);
    expect(find.text('99'), findsWidgets);

    final PagedResult<Product> result = await database.listProducts(
      const ProductQuery(search: 'بروتين'),
    );
    expect(result.items.single.stock, 99);
    expect(result.items.single.status, StockStatus.ok);
  });

  testWidgets('creates a product from the inventory tab', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);
    await openInventory(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'إضافة منتج'));
    await tester.pumpAndSettle();

    expect(dialogFields(), findsNWidgets(6));
    await tester.enterText(dialogFields().at(0), 'SKP-2001');
    await tester.enterText(dialogFields().at(1), 'منتج تجريبي');
    await tester.enterText(dialogFields().at(2), '10');
    await tester.enterText(dialogFields().at(3), '15');
    await tester.enterText(dialogFields().at(4), '2');
    await tester.enterText(dialogFields().at(5), '12');

    await tester.tap(find.text('اختر الوحدة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('قطعة').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('تمت إضافة المنتج'), findsOneWidget);
    expect(find.text('منتج تجريبي'), findsOneWidget);

    final PagedResult<Product> created = await database.listProducts(
      const ProductQuery(search: 'SKP-2001'),
    );
    expect(created.total, 1);
    expect(created.items.single.stock, 12);
    expect(created.items.single.unitName, 'قطعة');
  });

  testWidgets('hides inventory actions from the view only role', (
    WidgetTester tester,
  ) async {
    await session.login(
      email: 'accountant@growfit.erp',
      password: 'Account@1234',
    );
    await pumpApp(tester);
    await openInventory(tester);

    expect(find.text('بروتين مصل اللبن 1 كجم'), findsOneWidget);
    expect(find.text('إضافة منتج'), findsNothing);
    expect(find.byTooltip('تعديل الرصيد'), findsNothing);
    expect(find.byTooltip('تعديل'), findsNothing);
    expect(find.byTooltip('حذف'), findsNothing);
  });
}
