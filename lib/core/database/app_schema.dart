import 'package:sqflite_common/sqlite_api.dart';

import '../auth/password_hasher.dart';
import '../auth/permission_defaults.dart';
import '../auth/seed_users.dart';

typedef SchemaMigration = Future<void> Function(Database db);

abstract final class AppSchema {
  static const int version = 6;

  static const String appSettings = 'app_settings';
  static const String columnKey = 'setting_key';
  static const String columnValue = 'setting_value';
  static const String columnUpdatedAt = 'updated_at';

  static const String users = 'users';
  static const String userId = 'id';
  static const String userEmail = 'email';
  static const String userPasswordHash = 'password_hash';
  static const String userSalt = 'salt';
  static const String userFullName = 'full_name';
  static const String userRole = 'role';
  static const String userIsActive = 'is_active';
  static const String userCreatedAt = 'created_at';
  static const String userLastLoginAt = 'last_login_at';

  static const String sessions = 'user_sessions';
  static const String sessionToken = 'token';
  static const String sessionUserId = 'user_id';
  static const String sessionCreatedAt = 'created_at';
  static const String sessionExpiresAt = 'expires_at';

  static const String rolePermissions = 'role_permissions';
  static const String permissionRole = 'role';
  static const String permissionResource = 'resource';
  static const String permissionAction = 'action';
  static const String permissionAllowed = 'allowed';

  static const String categories = 'categories';
  static const String categoryId = 'id';
  static const String categoryName = 'name';
  static const String categoryDescription = 'description';

  static const String units = 'units';
  static const String unitId = 'id';
  static const String unitName = 'name';

  static const String products = 'products';
  static const String productId = 'id';
  static const String productSku = 'sku';
  static const String productName = 'name';
  static const String productCategoryId = 'category_id';
  static const String productUnitId = 'unit_id';
  static const String productCostPrice = 'cost_price';
  static const String productSalePrice = 'sale_price';
  static const String productStock = 'stock';
  static const String productMinStock = 'min_stock';
  static const String productIsActive = 'is_active';
  static const String productCreatedAt = 'created_at';
  static const String productUpdatedAt = 'updated_at';

  static const String stockMovements = 'stock_movements';
  static const String movementId = 'id';
  static const String movementProductId = 'product_id';
  static const String movementType = 'movement_type';
  static const String movementChange = 'quantity_change';
  static const String movementStockAfter = 'stock_after';
  static const String movementReason = 'reason';
  static const String movementCreatedBy = 'created_by';
  static const String movementCreatedAt = 'created_at';

  static const String customers = 'customers';
  static const String customerId = 'id';
  static const String customerName = 'name';
  static const String customerPhone = 'phone';
  static const String customerNote = 'note';
  static const String customerIsActive = 'is_active';
  static const String customerCreatedAt = 'created_at';
  static const String customerUpdatedAt = 'updated_at';

  static const String salesInvoices = 'sales_invoices';
  static const String saleId = 'id';
  static const String saleInvoiceNo = 'invoice_no';
  static const String saleCustomerId = 'customer_id';
  static const String saleUserId = 'user_id';
  static const String saleDate = 'sale_date';
  static const String saleSubtotal = 'subtotal';
  static const String saleDiscount = 'discount';
  static const String saleTotal = 'total';
  static const String saleStatus = 'status';
  static const String saleNotes = 'notes';
  static const String saleCreatedAt = 'created_at';
  static const String saleCancelledAt = 'cancelled_at';

  static const String salesItems = 'sales_items';
  static const String saleItemId = 'id';
  static const String saleItemSaleId = 'sale_id';
  static const String saleItemProductId = 'product_id';
  static const String saleItemProductName = 'product_name';
  static const String saleItemProductSku = 'product_sku';
  static const String saleItemQuantity = 'quantity';
  static const String saleItemUnitPrice = 'unit_price';
  static const String saleItemLineTotal = 'line_total';

