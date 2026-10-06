import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_erp/core/database/app_database.dart';
import 'package:web_erp/core/inventory/inventory_models.dart';
import 'package:web_erp/core/sales/sales_models.dart';

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

  Future<void> expectRule(Future<Object?> action, String message) async {
    await expectLater(
      action,
      throwsA(
        isA<AppRuleException>().having(
          (AppRuleException error) => error.message,
          'message',
          message,
        ),
      ),
    );
  }

  Future<Product> productBySku(String sku) async {
    final PagedResult<Product> result = await database.listProducts(
      ProductQuery(search: sku, pageSize: 100),
    );
    return result.items.firstWhere(
      (Product product) => product.sku == sku,
      orElse: () => throw AppRuleException('المنتج غير موجود: $sku'),
    );
  }

  Future<Customer> firstCustomer() async {
    return (await database.activeCustomers()).first;
  }

  test('seeds starter customers', () async {
    final PagedResult<Customer> customers = await database.listCustomers(
      pageSize: 100,
    );

    expect(customers.total, 3);
    expect(
      customers.items.map((Customer customer) => customer.name),
      containsAll(<String>['أحمد محمد', 'مؤسسة النور التجارية', 'سارة العلي']),
    );
    expect(
      customers.items.every((Customer customer) => customer.isActive),
      isTrue,
    );
    expect(
      customers.items.singleWhere((Customer c) => c.name == 'أحمد محمد').phone,
      '0501234567',
    );
  });

  test('creates, searches, updates and validates customers', () async {
    final Customer created = await database.createCustomer(
      name: '  عميل تجريبي  ',
      phone: '0501112233',
      note: 'ملاحظة أولية',
    );

    expect(created.name, 'عميل تجريبي');
    expect(created.phone, '0501112233');
    expect(created.note, 'ملاحظة أولية');
    expect(created.isActive, isTrue);
    expect(created.saleCount, 0);

    final PagedResult<Customer> byName = await database.listCustomers(
      search: 'تجريبي',
    );
    expect(byName.total, 1);
    final PagedResult<Customer> byPhone = await database.listCustomers(
      search: '0501112233',
    );
    expect(byPhone.total, 1);

    final Customer updated = await database.updateCustomer(
      created.id,
      name: 'عميل محدث',
      phone: null,
      note: '',
      isActive: false,
    );
    expect(updated.name, 'عميل محدث');
    expect(updated.note, isNull);
    expect(updated.isActive, isFalse);

    await expectRule(database.createCustomer(name: '   '), 'اسم العميل مطلوب');
    await expectRule(
      database.createCustomer(name: 'هاتف خاطئ', phone: 'abc'),
      'رقم الهاتف غير صالح',
    );
    expect(await database.customerById(9999), isNull);
  });

  test(
    'deletes a customer without invoices and blocks one with invoices',
    () async {
      final Customer loose = await database.createCustomer(name: 'عميل محذوف');
      await database.deleteCustomer(loose.id);
      expect(await database.customerById(loose.id), isNull);

      final Customer bound = await database.createCustomer(name: 'عميل مرتبط');
      final Product product = await productBySku('SKP-1003');
      await database.createSale(
        customerId: bound.id,
        items: <SaleLineInput>[
          (productId: product.id, quantity: 1, unitPrice: 5),
        ],
      );

      expect((await database.customerById(bound.id))!.saleCount, 1);
      await expectRule(
        database.deleteCustomer(bound.id),
        'لا يمكن حذف عميل له فواتير مبيعات',
      );
    },
  );

  test(
    'creates an invoice with totals, snapshots, stock and movements',
    () async {
      final Customer customer = await firstCustomer();
      final Product protein = await productBySku('SKP-1001');
      final Product water = await productBySku('SKP-1003');

      final Sale sale = await database.createSale(
        customerId: customer.id,
        items: <SaleLineInput>[
          (productId: protein.id, quantity: 3, unitPrice: 620),
          (productId: water.id, quantity: 10, unitPrice: 5),
        ],
        discount: 20,
        notes: 'طلب تجريبي',
        createdBy: 1,
      );

      expect(sale.invoiceNo, 'INV-000001');
      expect(sale.status, SaleStatus.completed);
      expect(sale.subtotal, 1910);
      expect(sale.discount, 20);
      expect(sale.total, 1890);
      expect(sale.customerName, customer.name);
      expect(sale.customerDisplay, customer.name);
      expect(sale.notes, 'طلب تجريبي');
      expect(sale.items.length, 2);

      final SaleLine line = sale.items.first;
      expect(line.productId, protein.id);
      expect(line.productName, 'بروتين مصل اللبن 1 كجم');
      expect(line.productSku, 'SKP-1001');
      expect(line.quantity, 3);
      expect(line.unitPrice, 620);
      expect(line.lineTotal, 1860);

      expect((await database.productById(protein.id))!.stock, 37);
      expect((await database.productById(water.id))!.stock, 230);

      final PagedResult<StockMovement> movements = await database.listMovements(
        search: 'INV-000001',
        pageSize: 50,
      );
      expect(movements.total, 2);
      expect(
        movements.items.every((StockMovement m) => m.type == MovementType.sale),
        isTrue,
      );
      expect(
        movements.items.map((StockMovement m) => m.quantityChange),
        containsAll(<int>[-3, -10]),
      );
    },
  );

  test('creates cash invoices with sequential numbering', () async {
    final Product product = await productBySku('SKP-1005');

    final Sale first = await database.createSale(
      items: <SaleLineInput>[
        (productId: product.id, quantity: 2, unitPrice: 38),
      ],
    );
    final Sale second = await database.createSale(
      items: <SaleLineInput>[
        (productId: product.id, quantity: 1, unitPrice: 38),
      ],
    );

    expect(first.invoiceNo, 'INV-000001');
    expect(second.invoiceNo, 'INV-000002');
    expect(first.customerId, isNull);
    expect(first.customerDisplay, 'عميل نقدي');
    expect(first.items.single.productName, 'شوفان كامل 1 كجم');
    expect((await database.productById(product.id))!.stock, 57);
  });

  test('rejects invalid sale requests and keeps stock untouched', () async {
    final Product protein = await productBySku('SKP-1001');
    final Product juice = await productBySku('SKP-1004');
    final Product creatine = await productBySku('SKP-1002');
    final int before = protein.stock;

    await expectRule(
      database.createSale(items: const <SaleLineInput>[]),
      'يجب إضافة منتج واحد على الأقل',
    );
    await expectRule(
      database.createSale(
        items: <SaleLineInput>[
          (productId: protein.id, quantity: 1, unitPrice: 10),
          (productId: protein.id, quantity: 2, unitPrice: 10),
        ],
      ),
      'لا يمكن تكرار المنتج نفسه في الفاتورة',
    );
    await expectRule(
      database.createSale(
        items: <SaleLineInput>[
          (productId: protein.id, quantity: 1, unitPrice: 10),
        ],
        discount: 9999,
      ),
      'الخصم أكبر من مجموع الفاتورة',
    );
    await expectRule(
      database.createSale(
        items: <SaleLineInput>[
          (productId: protein.id, quantity: 0, unitPrice: 10),
        ],
      ),
      'الكمية يجب أن تكون أكبر من صفر',
    );
    await expectRule(
      database.createSale(
        customerId: 9999,
        items: <SaleLineInput>[
          (productId: protein.id, quantity: 1, unitPrice: 10),
        ],
      ),
      'العميل غير موجود',
    );
    await expectRule(
      database.createSale(
        items: <SaleLineInput>[
          (productId: juice.id, quantity: 1, unitPrice: 18),
        ],
      ),
      'الرصيد لا يكفي لـ عصير برتقال طبيعي 1 ل، المتوفر 0 فقط',
    );
    await expectRule(
      database.createSale(
        items: <SaleLineInput>[
          (productId: creatine.id, quantity: 9, unitPrice: 240),
        ],
      ),
      'الرصيد لا يكفي لـ كرياتين مونوهيدرات 500 جم، المتوفر 8 فقط',
    );

    expect((await database.productById(protein.id))!.stock, before);
    expect((await database.productById(juice.id))!.stock, 0);
    expect((await database.productById(creatine.id))!.stock, 8);
    expect((await database.listSales(const SaleQuery())).total, 0);
  });

  test('cancels an invoice and restores stock', () async {
    final Product protein = await productBySku('SKP-1001');
    final int before = protein.stock;

    final Sale sale = await database.createSale(
      items: <SaleLineInput>[
        (productId: protein.id, quantity: 4, unitPrice: 620),
      ],
      createdBy: 1,
    );
    expect((await database.productById(protein.id))!.stock, before - 4);

    final Sale cancelled = await database.cancelSale(sale.id, byUser: 1);

    expect(cancelled.status, SaleStatus.cancelled);
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.cancelledAt, isNotNull);
    expect((await database.productById(protein.id))!.stock, before);

    final PagedResult<StockMovement> movements = await database.listMovements(
      search: 'إلغاء فاتورة ${sale.invoiceNo}',
    );
    expect(movements.total, 1);
    expect(movements.items.single.type, MovementType.adjustment);
    expect(movements.items.single.quantityChange, 4);
    expect(movements.items.single.stockAfter, before);

    await expectRule(database.cancelSale(sale.id), 'الفاتورة ملغاة بالفعل');
    await expectRule(database.cancelSale(9999), 'الفاتورة غير موجودة');
  });

  test('lists invoices by search, status and page', () async {
    final Customer customer = await firstCustomer();
    final Product product = await productBySku('SKP-1003');

    final Sale cashSale = await database.createSale(
      items: <SaleLineInput>[
        (productId: product.id, quantity: 1, unitPrice: 5),
      ],
    );
    final Sale customerSale = await database.createSale(
      customerId: customer.id,
      items: <SaleLineInput>[
        (productId: product.id, quantity: 2, unitPrice: 5),
      ],
    );
    await database.createSale(
      items: <SaleLineInput>[
        (productId: product.id, quantity: 3, unitPrice: 5),
      ],
    );
    await database.cancelSale(cashSale.id);

    final PagedResult<Sale> all = await database.listSales(
      const SaleQuery(pageSize: 2),
    );
    expect(all.total, 3);
    expect(all.items.length, 2);
    expect(all.from, 1);
    expect(all.to, 2);

    final PagedResult<Sale> page2 = await database.listSales(
      const SaleQuery(page: 2, pageSize: 2),
    );
    expect(page2.items.length, 1);
    expect(page2.page, 2);

    final PagedResult<Sale> byInvoice = await database.listSales(
      SaleQuery(search: customerSale.invoiceNo),
    );
    expect(byInvoice.total, 1);
    expect(byInvoice.items.single.id, customerSale.id);

    final PagedResult<Sale> byCustomer = await database.listSales(
      SaleQuery(search: customer.name),
    );
    expect(byCustomer.total, 1);
    expect(byCustomer.items.single.id, customerSale.id);

    final PagedResult<Sale> completed = await database.listSales(
      const SaleQuery(status: SaleStatus.completed),
    );
    expect(completed.total, 2);

    final PagedResult<Sale> cancelled = await database.listSales(
      const SaleQuery(status: SaleStatus.cancelled),
    );
    expect(cancelled.total, 1);
    expect(cancelled.items.single.invoiceNo, cashSale.invoiceNo);
  });

  test(
    'keeps customers and invoices when reopening the database file',
    () async {
      final String path =
          'web_erp_sales_${DateTime.now().millisecondsSinceEpoch}.db';

      final AppDatabase first = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      final Product product = (await first.listProducts(
        const ProductQuery(pageSize: 100),
      )).items.first;
      final Sale sale = await first.createSale(
        items: <SaleLineInput>[
          (productId: product.id, quantity: 1, unitPrice: product.salePrice),
        ],
      );
      await first.createCustomer(name: 'عميل استمرار');
      await first.close();

      final AppDatabase second = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      expect((await second.saleById(sale.id))!.invoiceNo, sale.invoiceNo);
      expect((await second.listCustomers(search: 'استمرار')).total, 1);
      expect((await second.listSales(const SaleQuery())).total, 1);

      await second.close();
      await databaseFactoryFfi.deleteDatabase(path);
    },
  );
}
