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

  test('seeds starter inventory data', () async {
    final List<InventoryCategory> categories = await database.listCategories();
    final List<InventoryUnit> units = await database.listUnits();
    final PagedResult<Product> products = await database.listProducts(
      const ProductQuery(),
    );

    expect(categories.length, 4);
    expect(units.length, 5);
    expect(products.total, 8);
    expect(
      categories
          .firstWhere((InventoryCategory c) => c.name == 'مكملات غذائية')
          .productCount,
      2,
    );
    expect(
      units.firstWhere((InventoryUnit u) => u.name == 'قطعة').productCount,
      2,
    );

    final PagedResult<Product> out = await database.listProducts(
      const ProductQuery(stockFilter: StockFilter.out),
    );
    final PagedResult<Product> low = await database.listProducts(
      const ProductQuery(stockFilter: StockFilter.low),
    );
    final PagedResult<Product> ok = await database.listProducts(
      const ProductQuery(stockFilter: StockFilter.ok),
    );
    expect(out.total, 1);
    expect(low.total, 2);
    expect(ok.total, 5);

    expect((await database.listMovements(pageSize: 100)).total, 7);
  });

  test('creates, renames and deletes categories with rules', () async {
    final InventoryCategory created = await database.createCategory(
      name: ' عناصر جديدة ',
      description: '  وصف مختصر  ',
    );
    expect(created.name, 'عناصر جديدة');
    expect(created.description, 'وصف مختصر');
    expect((await database.listCategories()).length, 5);

    await expectRule(
      database.createCategory(name: 'مشروبات'),
      'التصنيف موجود بالفعل',
    );
    await expectRule(database.createCategory(name: '   '), 'اسم التصنيف مطلوب');

    final InventoryCategory renamed = await database.updateCategory(
      created.id,
      name: 'عناصر محدثة',
      description: 'وصف محدث',
    );
    expect(renamed.name, 'عناصر محدثة');
    expect(renamed.description, 'وصف محدث');
    expect(renamed.productCount, 0);

    await expectRule(
      database.updateCategory(created.id, name: 'مشروبات'),
      'التصنيف موجود بالفعل',
    );
    await expectRule(
      database.updateCategory(9999, name: 'أي'),
      'التصنيف غير موجود',
    );

    final InventoryCategory drinks = (await database.listCategories())
        .firstWhere((InventoryCategory c) => c.name == 'مشروبات');
    await expectRule(
      database.deleteCategory(drinks.id),
      'لا يمكن حذف تصنيف مرتبط بمنتجات',
    );

    await database.deleteCategory(created.id);
    expect((await database.listCategories()).length, 4);
    await expectRule(database.deleteCategory(created.id), 'التصنيف غير موجود');
  });

  test('creates, renames and deletes units with rules', () async {
    final InventoryUnit created = await database.createUnit(' جرام ');
    expect(created.name, 'جرام');
    expect((await database.listUnits()).length, 6);

    await expectRule(database.createUnit('قطعة'), 'الوحدة موجودة بالفعل');
    await expectRule(database.createUnit('  '), 'اسم الوحدة مطلوب');
    await expectRule(
      database.updateUnit(created.id, 'لتر'),
      'الوحدة موجودة بالفعل',
    );
    await expectRule(database.updateUnit(9999, 'أي'), 'الوحدة غير موجودة');

    final InventoryUnit renamed = await database.updateUnit(
      created.id,
      'جرام طازج',
    );
    expect(renamed.name, 'جرام طازج');

    final InventoryUnit piece = (await database.listUnits()).firstWhere(
      (InventoryUnit u) => u.name == 'قطعة',
    );
    await expectRule(
      database.deleteUnit(piece.id),
      'لا يمكن حذف وحدة مرتبطة بمنتجات',
    );

    await database.deleteUnit(created.id);
    expect((await database.listUnits()).length, 5);
    await expectRule(database.deleteUnit(created.id), 'الوحدة غير موجودة');
  });

  test('validates product creation and records the opening balance', () async {
    final List<InventoryUnit> units = await database.listUnits();
    final List<InventoryCategory> categories = await database.listCategories();
    final int unitId = units.first.id;

    final Product created = await database.createProduct(
      sku: ' skp-2001 ',
      name: 'منتج جديد',
      categoryId: categories.first.id,
      unitId: unitId,
      costPrice: 10,
      salePrice: 15,
      stock: 25,
      minStock: 5,
    );
    expect(created.sku, 'SKP-2001');
    expect(created.stock, 25);
    expect(created.status, StockStatus.ok);
    expect(created.categoryName, categories.first.name);
    expect(created.unitName, units.first.name);

    final List<StockMovement> ownMoves =
        (await database.listMovements(pageSize: 100)).items
            .where((StockMovement movement) => movement.productId == created.id)
            .toList();
    expect(ownMoves.length, 1);
    expect(ownMoves.first.type, MovementType.initial);
    expect(ownMoves.first.quantityChange, 25);
    expect(ownMoves.first.stockAfter, 25);
    expect(ownMoves.first.reason, 'رصيد افتتاحي');

    await expectRule(
      database.createProduct(sku: 'SKP-2002', name: '   ', unitId: unitId),
      'اسم المنتج مطلوب',
    );
    await expectRule(
      database.createProduct(sku: '', name: 'أي', unitId: unitId),
      'كود المنتج مطلوب',
    );
    await expectRule(
      database.createProduct(sku: 'SKP 2002', name: 'أي', unitId: unitId),
      'كود المنتج لا يجوز أن يحتوي على مسافات',
    );
    await expectRule(
      database.createProduct(sku: 'SKP-1001', name: 'أي', unitId: unitId),
      'كود المنتج مستخدم بالفعل',
    );
    await expectRule(
      database.createProduct(sku: 'skp-1001', name: 'أي', unitId: unitId),
      'كود المنتج مستخدم بالفعل',
    );
    await expectRule(
      database.createProduct(sku: 'SKP-2003', name: 'أي', unitId: 9999),
      'الوحدة غير موجودة',
    );
    await expectRule(
      database.createProduct(
        sku: 'SKP-2004',
        name: 'أي',
        categoryId: 9999,
        unitId: unitId,
      ),
      'التصنيف غير موجود',
    );
    await expectRule(
      database.createProduct(
        sku: 'SKP-2005',
        name: 'أي',
        unitId: unitId,
        costPrice: -1,
      ),
      'سعر التكلفة لا يمكن أن يكون أقل من صفر',
    );
    await expectRule(
      database.createProduct(
        sku: 'SKP-2006',
        name: 'أي',
        unitId: unitId,
        salePrice: -2,
      ),
      'سعر البيع لا يمكن أن يكون أقل من صفر',
    );
    await expectRule(
      database.createProduct(
        sku: 'SKP-2007',
        name: 'أي',
        unitId: unitId,
        stock: -5,
      ),
      'الرصيد الابتدائي لا يمكن أن يكون أقل من صفر',
    );
    await expectRule(
      database.createProduct(
        sku: 'SKP-2008',
        name: 'أي',
        unitId: unitId,
        minStock: -1,
      ),
      'الحد الأدنى لا يمكن أن يكون أقل من صفر',
    );

    final Product zero = await database.createProduct(
      sku: 'SKP-2010',
      name: 'بدون رصيد',
      unitId: unitId,
      stock: 0,
    );
    expect(zero.stock, 0);
    final List<StockMovement> zeroMoves =
        (await database.listMovements(pageSize: 100)).items
            .where((StockMovement movement) => movement.productId == zero.id)
            .toList();
    expect(zeroMoves, isEmpty);
  });

  test('updates product fields without touching the stock', () async {
    final Product target = await productBySku('SKP-1001');
    final int stockBefore = target.stock;

    final Product updated = await database.updateProduct(
      id: target.id,
      sku: target.sku,
      name: 'بروتين محدث',
      categoryId: target.categoryId,
      unitId: target.unitId,
      costPrice: 460,
      salePrice: 640,
      minStock: 12,
      isActive: false,
    );
    expect(updated.name, 'بروتين محدث');
    expect(updated.stock, stockBefore);
    expect(updated.minStock, 12);
    expect(updated.salePrice, 640);
    expect(updated.isActive, isFalse);

    final Product other = await productBySku('SKP-1002');
    await expectRule(
      database.updateProduct(
        id: other.id,
        sku: target.sku,
        name: other.name,
        categoryId: other.categoryId,
        unitId: other.unitId,
        costPrice: 1,
        salePrice: 1,
        minStock: 1,
        isActive: true,
      ),
      'كود المنتج مستخدم بالفعل',
    );
    await expectRule(
      database.updateProduct(
        id: 9999,
        sku: 'SKP-9999',
        name: 'أي',
        unitId: other.unitId,
        costPrice: 1,
        salePrice: 1,
        minStock: 1,
        isActive: true,
      ),
      'المنتج غير موجود',
    );
  });

  test('searches, filters, sorts and paginates products', () async {
    final PagedResult<Product> byName = await database.listProducts(
      const ProductQuery(search: 'بروتين'),
    );
    expect(byName.total, 1);
    expect(byName.items.single.name, 'بروتين مصل اللبن 1 كجم');

    final PagedResult<Product> bySku = await database.listProducts(
      const ProductQuery(search: 'skp-1003'),
    );
    expect(bySku.total, 1);
    expect(bySku.items.single.name, 'مياه معدنية 1.5 ل');

    final List<InventoryCategory> categories = await database.listCategories();
    final InventoryCategory drinks = categories.firstWhere(
      (InventoryCategory c) => c.name == 'مشروبات',
    );
    final PagedResult<Product> inDrinks = await database.listProducts(
      ProductQuery(categoryId: drinks.id),
    );
    expect(inDrinks.total, 2);
    expect(
      inDrinks.items.every((Product p) => p.categoryId == drinks.id),
      isTrue,
    );

    final PagedResult<Product> asc = await database.listProducts(
      const ProductQuery(sort: ProductSort.stock, pageSize: 100),
    );
    final List<int> stocks = asc.items
        .map((Product product) => product.stock)
        .toList();
    final List<int> sorted = List<int>.from(stocks)..sort();
    expect(stocks, sorted);

    final PagedResult<Product> desc = await database.listProducts(
      const ProductQuery(
        sort: ProductSort.stock,
        ascending: false,
        pageSize: 100,
      ),
    );
    expect(desc.items.first.stock, 240);
    expect(desc.items.last.stock, 0);

    final PagedResult<Product> page1 = await database.listProducts(
      const ProductQuery(pageSize: 3, page: 1),
    );
    expect(page1.total, 8);
    expect(page1.pageCount, 3);
    expect(page1.items.length, 3);
    expect(page1.from, 1);
    expect(page1.to, 3);

    final PagedResult<Product> page3 = await database.listProducts(
      const ProductQuery(pageSize: 3, page: 3),
    );
    expect(page3.items.length, 2);
    expect(page3.from, 7);
    expect(page3.to, 8);

    final PagedResult<Product> clamped = await database.listProducts(
      const ProductQuery(pageSize: 3, page: 99),
    );
    expect(clamped.page, 3);
    expect(clamped.items.length, 2);

    final PagedResult<Product> empty = await database.listProducts(
      const ProductQuery(search: 'غير موجود إطلاقاً'),
    );
    expect(empty.total, 0);
    expect(empty.items, isEmpty);
    expect(empty.from, 0);
    expect(empty.to, 0);
    expect(empty.pageCount, 1);
  });

  test('adjusts stock with movements and guards', () async {
    final Product target = await productBySku('SKP-1001');
    final int movesBefore = (await database.listMovements(pageSize: 100)).total;

    await database.adjustStock(
      productId: target.id,
      newQuantity: 55,
      reason: 'جرد المخزن',
      createdBy: 1,
    );
    expect((await database.productById(target.id))!.stock, 55);

    final PagedResult<StockMovement> moves = await database.listMovements(
      pageSize: 100,
    );
    expect(moves.total, movesBefore + 1);
    final StockMovement latest = moves.items.first;
    expect(latest.type, MovementType.adjustment);
    expect(latest.quantityChange, 15);
    expect(latest.stockAfter, 55);
    expect(latest.reason, 'جرد المخزن');
    expect(latest.createdByName, isNotNull);

    await database.adjustStock(
      productId: target.id,
      newQuantity: 10,
      reason: 'تصحيح',
    );
    expect((await database.productById(target.id))!.stock, 10);

    await expectRule(
      database.adjustStock(
        productId: target.id,
        newQuantity: 10,
        reason: 'نفس القيمة',
      ),
      'الرصيد الحالي مطابق للقيمة الجديدة',
    );
    await expectRule(
      database.adjustStock(
        productId: target.id,
        newQuantity: -1,
        reason: 'سالب',
      ),
      'الرصيد الجديد لا يمكن أن يكون أقل من صفر',
    );
    await expectRule(
      database.adjustStock(productId: 9999, newQuantity: 5, reason: 'أي'),
      'المنتج غير موجود',
    );
    await expectRule(
      database.adjustStock(productId: target.id, newQuantity: 5, reason: '   '),
      'سبب الحركة مطلوب',
    );

    expect((await database.productById(target.id))!.stock, 10);
  });

  test('rejects movements that would break the stock', () async {
    final Product target = await productBySku('SKP-1003');
    final int before = target.stock;

    await expectRule(
      database.postMovement(
        productId: target.id,
        type: MovementType.sale,
        quantityChange: -1000,
        reason: 'بيع كبير',
      ),
      'الرصيد لا يكفي، المتوفر $before فقط',
    );
    expect((await database.productById(target.id))!.stock, before);
    expect((await database.listMovements(search: 'بيع كبير')).total, 0);

    await expectRule(
      database.postMovement(
        productId: target.id,
        type: MovementType.sale,
        quantityChange: 0,
        reason: 'صفر',
      ),
      'قيمة الحركة لا يمكن أن تكون صفر',
    );
    await expectRule(
      database.postMovement(
        productId: 9999,
        type: MovementType.purchase,
        quantityChange: 1,
        reason: 'أي',
      ),
      'المنتج غير موجود',
    );

    await database.postMovement(
      productId: target.id,
      type: MovementType.sale,
      quantityChange: -40,
      reason: 'بيع 40',
      createdBy: 1,
    );
    expect((await database.productById(target.id))!.stock, before - 40);

    final PagedResult<StockMovement> sales = await database.listMovements(
      type: MovementType.sale,
      pageSize: 100,
    );
    expect(sales.total, 1);
    expect(sales.items.single.quantityChange, -40);
    expect(sales.items.single.stockAfter, before - 40);
    expect(sales.items.single.createdByName, isNotNull);
  });

  test('deletes products only when they have no business movements', () async {
    final Product protein = await productBySku('SKP-1001');

    await database.deleteProduct(protein.id);
    expect(await database.productById(protein.id), isNull);
    expect(
      (await database.listMovements(pageSize: 100)).items
          .where((StockMovement movement) => movement.productId == protein.id),
      isEmpty,
    );

    final Product water = await productBySku('SKP-1003');
    await database.adjustStock(
      productId: water.id,
      newQuantity: 200,
      reason: 'جرد',
    );
    await expectRule(
      database.deleteProduct(water.id),
      'لا يمكن حذف منتج له حركات مبيعات أو تسوية',
    );
    await expectRule(database.deleteProduct(9999), 'المنتج غير موجود');
  });

  test('lists movements with search, type filter and pagination', () async {
    final PagedResult<StockMovement> all = await database.listMovements(
      pageSize: 100,
    );
    expect(all.total, 7);
    expect(
      all.items.every(
        (StockMovement movement) => movement.type == MovementType.initial,
      ),
      isTrue,
    );
    expect(all.items.first.productSku, 'SKP-1008');

    final PagedResult<StockMovement> search = await database.listMovements(
      search: 'مياه',
    );
    expect(search.total, 1);
    expect(search.items.single.productName, 'مياه معدنية 1.5 ل');

    expect((await database.listMovements(type: MovementType.initial)).total, 7);
    expect(
      (await database.listMovements(type: MovementType.adjustment)).total,
      0,
    );

    final PagedResult<StockMovement> page1 = await database.listMovements(
      pageSize: 3,
      page: 1,
    );
    expect(page1.total, 7);
    expect(page1.pageCount, 3);
    expect(page1.items.length, 3);

    final PagedResult<StockMovement> page3 = await database.listMovements(
      pageSize: 3,
      page: 3,
    );
    expect(page3.items.length, 1);
    expect(page3.from, 7);
    expect(page3.to, 7);

    final Product target = await productBySku('SKP-1005');
    await database.adjustStock(
      productId: target.id,
      newQuantity: 50,
      reason: 'جرد سريع',
    );
    final PagedResult<StockMovement> recent = await database.listMovements();
    expect(recent.items.first.type, MovementType.adjustment);
    expect(recent.items.first.reason, 'جرد سريع');
    expect(recent.items.first.productName, 'شوفان كامل 1 كجم');
    expect(recent.total, 8);
  });

  test('keeps inventory data when reopening the database file', () async {
    final String path =
        'web_erp_inventory_${DateTime.now().millisecondsSinceEpoch}.db';

    final AppDatabase first = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final List<InventoryUnit> units = await first.listUnits();
    final Product product = await first.createProduct(
      sku: 'SKP-7777',
      name: 'منتج استمرار',
      unitId: units.first.id,
      stock: 12,
    );
    await first.adjustStock(
      productId: product.id,
      newQuantity: 30,
      reason: 'جرد',
    );
    await first.createCategory(name: 'اختبار استمرار');
    await first.close();

    final AppDatabase second = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final PagedResult<Product> reopened = await second.listProducts(
      const ProductQuery(search: 'SKP-7777'),
    );
    expect(reopened.total, 1);
    expect(reopened.items.single.stock, 30);
    expect(
      (await second.listMovements(search: 'SKP-7777', pageSize: 50)).total,
      2,
    );
    expect(
      (await second.listCategories()).any(
        (InventoryCategory c) => c.name == 'اختبار استمرار',
      ),
      isTrue,
    );

    await second.close();
    await databaseFactoryFfi.deleteDatabase(path);
  });
}