  static const String suppliers = 'suppliers';
  static const String supplierId = 'id';
  static const String supplierName = 'name';
  static const String supplierPhone = 'phone';
  static const String supplierNote = 'note';
  static const String supplierIsActive = 'is_active';
  static const String supplierCreatedAt = 'created_at';
  static const String supplierUpdatedAt = 'updated_at';

  static const String purchases = 'purchases';
  static const String purchaseId = 'id';
  static const String purchaseOrderNo = 'order_no';
  static const String purchaseSupplierId = 'supplier_id';
  static const String purchaseUserId = 'user_id';
  static const String purchaseDate = 'purchase_date';
  static const String purchaseSubtotal = 'subtotal';
  static const String purchaseDiscount = 'discount';
  static const String purchaseTotal = 'total';
  static const String purchaseStatus = 'status';
  static const String purchaseNotes = 'notes';
  static const String purchaseCreatedAt = 'created_at';
  static const String purchaseCancelledAt = 'cancelled_at';

  static const String purchaseItems = 'purchase_items';
  static const String purchaseItemId = 'id';
  static const String purchaseItemPurchaseId = 'purchase_id';
  static const String purchaseItemProductId = 'product_id';
  static const String purchaseItemProductName = 'product_name';
  static const String purchaseItemProductSku = 'product_sku';
  static const String purchaseItemQuantity = 'quantity';
  static const String purchaseItemUnitPrice = 'unit_price';
  static const String purchaseItemLineTotal = 'line_total';

  static final Map<int, SchemaMigration> migrations = <int, SchemaMigration>{
    2: _createAuthTables,
    3: _createPermissionTable,
    4: _createInventoryTables,
    5: _createSalesTables,
    6: _createPurchaseTables,
  };

