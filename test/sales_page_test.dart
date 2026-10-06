import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_erp/app.dart';
import 'package:web_erp/core/database/app_database.dart';
import 'package:web_erp/core/inventory/inventory_models.dart';
import 'package:web_erp/core/sales/sales_models.dart';
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

  Future<void> openSales(WidgetTester tester) async {
    await tester.tap(menuItem('المبيعات'));
    await tester.pumpAndSettle();
  }

  Finder dialogFields() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, label),
  );

  Future<Product> productBySku(String sku) async {
    final PagedResult<Product> result = await database.listProducts(
      ProductQuery(search: sku, pageSize: 100),
    );
    return result.items.firstWhere((Product product) => product.sku == sku);
  }

  testWidgets('shows the invoices empty state and seeded customers', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);
    await openSales(tester);

    expect(find.text('فواتير المبيعات'), findsOneWidget);
    expect(find.text('لا توجد فواتير مطابقة للبحث'), findsOneWidget);
    expect(find.text('فاتورة جديدة'), findsOneWidget);
    expect(find.text('عرض 1–0 من 0 فاتورة'), findsNothing);

    await tester.tap(find.text('العملاء'));
    await tester.pumpAndSettle();

    expect(find.text('إضافة عميل'), findsOneWidget);
    expect(find.text('أحمد محمد'), findsOneWidget);
    expect(find.text('عرض 1–3 من 3 عميل'), findsOneWidget);
  });

  testWidgets('creates a customer from the customers tab', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);
    await openSales(tester);

    await tester.tap(find.text('العملاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'إضافة عميل'));
    await tester.pumpAndSettle();

    expect(dialogFields(), findsNWidgets(3));
    await tester.enterText(dialogFields().at(0), 'عميل واجهة');
    await tester.enterText(dialogFields().at(1), '0550001111');
    await tester.enterText(dialogFields().at(2), 'عبر الواجهة');

    await tester.tap(dialogButton('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('تمت إضافة العميل'), findsOneWidget);
    expect(find.text('عميل واجهة'), findsOneWidget);

    final PagedResult<Customer> created = await database.listCustomers(
      search: 'عميل واجهة',
    );
    expect(created.total, 1);
    expect(created.items.single.phone, '0550001111');
  });

  testWidgets('creates an invoice and decrements stock', (
    WidgetTester tester,
  ) async {
    await signInAsAdmin();
    await pumpApp(tester);
    await openSales(tester);

    final Product protein = await productBySku('SKP-1001');
    expect(protein.stock, 40);

    await tester.tap(find.widgetWithText(FilledButton, 'فاتورة جديدة'));
    await tester.pumpAndSettle();

    expect(find.text('فاتورة مبيعات جديدة'), findsOneWidget);

    await tester.tap(find.text('اختر منتجاً…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بروتين مصل اللبن 1 كجم (SKP-1001)'));
    await tester.pumpAndSettle();

    expect(find.text('المتوفر: 40'), findsOneWidget);

    await tester.enterText(dialogFields().at(1), '3');
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'إضافة'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 × 620.00'), findsOneWidget);
    expect(find.text('1860.00'), findsWidgets);

    await tester.tap(dialogButton('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('تم إنشاء الفاتورة INV-000001'), findsOneWidget);
    expect(find.text('INV-000001'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('مكتملة'),
      ),
      findsOneWidget,
    );

    final PagedResult<Sale> sales = await database.listSales(const SaleQuery());
    expect(sales.total, 1);
    expect(sales.items.single.total, 1860);

    expect((await database.productById(protein.id))!.stock, 37);
    final PagedResult<StockMovement> movements = await database.listMovements(
      search: 'INV-000001',
    );
    expect(movements.total, 1);
    expect(movements.items.single.quantityChange, -3);
  });

  testWidgets('cancels an invoice and restores stock', (
    WidgetTester tester,
  ) async {
    final Product protein = await productBySku('SKP-1001');
    final Sale sale = await database.createSale(
      items: <SaleLineInput>[
        (productId: protein.id, quantity: 2, unitPrice: protein.salePrice),
      ],
    );
    expect((await database.productById(protein.id))!.stock, 38);

    await signInAsAdmin();
    await pumpApp(tester);
    await openSales(tester);

    expect(find.text(sale.invoiceNo), findsOneWidget);

    await tester.tap(find.byTooltip('إلغاء الفاتورة'));
    await tester.pumpAndSettle();

    expect(find.text('إلغاء الفاتورة ${sale.invoiceNo}'), findsOneWidget);

    await tester.tap(dialogButton('إلغاء الفاتورة'));
    await tester.pumpAndSettle();

    expect(find.text('تم إلغاء الفاتورة ${sale.invoiceNo}'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(DataTable), matching: find.text('ملغاة')),
      findsOneWidget,
    );
    expect(find.byTooltip('إلغاء الفاتورة'), findsNothing);

    expect((await database.productById(protein.id))!.stock, 40);
    final Sale? reloaded = await database.saleById(sale.id);
    expect(reloaded!.status, SaleStatus.cancelled);
  });

  testWidgets('opens the invoice detail dialog', (WidgetTester tester) async {
    final Product protein = await productBySku('SKP-1001');
    final Sale sale = await database.createSale(
      items: <SaleLineInput>[
        (productId: protein.id, quantity: 5, unitPrice: protein.salePrice),
      ],
      discount: 10,
      notes: 'ملاحظة الفاتورة',
    );

    await signInAsAdmin();
    await pumpApp(tester);
    await openSales(tester);

    await tester.tap(find.byTooltip('عرض الفاتورة'));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل الفاتورة'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(sale.invoiceNo),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('عميل نقدي'),
      ),
      findsOneWidget,
    );
    expect(find.text('ملاحظة الفاتورة'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('3100.00'),
      ),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('3090.00'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'إغلاق'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الفاتورة'), findsNothing);
  });

  testWidgets('hides sales actions from the view only role', (
    WidgetTester tester,
  ) async {
    final Product protein = await productBySku('SKP-1001');
    await database.createSale(
      items: <SaleLineInput>[
        (productId: protein.id, quantity: 1, unitPrice: protein.salePrice),
      ],
    );

    await session.login(
      email: 'accountant@growfit.erp',
      password: 'Account@1234',
    );
    await pumpApp(tester);
    await openSales(tester);

    expect(find.text('فواتير المبيعات'), findsOneWidget);
    expect(find.text('فاتورة جديدة'), findsNothing);
    expect(find.byTooltip('إلغاء الفاتورة'), findsNothing);
    expect(find.byTooltip('عرض الفاتورة'), findsOneWidget);

    await tester.tap(find.text('العملاء'));
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمد'), findsOneWidget);
    expect(find.text('إضافة عميل'), findsNothing);
    expect(find.byTooltip('تعديل'), findsNothing);
    expect(find.byTooltip('حذف'), findsNothing);
  });
}