  static Future<void> create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $appSettings (
        $columnKey TEXT PRIMARY KEY NOT NULL,
        $columnValue TEXT NOT NULL,
        $columnUpdatedAt TEXT NOT NULL
      )
    ''');

    await writeSetting(db, 'company_name', 'شركتي');
    await writeSetting(db, 'currency', 'USD');
    await writeSetting(db, 'date_format', 'yyyy-MM-dd');

    await _createAuthTables(db);
    await _createPermissionTable(db);
    await _createInventoryTables(db);
    await _createSalesTables(db);
    await _createPurchaseTables(db);
  }

  static Future<void> _createPermissionTable(Database db) async {
    await db.execute('''
      CREATE TABLE $rolePermissions (
        $permissionRole TEXT NOT NULL,
        $permissionResource TEXT NOT NULL,
        $permissionAction TEXT NOT NULL,
        $permissionAllowed INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY ($permissionRole, $permissionResource, $permissionAction)
      )
    ''');

    final Batch batch = db.batch();
    for (final (String role, String resource, String action)
        in PermissionDefaults.seedRows()) {
      batch.insert(rolePermissions, <String, Object?>{
        permissionRole: role,
        permissionResource: resource,
        permissionAction: action,
        permissionAllowed: 1,
      });
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _createAuthTables(Database db) async {
    await db.execute('''
      CREATE TABLE $users (
        $userId INTEGER PRIMARY KEY AUTOINCREMENT,
        $userEmail TEXT NOT NULL UNIQUE,
        $userPasswordHash TEXT NOT NULL,
        $userSalt TEXT NOT NULL,
        $userFullName TEXT NOT NULL,
        $userRole TEXT NOT NULL,
        $userIsActive INTEGER NOT NULL DEFAULT 1,
        $userCreatedAt TEXT NOT NULL,
        $userLastLoginAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $sessions (
        $sessionToken TEXT PRIMARY KEY NOT NULL,
        $sessionUserId INTEGER NOT NULL,
        $sessionCreatedAt TEXT NOT NULL,
        $sessionExpiresAt TEXT NOT NULL,
        FOREIGN KEY ($sessionUserId) REFERENCES $users ($userId) ON DELETE CASCADE
      )
    ''');

    final Batch batch = db.batch();
    final String timestamp = _timestamp();
    for (final SeedUser user in SeedUsers.all) {
      final String salt = PasswordHasher.randomSalt();
      batch.insert(users, <String, Object?>{
        userEmail: user.email,
        userPasswordHash: PasswordHasher.hash(user.password, salt),
        userSalt: salt,
        userFullName: user.fullName,
        userRole: user.role.id,
        userIsActive: 1,
        userCreatedAt: timestamp,
      });
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _createInventoryTables(Database db) async {
    await db.execute('''
      CREATE TABLE $categories (
        $categoryId INTEGER PRIMARY KEY AUTOINCREMENT,
        $categoryName TEXT NOT NULL UNIQUE,
        $categoryDescription TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $units (
        $unitId INTEGER PRIMARY KEY AUTOINCREMENT,
        $unitName TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE $products (
        $productId INTEGER PRIMARY KEY AUTOINCREMENT,
        $productSku TEXT NOT NULL UNIQUE,
        $productName TEXT NOT NULL,
        $productCategoryId INTEGER,
        $productUnitId INTEGER NOT NULL,
        $productCostPrice REAL NOT NULL DEFAULT 0,
        $productSalePrice REAL NOT NULL DEFAULT 0,
        $productStock INTEGER NOT NULL DEFAULT 0,
        $productMinStock INTEGER NOT NULL DEFAULT 0,
        $productIsActive INTEGER NOT NULL DEFAULT 1,
        $productCreatedAt TEXT NOT NULL,
        $productUpdatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $stockMovements (
        $movementId INTEGER PRIMARY KEY AUTOINCREMENT,
        $movementProductId INTEGER NOT NULL,
        $movementType TEXT NOT NULL,
        $movementChange INTEGER NOT NULL,
        $movementStockAfter INTEGER NOT NULL,
        $movementReason TEXT NOT NULL,
        $movementCreatedBy INTEGER,
        $movementCreatedAt TEXT NOT NULL
      )
    ''');

    await _seedInventory(db);
  }

  static Future<void> _seedInventory(Database db) async {
    final String timestamp = _timestamp();
    final Map<String, int> categoryIds = <String, int>{};
    final Map<String, int> unitIds = <String, int>{};

    for (final (String name, String description) in _seedCategories) {
      final int id = await db.insert(categories, <String, Object?>{
        categoryName: name,
        categoryDescription: description,
      });
      categoryIds[name] = id;
    }

    for (final String name in _seedUnits) {
      final int id = await db.insert(units, <String, Object?>{unitName: name});
      unitIds[name] = id;
    }

    for (final seed in _seedProducts) {
      final int id = await db.insert(products, <String, Object?>{
        productSku: seed.sku,
        productName: seed.name,
        productCategoryId: categoryIds[seed.category],
        productUnitId: unitIds[seed.unit],
        productCostPrice: seed.cost,
        productSalePrice: seed.sale,
        productStock: seed.stock,
        productMinStock: seed.minStock,
        productIsActive: 1,
        productCreatedAt: timestamp,
        productUpdatedAt: timestamp,
      });
      if (seed.stock != 0) {
        await db.insert(stockMovements, <String, Object?>{
          movementProductId: id,
          movementType: 'initial',
          movementChange: seed.stock,
          movementStockAfter: seed.stock,
          movementReason: 'رصيد افتتاحي',
          movementCreatedBy: null,
          movementCreatedAt: timestamp,
        });
      }
    }
  }

  static Future<void> _createSalesTables(Database db) async {
    await db.execute('''
      CREATE TABLE $customers (
        $customerId INTEGER PRIMARY KEY AUTOINCREMENT,
        $customerName TEXT NOT NULL,
        $customerPhone TEXT,
        $customerNote TEXT,
        $customerIsActive INTEGER NOT NULL DEFAULT 1,
        $customerCreatedAt TEXT NOT NULL,
        $customerUpdatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $salesInvoices (
        $saleId INTEGER PRIMARY KEY AUTOINCREMENT,
        $saleInvoiceNo TEXT NOT NULL UNIQUE,
        $saleCustomerId INTEGER,
        $saleUserId INTEGER,
        $saleDate TEXT NOT NULL,
        $saleSubtotal REAL NOT NULL DEFAULT 0,
        $saleDiscount REAL NOT NULL DEFAULT 0,
        $saleTotal REAL NOT NULL DEFAULT 0,
        $saleStatus TEXT NOT NULL,
        $saleNotes TEXT,
        $saleCreatedAt TEXT NOT NULL,
        $saleCancelledAt TEXT,
        FOREIGN KEY ($saleCustomerId) REFERENCES $customers ($customerId),
        FOREIGN KEY ($saleUserId) REFERENCES $users ($userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE $salesItems (
        $saleItemId INTEGER PRIMARY KEY AUTOINCREMENT,
        $saleItemSaleId INTEGER NOT NULL,
        $saleItemProductId INTEGER NOT NULL,
        $saleItemProductName TEXT NOT NULL,
        $saleItemProductSku TEXT NOT NULL,
        $saleItemQuantity INTEGER NOT NULL,
        $saleItemUnitPrice REAL NOT NULL,
        $saleItemLineTotal REAL NOT NULL,
        FOREIGN KEY ($saleItemSaleId) REFERENCES $salesInvoices ($saleId) ON DELETE CASCADE
      )
    ''');

    await _seedCustomers(db);
  }

  static Future<void> _seedCustomers(Database db) async {
    final String timestamp = _timestamp();
    for (final (String name, String? phone, String note) in _seedCustomerRows) {
      await db.insert(customers, <String, Object?>{
        customerName: name,
        customerPhone: phone,
        customerNote: note,
        customerIsActive: 1,
        customerCreatedAt: timestamp,
        customerUpdatedAt: timestamp,
      });
    }
  }

  static Future<void> _createPurchaseTables(Database db) async {
    await db.execute('''
      CREATE TABLE $suppliers (
        $supplierId INTEGER PRIMARY KEY AUTOINCREMENT,
        $supplierName TEXT NOT NULL,
        $supplierPhone TEXT,
        $supplierNote TEXT,
        $supplierIsActive INTEGER NOT NULL DEFAULT 1,
        $supplierCreatedAt TEXT NOT NULL,
        $supplierUpdatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $purchases (
        $purchaseId INTEGER PRIMARY KEY AUTOINCREMENT,
        $purchaseOrderNo TEXT NOT NULL UNIQUE,
        $purchaseSupplierId INTEGER,
        $purchaseUserId INTEGER,
        $purchaseDate TEXT NOT NULL,
        $purchaseSubtotal REAL NOT NULL DEFAULT 0,
        $purchaseDiscount REAL NOT NULL DEFAULT 0,
        $purchaseTotal REAL NOT NULL DEFAULT 0,
        $purchaseStatus TEXT NOT NULL,
        $purchaseNotes TEXT,
        $purchaseCreatedAt TEXT NOT NULL,
        $purchaseCancelledAt TEXT,
        FOREIGN KEY ($purchaseSupplierId) REFERENCES $suppliers ($supplierId),
        FOREIGN KEY ($purchaseUserId) REFERENCES $users ($userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE $purchaseItems (
        $purchaseItemId INTEGER PRIMARY KEY AUTOINCREMENT,
        $purchaseItemPurchaseId INTEGER NOT NULL,
        $purchaseItemProductId INTEGER NOT NULL,
        $purchaseItemProductName TEXT NOT NULL,
        $purchaseItemProductSku TEXT NOT NULL,
        $purchaseItemQuantity INTEGER NOT NULL,
        $purchaseItemUnitPrice REAL NOT NULL,
        $purchaseItemLineTotal REAL NOT NULL,
        FOREIGN KEY ($purchaseItemPurchaseId) REFERENCES $purchases ($purchaseId) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      final SchemaMigration? migration = migrations[version];
      if (migration != null) {
        await migration(db);
      }
    }
  }

  static Future<void> writeSetting(
    Database db,
    String key,
    String value,
  ) async {
    await db.insert(appSettings, <String, Object?>{
      columnKey: key,
      columnValue: value,
      columnUpdatedAt: _timestamp(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static String _timestamp() => DateTime.now().toUtc().toIso8601String();
}

const List<(String, String)> _seedCategories = <(String, String)>[
  ('مشروبات', 'عصائر ومياه ومشروبات جاهزة'),
  ('مكملات غذائية', 'بروتين وكرياتين ومكملات رياضية'),
  ('أطعمة صحية', 'شوفان ومكسرات ومنتجات غذائية'),
  ('منظفات', 'منظفات وأدوات نظافة'),
];

const List<String> _seedUnits = <String>[
  'قطعة',
  'كيلوجرام',
  'لتر',
  'علبة',
  'كرتون',
];

const List<(String, String?, String)> _seedCustomerRows =
    <(String, String?, String)>[
      ('أحمد محمد', '0501234567', 'عميل دائم'),
      ('مؤسسة النور التجارية', '0557654321', 'حساب جملة'),
      ('سارة العلي', null, 'عميل بيع بالتجزئة'),
    ];

const List<
  ({
    String sku,
    String name,
    String category,
    String unit,
    double cost,
    double sale,
    int stock,
    int minStock,
  })
>
_seedProducts =
    <
      ({
        String sku,
        String name,
        String category,
        String unit,
        double cost,
        double sale,
        int stock,
        int minStock,
      })
    >[
      (
        sku: 'SKP-1001',
        name: 'بروتين مصل اللبن 1 كجم',
        category: 'مكملات غذائية',
        unit: 'كيلوجرام',
        cost: 450,
        sale: 620,
        stock: 40,
        minStock: 10,
      ),
      (
        sku: 'SKP-1002',
        name: 'كرياتين مونوهيدرات 500 جم',
        category: 'مكملات غذائية',
        unit: 'علبة',
        cost: 180,
        sale: 240,
        stock: 8,
        minStock: 10,
      ),
      (
        sku: 'SKP-1003',
        name: 'مياه معدنية 1.5 ل',
        category: 'مشروبات',
        unit: 'قطعة',
        cost: 3,
        sale: 5,
        stock: 240,
        minStock: 48,
      ),
      (
        sku: 'SKP-1004',
        name: 'عصير برتقال طبيعي 1 ل',
        category: 'مشروبات',
        unit: 'لتر',
        cost: 12,
        sale: 18,
        stock: 0,
        minStock: 12,
      ),
      (
        sku: 'SKP-1005',
        name: 'شوفان كامل 1 كجم',
        category: 'أطعمة صحية',
        unit: 'كيلوجرام',
        cost: 25,
        sale: 38,
        stock: 60,
        minStock: 15,
      ),
      (
        sku: 'SKP-1006',
        name: 'مكسرات مشكلة 500 جم',
        category: 'أطعمة صحية',
        unit: 'علبة',
        cost: 55,
        sale: 80,
        stock: 22,
        minStock: 10,
      ),
      (
        sku: 'SKP-1007',
        name: 'صابون سائل 500 مل',
        category: 'منظفات',
        unit: 'قطعة',
        cost: 8,
        sale: 14,
        stock: 30,
        minStock: 12,
      ),
      (
        sku: 'SKP-1008',
        name: 'مناديل ورقية علبة',
        category: 'منظفات',
        unit: 'علبة',
        cost: 6,
        sale: 10,
        stock: 6,
        minStock: 12,
      ),
    ];
