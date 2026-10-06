import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../auth/auth_user.dart';
import '../auth/password_hasher.dart';
import '../auth/permission_action.dart';
import '../auth/permission_defaults.dart';
import '../auth/user_role.dart';
import '../inventory/inventory_models.dart';
import '../sales/sales_models.dart';
import '../purchases/purchase_models.dart';
import 'app_schema.dart';

class AppRuleException implements Exception {
  AppRuleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PermissionGrant {
  const PermissionGrant({
    required this.role,
    required this.resource,
    required this.action,
    required this.allowed,
  });

  factory PermissionGrant.fromRow(Map<String, Object?> row) {
    return PermissionGrant(
      role: row[AppSchema.permissionRole] as String,
      resource: row[AppSchema.permissionResource] as String,
      action: row[AppSchema.permissionAction] as String,
      allowed: ((row[AppSchema.permissionAllowed] as int?) ?? 0) == 1,
    );
  }

  final String role;
  final String resource;
  final String action;
  final bool allowed;
}

class TableStat {
  const TableStat({required this.name, required this.rows});

  final String name;
  final int rows;
}

class DatabaseOverview {
  const DatabaseOverview({
    required this.fileName,
    required this.schemaVersion,
    required this.integrity,
    required this.tables,
  });

  final String fileName;
  final int schemaVersion;
  final String integrity;
  final List<TableStat> tables;

  int get totalRows => tables.fold<int>(0, (sum, table) => sum + table.rows);

  bool get isHealthy => integrity.toLowerCase() == 'ok';
}

class AppDatabase {
  AppDatabase._(this._db, this._fileName);

  final Database _db;
  final String _fileName;

  static const String defaultFileName = 'web_erp.db';

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final DatabaseFactory dbFactory = factory ?? databaseFactoryFfiWeb;
    final String fileName = path ?? defaultFileName;

    final Database db = await dbFactory.openDatabase(
      fileName,
      options: OpenDatabaseOptions(
        version: AppSchema.version,
        onCreate: AppSchema.create,
        onUpgrade: AppSchema.upgrade,
      ),
    );

    return AppDatabase._(db, fileName);
  }

  String get fileName => _fileName;

  Future<int> schemaVersion() => _db.getVersion();

  Future<String> integrityCheck() async {
    final List<Map<String, Object?>> result = await _db.rawQuery(
      'PRAGMA quick_check',
    );
    if (result.isEmpty) {
      return 'unknown';
    }
    return result.first.values.first.toString();
  }

  Future<List<TableStat>> tableStats() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );

    final List<TableStat> stats = <TableStat>[];
    for (final Map<String, Object?> row in rows) {
      final String name = row['name'].toString();
      final List<Map<String, Object?>> count = await _db.rawQuery(
        'SELECT COUNT(*) AS total FROM "$name"',
      );
      stats.add(
        TableStat(name: name, rows: (count.first['total'] as int?) ?? 0),
      );
    }
    return stats;
  }

  Future<DatabaseOverview> overview() async {
    final int version = await schemaVersion();
    final String integrity = await integrityCheck();
    final List<TableStat> tables = await tableStats();
    return DatabaseOverview(
      fileName: _fileName,
      schemaVersion: version,
      integrity: integrity,
      tables: tables,
    );
  }

  Future<String?> readSetting(String key) async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppSchema.appSettings,
      columns: <String>[AppSchema.columnValue],
      where: '${AppSchema.columnKey} = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first[AppSchema.columnValue] as String?;
  }

  Future<Map<String, String>> readSettings() async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppSchema.appSettings,
      orderBy: '${AppSchema.columnKey} ASC',
    );
    return <String, String>{
      for (final Map<String, Object?> row in rows)
        row[AppSchema.columnKey] as String:
            row[AppSchema.columnValue] as String,
    };
  }

  Future<void> writeSetting(String key, String value) async {
    await writeSettings(<String, String>{key: value});
  }

  Future<void> writeSettings(Map<String, String> values) async {
    final Batch batch = _db.batch();
    final String timestamp = DateTime.now().toUtc().toIso8601String();
    values.forEach((String key, String value) {
      batch.insert(AppSchema.appSettings, <String, Object?>{
        AppSchema.columnKey: key,
        AppSchema.columnValue: value,
        AppSchema.columnUpdatedAt: timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await batch.commit(noResult: true);
  }

  Future<void> close() => _db.close();

  Future<int> countUsers() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppSchema.users}',
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<AuthUser?> findUserByEmail(String email) async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppSchema.users,
      where: 'LOWER(${AppSchema.userEmail}) = ?',
      whereArgs: <Object?>[email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return AuthUser.fromRow(rows.first);
  }

  Future<AuthUser?> userById(int id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppSchema.users,
      where: '${AppSchema.userId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return AuthUser.fromRow(rows.first);
  }

  Future<List<AuthUser>> listUsers() async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppSchema.users,
      orderBy: '${AppSchema.userId} ASC',
    );
    return rows.map(AuthUser.fromRow).toList();
  }

  Future<AuthUser?> authenticate({
    required String email,
    required String password,
  }) async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppSchema.users,
      where: 'LOWER(${AppSchema.userEmail}) = ?',
      whereArgs: <Object?>[email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    final Map<String, Object?> row = rows.first;
    if (((row[AppSchema.userIsActive] as int?) ?? 0) != 1) {
      return null;
    }

    final bool valid = PasswordHasher.verify(
      password: password,
      salt: row[AppSchema.userSalt] as String,
      expectedHash: row[AppSchema.userPasswordHash] as String,
    );
    if (!valid) {
      return null;
    }

    final String now = _timestamp();
    await _db.update(
      AppSchema.users,
      <String, Object?>{AppSchema.userLastLoginAt: now},
      where: '${AppSchema.userId} = ?',
      whereArgs: <Object?>[row[AppSchema.userId]],
    );

    return AuthUser.fromRow(<String, Object?>{
      ...row,
      AppSchema.userLastLoginAt: now,
    });
  }

  Future<String> createSession(
    int userId, {
    Duration ttl = const Duration(days: 30),
  }) async {
    final String token = PasswordHasher.randomSalt(32);
    final DateTime now = DateTime.now().toUtc();
    await _db.insert(AppSchema.sessions, <String, Object?>{
      AppSchema.sessionToken: token,
      AppSchema.sessionUserId: userId,
      AppSchema.sessionCreatedAt: now.toIso8601String(),
      AppSchema.sessionExpiresAt: now.add(ttl).toIso8601String(),
    });
    return token;
  }

  Future<AuthUser?> sessionUser(String? token) async {
    if (token == null || token.isEmpty) {
      return null;
    }

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT u.* FROM ${AppSchema.users} u
      INNER JOIN ${AppSchema.sessions} s ON s.${AppSchema.sessionUserId} = u.${AppSchema.userId}
      WHERE s.${AppSchema.sessionToken} = ? AND s.${AppSchema.sessionExpiresAt} > ?
      ''',
      <Object?>[token, _timestamp()],
    );
    if (rows.isEmpty) {
      return null;
    }
    final AuthUser user = AuthUser.fromRow(rows.first);
    return user.isActive ? user : null;
  }

  Future<void> deleteSession(String token) async {
    await _db.delete(
      AppSchema.sessions,
      where: '${AppSchema.sessionToken} = ?',
      whereArgs: <Object?>[token],
    );
  }

  Future<void> deleteExpiredSessions() async {
    await _db.delete(
      AppSchema.sessions,
      where: '${AppSchema.sessionExpiresAt} <= ?',
      whereArgs: <Object?>[_timestamp()],
    );
  }

  Future<List<PermissionGrant>> listPermissions() async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppSchema.rolePermissions,
      orderBy:
          '${AppSchema.permissionRole} ASC, ${AppSchema.permissionResource} ASC, ${AppSchema.permissionAction} ASC',
    );
    return rows.map(PermissionGrant.fromRow).toList();
  }

  Future<void> setPermission({
    required String role,
    required String resource,
    required String action,
    required bool allowed,
  }) async {
    if (role == UserRole.admin.id) {
      throw AppRuleException('لا يمكن تعديل صلاحيات دور مدير النظام');
    }
    if (!PermissionDefaults.isResource(resource)) {
      throw AppRuleException('صفحة غير معروفة: $resource');
    }
    if (PermissionAction.parse(action) == null) {
      throw AppRuleException('إجراء غير معروف: $action');
    }

    if (allowed) {
      await _db.insert(AppSchema.rolePermissions, <String, Object?>{
        AppSchema.permissionRole: role,
        AppSchema.permissionResource: resource,
        AppSchema.permissionAction: action,
        AppSchema.permissionAllowed: 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await _db.delete(
        AppSchema.rolePermissions,
        where:
            '${AppSchema.permissionRole} = ? AND ${AppSchema.permissionResource} = ? AND ${AppSchema.permissionAction} = ?',
        whereArgs: <Object?>[role, resource, action],
      );
    }
  }

  Future<void> resetPermissions() async {
    await _db.delete(AppSchema.rolePermissions);
    final Batch batch = _db.batch();
    for (final (String role, String resource, String action)
        in PermissionDefaults.seedRows()) {
      batch.insert(AppSchema.rolePermissions, <String, Object?>{
        AppSchema.permissionRole: role,
        AppSchema.permissionResource: resource,
        AppSchema.permissionAction: action,
        AppSchema.permissionAllowed: 1,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<int> activeAdminCount() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      "SELECT COUNT(*) AS total FROM ${AppSchema.users} "
      "WHERE ${AppSchema.userRole} = ? AND ${AppSchema.userIsActive} = 1",
      <Object?>[UserRole.admin.id],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<AuthUser> createUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    bool isActive = true,
  }) async {
    final String cleanEmail = _cleanEmail(email);
    _validateFullName(fullName);
    _validatePassword(password);

    if (await findUserByEmail(cleanEmail) != null) {
      throw AppRuleException('البريد الإلكتروني مستخدم بالفعل');
    }

    final String salt = PasswordHasher.randomSalt();
    final int id = await _db.insert(AppSchema.users, <String, Object?>{
      AppSchema.userEmail: cleanEmail,
      AppSchema.userPasswordHash: PasswordHasher.hash(password, salt),
      AppSchema.userSalt: salt,
      AppSchema.userFullName: fullName.trim(),
      AppSchema.userRole: role.id,
      AppSchema.userIsActive: isActive ? 1 : 0,
      AppSchema.userCreatedAt: _timestamp(),
    });

    final AuthUser? created = await userById(id);
    if (created == null) {
      throw AppRuleException('تعذر إنشاء المستخدم');
    }
    return created;
  }

  Future<AuthUser> updateUser({
    required int id,
    String? email,
    String? fullName,
    UserRole? role,
    bool? isActive,
    String? password,
  }) async {
    final AuthUser? current = await userById(id);
    if (current == null) {
      throw AppRuleException('المستخدم غير موجود');
    }

    final String targetRole = role?.id ?? current.role.id;
    final bool targetActive = isActive ?? current.isActive;
    final bool losesAdmin =
        current.role == UserRole.admin &&
        current.isActive &&
        (targetRole != UserRole.admin.id || !targetActive);
    if (losesAdmin && await activeAdminCount() <= 1) {
      throw AppRuleException('لا يمكن تعطيل أو تغيير دور آخر مدير نظام');
    }

    final Map<String, Object?> values = <String, Object?>{};

    if (email != null) {
      final String cleanEmail = _cleanEmail(email);
      final AuthUser? existing = await findUserByEmail(cleanEmail);
      if (existing != null && existing.id != id) {
        throw AppRuleException('البريد الإلكتروني مستخدم بالفعل');
      }
      values[AppSchema.userEmail] = cleanEmail;
    }

    if (fullName != null) {
      _validateFullName(fullName);
      values[AppSchema.userFullName] = fullName.trim();
    }

    if (role != null) {
      values[AppSchema.userRole] = role.id;
    }

    if (isActive != null) {
      values[AppSchema.userIsActive] = isActive ? 1 : 0;
      if (!isActive) {
        await _db.delete(
          AppSchema.sessions,
          where: '${AppSchema.sessionUserId} = ?',
          whereArgs: <Object?>[id],
        );
      }
    }

    if (password != null && password.isNotEmpty) {
      _validatePassword(password);
      final String salt = PasswordHasher.randomSalt();
      values[AppSchema.userPasswordHash] = PasswordHasher.hash(password, salt);
      values[AppSchema.userSalt] = salt;
      await _db.delete(
        AppSchema.sessions,
        where: '${AppSchema.sessionUserId} = ?',
        whereArgs: <Object?>[id],
      );
    }

    if (values.isEmpty) {
      return current;
    }

    await _db.update(
      AppSchema.users,
      values,
      where: '${AppSchema.userId} = ?',
      whereArgs: <Object?>[id],
    );

    final AuthUser? updated = await userById(id);
    if (updated == null) {
      throw AppRuleException('تعذر تحديث المستخدم');
    }
    return updated;
  }

  Future<void> deleteUser(int id) async {
    final AuthUser? current = await userById(id);
    if (current == null) {
      throw AppRuleException('المستخدم غير موجود');
    }
    if (current.role == UserRole.admin &&
        current.isActive &&
        await activeAdminCount() <= 1) {
      throw AppRuleException('لا يمكن حذف آخر مدير نظام');
    }

    await _db.delete(
      AppSchema.sessions,
      where: '${AppSchema.sessionUserId} = ?',
      whereArgs: <Object?>[id],
    );
    await _db.delete(
      AppSchema.users,
      where: '${AppSchema.userId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  static const String _categorySelect =
      'SELECT c.*, (SELECT COUNT(*) FROM ${AppSchema.products} p '
      'WHERE p.${AppSchema.productCategoryId} = c.${AppSchema.categoryId}) AS product_count '
      'FROM ${AppSchema.categories} c';

  static const String _unitSelect =
      'SELECT u.*, (SELECT COUNT(*) FROM ${AppSchema.products} p '
      'WHERE p.${AppSchema.productUnitId} = u.${AppSchema.unitId}) AS product_count '
      'FROM ${AppSchema.units} u';

  static const String _productSelect =
      'SELECT p.*, c.name AS category_name, u.name AS unit_name '
      'FROM ${AppSchema.products} p '
      'LEFT JOIN ${AppSchema.categories} c ON c.${AppSchema.categoryId} = p.${AppSchema.productCategoryId} '
      'LEFT JOIN ${AppSchema.units} u ON u.${AppSchema.unitId} = p.${AppSchema.productUnitId} ';

  static const String _movementSelect =
      'SELECT m.*, p.${AppSchema.productName} AS product_name, '
      'p.${AppSchema.productSku} AS product_sku, '
      'u.${AppSchema.userFullName} AS created_by_name '
      'FROM ${AppSchema.stockMovements} m '
      'LEFT JOIN ${AppSchema.products} p ON p.${AppSchema.productId} = m.${AppSchema.movementProductId} '
      'LEFT JOIN ${AppSchema.users} u ON u.${AppSchema.userId} = m.${AppSchema.movementCreatedBy} ';

  Future<List<InventoryCategory>> listCategories() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_categorySelect ORDER BY ${AppSchema.categoryName} COLLATE NOCASE ASC',
    );
    return rows.map(InventoryCategory.fromRow).toList();
  }

  Future<InventoryCategory?> _categoryById(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_categorySelect WHERE c.${AppSchema.categoryId} = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return InventoryCategory.fromRow(rows.first);
  }

  Future<void> _requireCategory(int id) async {
    if (await _categoryById(id) == null) {
      throw AppRuleException('التصنيف غير موجود');
    }
  }

  Future<InventoryCategory> createCategory({
    required String name,
    String? description,
  }) async {
    final String cleanName = _requireLabel(name, 'اسم التصنيف');
    final String? cleanDescription = _cleanOptional(description);
    await _ensureUniqueValue(
      AppSchema.categories,
      AppSchema.categoryName,
      cleanName,
      'التصنيف موجود بالفعل',
    );

    final int id = await _db.insert(AppSchema.categories, <String, Object?>{
      AppSchema.categoryName: cleanName,
      AppSchema.categoryDescription: cleanDescription,
    });

    return InventoryCategory(
      id: id,
      name: cleanName,
      description: cleanDescription,
    );
  }

  Future<InventoryCategory> updateCategory(
    int id, {
    String? name,
    String? description,
  }) async {
    await _requireCategory(id);
    final Map<String, Object?> values = <String, Object?>{};

    if (name != null) {
      final String cleanName = _requireLabel(name, 'اسم التصنيف');
      await _ensureUniqueValue(
        AppSchema.categories,
        AppSchema.categoryName,
        cleanName,
        'التصنيف موجود بالفعل',
        excludeId: id,
      );
      values[AppSchema.categoryName] = cleanName;
    }

    if (description != null) {
      values[AppSchema.categoryDescription] = _cleanOptional(description);
    }

    if (values.isNotEmpty) {
      await _db.update(
        AppSchema.categories,
        values,
        where: '${AppSchema.categoryId} = ?',
        whereArgs: <Object?>[id],
      );
    }

    final InventoryCategory? updated = await _categoryById(id);
    if (updated == null) {
      throw AppRuleException('تعذر تحديث التصنيف');
    }
    return updated;
  }

  Future<void> deleteCategory(int id) async {
    await _requireCategory(id);
    final List<Map<String, Object?>> rows = await _db.query(
      AppSchema.products,
      columns: <String>[AppSchema.productId],
      where: '${AppSchema.productCategoryId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw AppRuleException('لا يمكن حذف تصنيف مرتبط بمنتجات');
    }
    await _db.delete(
      AppSchema.categories,
      where: '${AppSchema.categoryId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<List<InventoryUnit>> listUnits() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_unitSelect ORDER BY ${AppSchema.unitName} COLLATE NOCASE ASC',
    );
    return rows.map(InventoryUnit.fromRow).toList();
  }

  Future<InventoryUnit?> _unitById(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_unitSelect WHERE u.${AppSchema.unitId} = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return InventoryUnit.fromRow(rows.first);
  }

  Future<void> _requireUnit(int id) async {
    if (await _unitById(id) == null) {
      throw AppRuleException('الوحدة غير موجودة');
    }
  }

  Future<InventoryUnit> createUnit(String name) async {
    final String cleanName = _requireLabel(name, 'اسم الوحدة');
    await _ensureUniqueValue(
      AppSchema.units,
      AppSchema.unitName,
      cleanName,
      'الوحدة موجودة بالفعل',
    );

    final int id = await _db.insert(AppSchema.units, <String, Object?>{
      AppSchema.unitName: cleanName,
    });
    return InventoryUnit(id: id, name: cleanName);
  }

  Future<InventoryUnit> updateUnit(int id, String name) async {
    await _requireUnit(id);
    final String cleanName = _requireLabel(name, 'اسم الوحدة');
    await _ensureUniqueValue(
      AppSchema.units,
      AppSchema.unitName,
      cleanName,
      'الوحدة موجودة بالفعل',
      excludeId: id,
    );

    await _db.update(
      AppSchema.units,
      <String, Object?>{AppSchema.unitName: cleanName},
      where: '${AppSchema.unitId} = ?',
      whereArgs: <Object?>[id],
    );

    final InventoryUnit? updated = await _unitById(id);
    if (updated == null) {
      throw AppRuleException('تعذر تحديث الوحدة');
    }
    return updated;
  }

  Future<void> deleteUnit(int id) async {
    await _requireUnit(id);
    final List<Map<String, Object?>> rows = await _db.query(
      AppSchema.products,
      columns: <String>[AppSchema.productId],
      where: '${AppSchema.productUnitId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw AppRuleException('لا يمكن حذف وحدة مرتبطة بمنتجات');
    }
    await _db.delete(
      AppSchema.units,
      where: '${AppSchema.unitId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<PagedResult<Product>> listProducts(ProductQuery query) async {
    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];

    final String search = query.search.trim();
    if (search.isNotEmpty) {
      clauses.add(
        '(p.${AppSchema.productName} LIKE ? COLLATE NOCASE '
        'OR p.${AppSchema.productSku} LIKE ? COLLATE NOCASE)',
      );
      args.add('%$search%');
      args.add('%$search%');
    }

    if (query.categoryId != null) {
      clauses.add('p.${AppSchema.productCategoryId} = ?');
      args.add(query.categoryId);
    }

    switch (query.stockFilter) {
      case StockFilter.all:
        break;
      case StockFilter.out:
        clauses.add('p.${AppSchema.productStock} <= 0');
        break;
      case StockFilter.low:
        clauses.add(
          'p.${AppSchema.productStock} > 0 '
          'AND p.${AppSchema.productStock} <= p.${AppSchema.productMinStock}',
        );
        break;
      case StockFilter.ok:
        clauses.add(
          'p.${AppSchema.productStock} > p.${AppSchema.productMinStock}',
        );
        break;
    }

    final String where = clauses.isEmpty
        ? ''
        : 'WHERE ${clauses.join(' AND ')}';

    final List<Map<String, Object?>> countRows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppSchema.products} p $where',
      args,
    );
    final int total = (countRows.first['total'] as int?) ?? 0;

    final int pageSize = _clampPageSize(query.pageSize);
    final int pageCount = total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
    final int page = query.page.clamp(1, pageCount).toInt();
    final int offset = (page - 1) * pageSize;

    final String orderColumn = _productSortColumn(query.sort);
    final String direction = query.ascending ? 'ASC' : 'DESC';

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_productSelect$where '
      'ORDER BY $orderColumn $direction, p.${AppSchema.productId} ASC '
      'LIMIT ? OFFSET ?',
      <Object?>[...args, pageSize, offset],
    );

    return PagedResult<Product>(
      items: rows.map(Product.fromRow).toList(),
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Product?> productById(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_productSelect WHERE p.${AppSchema.productId} = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return Product.fromRow(rows.first);
  }

  Future<Product> createProduct({
    required String sku,
    required String name,
    int? categoryId,
    required int unitId,
    double costPrice = 0,
    double salePrice = 0,
    int stock = 0,
    int minStock = 0,
    bool isActive = true,
  }) async {
    final String cleanSku = _requireSku(sku);
    final String cleanName = _requireLabel(name, 'اسم المنتج');
    _validatePrice(costPrice, 'سعر التكلفة');
    _validatePrice(salePrice, 'سعر البيع');
    _validateCount(stock, 'الرصيد الابتدائي');
    _validateCount(minStock, 'الحد الأدنى');
    await _ensureUniqueValue(
      AppSchema.products,
      AppSchema.productSku,
      cleanSku,
      'كود المنتج مستخدم بالفعل',
    );
    if (categoryId != null) {
      await _requireCategory(categoryId);
    }
    await _requireUnit(unitId);

    final String timestamp = _timestamp();
    final int id = await _db.transaction((Transaction txn) async {
      final int inserted = await txn.insert(
        AppSchema.products,
        <String, Object?>{
          AppSchema.productSku: cleanSku,
          AppSchema.productName: cleanName,
          AppSchema.productCategoryId: categoryId,
          AppSchema.productUnitId: unitId,
          AppSchema.productCostPrice: costPrice,
          AppSchema.productSalePrice: salePrice,
          AppSchema.productStock: stock,
          AppSchema.productMinStock: minStock,
          AppSchema.productIsActive: isActive ? 1 : 0,
          AppSchema.productCreatedAt: timestamp,
          AppSchema.productUpdatedAt: timestamp,
        },
      );
      if (stock > 0) {
        await txn.insert(AppSchema.stockMovements, <String, Object?>{
          AppSchema.movementProductId: inserted,
          AppSchema.movementType: MovementType.initial.id,
          AppSchema.movementChange: stock,
          AppSchema.movementStockAfter: stock,
          AppSchema.movementReason: 'رصيد افتتاحي',
          AppSchema.movementCreatedBy: null,
          AppSchema.movementCreatedAt: timestamp,
        });
      }
      return inserted;
    });

    final Product? created = await productById(id);
    if (created == null) {
      throw AppRuleException('تعذر إنشاء المنتج');
    }
    return created;
  }

  Future<Product> updateProduct({
    required int id,
    required String sku,
    required String name,
    int? categoryId,
    required int unitId,
    required double costPrice,
    required double salePrice,
    required int minStock,
    required bool isActive,
    int? stock,
  }) async {
    if (await productById(id) == null) {
      throw AppRuleException('المنتج غير موجود');
    }
    final String cleanSku = _requireSku(sku);
    final String cleanName = _requireLabel(name, 'اسم المنتج');
    _validatePrice(costPrice, 'سعر التكلفة');
    _validatePrice(salePrice, 'سعر البيع');
    _validateCount(minStock, 'الحد الأدنى');
    await _ensureUniqueValue(
      AppSchema.products,
      AppSchema.productSku,
      cleanSku,
      'كود المنتج مستخدم بالفعل',
      excludeId: id,
    );
    if (categoryId != null) {
      await _requireCategory(categoryId);
    }
    await _requireUnit(unitId);

    final Map<String, Object?> updateValues = <String, Object?>{
        AppSchema.productSku: cleanSku,
        AppSchema.productName: cleanName,
        AppSchema.productCategoryId: categoryId,
        AppSchema.productUnitId: unitId,
        AppSchema.productCostPrice: costPrice,
        AppSchema.productSalePrice: salePrice,
        AppSchema.productMinStock: minStock,
        AppSchema.productIsActive: isActive ? 1 : 0,
        AppSchema.productUpdatedAt: _timestamp(),
      };
    if (stock != null) {
      updateValues[AppSchema.productStock] = stock;
    }
    await _db.update(
      AppSchema.products,
      updateValues,
      where: '${AppSchema.productId} = ?',
      whereArgs: <Object?>[id],
    );

    final Product? updated = await productById(id);
    if (updated == null) {
      throw AppRuleException('تعذر تحديث المنتج');
    }
    return updated;
  }

  Future<void> deleteProduct(int id) async {
    if (await productById(id) == null) {
      throw AppRuleException('المنتج غير موجود');
    }

    final List<Map<String, Object?>> tracked = await _db.query(
      AppSchema.stockMovements,
      columns: <String>[AppSchema.movementId],
      where:
          '${AppSchema.movementProductId} = ? '
          'AND ${AppSchema.movementType} != ?',
      whereArgs: <Object?>[id, MovementType.initial.id],
      limit: 1,
    );
    if (tracked.isNotEmpty) {
      throw AppRuleException('لا يمكن حذف منتج له حركات مبيعات أو تسوية');
    }

    await _db.transaction((Transaction txn) async {
      await txn.delete(
        AppSchema.stockMovements,
        where: '${AppSchema.movementProductId} = ?',
        whereArgs: <Object?>[id],
      );
      await txn.delete(
        AppSchema.products,
        where: '${AppSchema.productId} = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  Future<void> postMovement({
    required int productId,
    required MovementType type,
    required int quantityChange,
    required String reason,
    int? createdBy,
  }) async {
    if (quantityChange == 0) {
      throw AppRuleException('قيمة الحركة لا يمكن أن تكون صفر');
    }
    final String cleanReason = _requireLabel(reason, 'سبب الحركة');

    await _db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> rows = await txn.query(
        AppSchema.products,
        where: '${AppSchema.productId} = ?',
        whereArgs: <Object?>[productId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw AppRuleException('المنتج غير موجود');
      }

      final int current = (rows.first[AppSchema.productStock] as int?) ?? 0;
      final int next = current + quantityChange;
      if (next < 0) {
        throw AppRuleException('الرصيد لا يكفي، المتوفر $current فقط');
      }

      await txn.update(
        AppSchema.products,
        <String, Object?>{
          AppSchema.productStock: next,
          AppSchema.productUpdatedAt: _timestamp(),
        },
        where: '${AppSchema.productId} = ?',
        whereArgs: <Object?>[productId],
      );
      await txn.insert(AppSchema.stockMovements, <String, Object?>{
        AppSchema.movementProductId: productId,
        AppSchema.movementType: type.id,
        AppSchema.movementChange: quantityChange,
        AppSchema.movementStockAfter: next,
        AppSchema.movementReason: cleanReason,
        AppSchema.movementCreatedBy: createdBy,
        AppSchema.movementCreatedAt: _timestamp(),
      });
    });
  }

  Future<void> adjustStock({
    required int productId,
    required int newQuantity,
    required String reason,
    int? createdBy,
  }) async {
    if (newQuantity < 0) {
      throw AppRuleException('الرصيد الجديد لا يمكن أن يكون أقل من صفر');
    }

    final Product? product = await productById(productId);
    if (product == null) {
      throw AppRuleException('المنتج غير موجود');
    }

    final int delta = newQuantity - product.stock;
    if (delta == 0) {
      throw AppRuleException('الرصيد الحالي مطابق للقيمة الجديدة');
    }

    await postMovement(
      productId: productId,
      type: MovementType.adjustment,
      quantityChange: delta,
      reason: reason,
      createdBy: createdBy,
    );
  }

  Future<PagedResult<StockMovement>> listMovements({
    String search = '',
    MovementType? type,
    int page = 1,
    int pageSize = 10,
  }) async {
    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];

    final String cleanSearch = search.trim();
    if (cleanSearch.isNotEmpty) {
      clauses.add(
        '(p.${AppSchema.productName} LIKE ? COLLATE NOCASE '
        'OR p.${AppSchema.productSku} LIKE ? COLLATE NOCASE '
        'OR m.${AppSchema.movementReason} LIKE ? COLLATE NOCASE)',
      );
      args.add('%$cleanSearch%');
      args.add('%$cleanSearch%');
      args.add('%$cleanSearch%');
    }

    if (type != null) {
      clauses.add('m.${AppSchema.movementType} = ?');
      args.add(type.id);
    }

    final String where = clauses.isEmpty
        ? ''
        : 'WHERE ${clauses.join(' AND ')}';

    final List<Map<String, Object?>> countRows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppSchema.stockMovements} m '
      'LEFT JOIN ${AppSchema.products} p '
      'ON p.${AppSchema.productId} = m.${AppSchema.movementProductId} $where',
      args,
    );
    final int total = (countRows.first['total'] as int?) ?? 0;

    final int size = _clampPageSize(pageSize);
    final int pageCount = total == 0 ? 1 : (total + size - 1) ~/ size;
    final int currentPage = page.clamp(1, pageCount).toInt();
    final int offset = (currentPage - 1) * size;

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_movementSelect$where '
      'ORDER BY m.${AppSchema.movementCreatedAt} DESC, m.${AppSchema.movementId} DESC '
      'LIMIT ? OFFSET ?',
      <Object?>[...args, size, offset],
    );

    return PagedResult<StockMovement>(
      items: rows.map(StockMovement.fromRow).toList(),
      total: total,
      page: currentPage,
      pageSize: size,
    );
  }

  static const String _customerSelect =
      'SELECT cu.*, (SELECT COUNT(*) FROM ${AppSchema.salesInvoices} s '
      'WHERE s.${AppSchema.saleCustomerId} = cu.${AppSchema.customerId}) AS sale_count '
      'FROM ${AppSchema.customers} cu ';

  static const String _saleSelect =
      'SELECT s.*, cu.${AppSchema.customerName} AS customer_name, '
      'u.${AppSchema.userFullName} AS user_name '
      'FROM ${AppSchema.salesInvoices} s '
      'LEFT JOIN ${AppSchema.customers} cu ON cu.${AppSchema.customerId} = s.${AppSchema.saleCustomerId} '
      'LEFT JOIN ${AppSchema.users} u ON u.${AppSchema.userId} = s.${AppSchema.saleUserId} ';

  Future<PagedResult<Customer>> listCustomers({
    String search = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];

    final String cleanSearch = search.trim();
    if (cleanSearch.isNotEmpty) {
      clauses.add(
        '(cu.${AppSchema.customerName} LIKE ? COLLATE NOCASE '
        'OR cu.${AppSchema.customerPhone} LIKE ? COLLATE NOCASE)',
      );
      args.add('%$cleanSearch%');
      args.add('%$cleanSearch%');
    }

    final String where = clauses.isEmpty
        ? ''
        : 'WHERE ${clauses.join(' AND ')}';

    final List<Map<String, Object?>> countRows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppSchema.customers} cu $where',
      args,
    );
    final int total = (countRows.first['total'] as int?) ?? 0;

    final int size = _clampPageSize(pageSize);
    final int pageCount = total == 0 ? 1 : (total + size - 1) ~/ size;
    final int currentPage = page.clamp(1, pageCount).toInt();
    final int offset = (currentPage - 1) * size;

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_customerSelect$where '
      'ORDER BY cu.${AppSchema.customerName} COLLATE NOCASE ASC, cu.${AppSchema.customerId} ASC '
      'LIMIT ? OFFSET ?',
      <Object?>[...args, size, offset],
    );

    return PagedResult<Customer>(
      items: rows.map(Customer.fromRow).toList(),
      total: total,
      page: currentPage,
      pageSize: size,
    );
  }

  Future<Customer?> customerById(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_customerSelect WHERE cu.${AppSchema.customerId} = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return Customer.fromRow(rows.first);
  }

  Future<void> _requireCustomer(int id) async {
    if (await customerById(id) == null) {
      throw AppRuleException('العميل غير موجود');
    }
  }

  Future<List<Customer>> activeCustomers({int limit = 100}) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_customerSelect WHERE cu.${AppSchema.customerIsActive} = 1 '
      'ORDER BY cu.${AppSchema.customerName} COLLATE NOCASE ASC '
      'LIMIT ?',
      <Object?>[limit],
    );
    return rows.map(Customer.fromRow).toList();
  }

  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? note,
    bool isActive = true,
  }) async {
    final String cleanName = _requireLabel(name, 'اسم العميل');
    final String? cleanPhone = _validatePhone(phone);
    final String? cleanNote = _cleanOptional(note);

    final String timestamp = _timestamp();
    final int id = await _db.insert(AppSchema.customers, <String, Object?>{
      AppSchema.customerName: cleanName,
      AppSchema.customerPhone: cleanPhone,
      AppSchema.customerNote: cleanNote,
      AppSchema.customerIsActive: isActive ? 1 : 0,
      AppSchema.customerCreatedAt: timestamp,
      AppSchema.customerUpdatedAt: timestamp,
    });

    final Customer? created = await customerById(id);
    if (created == null) {
      throw AppRuleException('تعذر إنشاء العميل');
    }
    return created;
  }

  Future<Customer> updateCustomer(
    int id, {
    String? name,
    String? phone,
    String? note,
    bool? isActive,
  }) async {
    await _requireCustomer(id);
    final Map<String, Object?> values = <String, Object?>{};

    if (name != null) {
      values[AppSchema.customerName] = _requireLabel(name, 'اسم العميل');
    }
    if (phone != null) {
      values[AppSchema.customerPhone] = _validatePhone(phone);
    }
    if (note != null) {
      values[AppSchema.customerNote] = _cleanOptional(note);
    }
    if (isActive != null) {
      values[AppSchema.customerIsActive] = isActive ? 1 : 0;
    }

    if (values.isNotEmpty) {
      values[AppSchema.customerUpdatedAt] = _timestamp();
      await _db.update(
        AppSchema.customers,
        values,
        where: '${AppSchema.customerId} = ?',
        whereArgs: <Object?>[id],
      );
    }

    final Customer? updated = await customerById(id);
    if (updated == null) {
      throw AppRuleException('تعذر تحديث العميل');
    }
    return updated;
  }

  Future<void> deleteCustomer(int id) async {
    await _requireCustomer(id);
    final List<Map<String, Object?>> rows = await _db.query(
      AppSchema.salesInvoices,
      columns: <String>[AppSchema.saleId],
      where: '${AppSchema.saleCustomerId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw AppRuleException('لا يمكن حذف عميل له فواتير مبيعات');
    }
    await _db.delete(
      AppSchema.customers,
      where: '${AppSchema.customerId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<PagedResult<Sale>> listSales(SaleQuery query) async {
    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];

    final String search = query.search.trim();
    if (search.isNotEmpty) {
      clauses.add(
        '(s.${AppSchema.saleInvoiceNo} LIKE ? COLLATE NOCASE '
        'OR cu.${AppSchema.customerName} LIKE ? COLLATE NOCASE)',
      );
      args.add('%$search%');
      args.add('%$search%');
    }

    if (query.status != null) {
      clauses.add('s.${AppSchema.saleStatus} = ?');
      args.add(query.status!.id);
    }

    final String where = clauses.isEmpty
        ? ''
        : 'WHERE ${clauses.join(' AND ')}';

    final List<Map<String, Object?>> countRows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppSchema.salesInvoices} s '
      'LEFT JOIN ${AppSchema.customers} cu '
      'ON cu.${AppSchema.customerId} = s.${AppSchema.saleCustomerId} $where',
      args,
    );
    final int total = (countRows.first['total'] as int?) ?? 0;

    final int size = _clampPageSize(query.pageSize);
    final int pageCount = total == 0 ? 1 : (total + size - 1) ~/ size;
    final int currentPage = query.page.clamp(1, pageCount).toInt();
    final int offset = (currentPage - 1) * size;

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_saleSelect$where '
      'ORDER BY s.${AppSchema.saleDate} DESC, s.${AppSchema.saleId} DESC '
      'LIMIT ? OFFSET ?',
      <Object?>[...args, size, offset],
    );

    return PagedResult<Sale>(
      items: rows.map(Sale.fromRow).toList(),
      total: total,
      page: currentPage,
      pageSize: size,
    );
  }

  Future<Sale?> saleById(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_saleSelect WHERE s.${AppSchema.saleId} = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }

    final List<Map<String, Object?>> itemRows = await _db.rawQuery(
      'SELECT * FROM ${AppSchema.salesItems} '
      'WHERE ${AppSchema.saleItemSaleId} = ? '
      'ORDER BY ${AppSchema.saleItemId} ASC',
      <Object?>[id],
    );
    return Sale.fromRow(rows.first)
        .withItems(itemRows.map(SaleLine.fromRow).toList());
  }

  Future<Sale> createSale({
    int? customerId,
    required List<SaleLineInput> items,
    double discount = 0,
    String? notes,
    int? createdBy,
  }) async {
    if (items.isEmpty) {
      throw AppRuleException('يجب إضافة منتج واحد على الأقل');
    }
    if (discount < 0) {
      throw AppRuleException('الخصم لا يمكن أن يكون أقل من صفر');
    }
    final String? cleanNotes = _cleanOptional(notes);
    if (customerId != null) {
      await _requireCustomer(customerId);
    }

    final Set<int> seen = <int>{};
    for (final SaleLineInput item in items) {
      if (item.productId <= 0) {
        throw AppRuleException('منتج غير صالح في الفاتورة');
      }
      if (!seen.add(item.productId)) {
        throw AppRuleException('لا يمكن تكرار المنتج نفسه في الفاتورة');
      }
      _validateCount(item.quantity, 'الكمية');
      _validatePrice(item.unitPrice, 'سعر البيع');
      if (item.quantity <= 0) {
        throw AppRuleException('الكمية يجب أن تكون أكبر من صفر');
      }
    }

    final String timestamp = _timestamp();
    final int id = await _db.transaction((Transaction txn) async {
      final Map<int, Map<String, Object?>> products =
          <int, Map<String, Object?>>{};
      double subtotal = 0;
      for (final SaleLineInput item in items) {
        final List<Map<String, Object?>> rows = await txn.query(
          AppSchema.products,
          where: '${AppSchema.productId} = ?',
          whereArgs: <Object?>[item.productId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw AppRuleException('المنتج غير موجود');
        }
        final Map<String, Object?> product = rows.first;
        if (((product[AppSchema.productIsActive] as int?) ?? 0) != 1) {
          throw AppRuleException(
            'المنتج «${product[AppSchema.productName]}» غير مفعل',
          );
        }
        products[item.productId] = product;
        subtotal += roundMoney(item.quantity * item.unitPrice);
      }

      subtotal = roundMoney(subtotal);
      final double cleanDiscount = roundMoney(discount);
      if (cleanDiscount > subtotal) {
        throw AppRuleException('الخصم أكبر من مجموع الفاتورة');
      }
      final double total = roundMoney(subtotal - cleanDiscount);

      final List<Map<String, Object?>> sequenceRows = await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM ${AppSchema.salesInvoices}',
      );
      final int sequence = (sequenceRows.first['c'] as int?) ?? 0;
      final String invoiceNo =
          'INV-${(sequence + 1).toString().padLeft(6, '0')}';

      final int saleId = await txn.insert(
        AppSchema.salesInvoices,
        <String, Object?>{
          AppSchema.saleInvoiceNo: invoiceNo,
          AppSchema.saleCustomerId: customerId,
          AppSchema.saleUserId: createdBy,
          AppSchema.saleDate: timestamp,
          AppSchema.saleSubtotal: subtotal,
          AppSchema.saleDiscount: cleanDiscount,
          AppSchema.saleTotal: total,
          AppSchema.saleStatus: SaleStatus.completed.id,
          AppSchema.saleNotes: cleanNotes,
          AppSchema.saleCreatedAt: timestamp,
          AppSchema.saleCancelledAt: null,
        },
      );

      for (final SaleLineInput item in items) {
        final Map<String, Object?> product = products[item.productId]!;
        final String productName =
            (product[AppSchema.productName] as String?) ?? '';
        final String productSku =
            (product[AppSchema.productSku] as String?) ?? '';
        final double lineTotal = roundMoney(item.quantity * item.unitPrice);

        await txn.insert(AppSchema.salesItems, <String, Object?>{
          AppSchema.saleItemSaleId: saleId,
          AppSchema.saleItemProductId: item.productId,
          AppSchema.saleItemProductName: productName,
          AppSchema.saleItemProductSku: productSku,
          AppSchema.saleItemQuantity: item.quantity,
          AppSchema.saleItemUnitPrice: item.unitPrice,
          AppSchema.saleItemLineTotal: lineTotal,
        });

        final int current = (product[AppSchema.productStock] as int?) ?? 0;
        final int next = current - item.quantity;
        if (next < 0) {
          throw AppRuleException(
            'الرصيد لا يكفي لـ $productName، المتوفر $current فقط',
          );
        }
        await txn.update(
          AppSchema.products,
          <String, Object?>{
            AppSchema.productStock: next,
            AppSchema.productUpdatedAt: timestamp,
          },
          where: '${AppSchema.productId} = ?',
          whereArgs: <Object?>[item.productId],
        );
        await txn.insert(AppSchema.stockMovements, <String, Object?>{
          AppSchema.movementProductId: item.productId,
          AppSchema.movementType: MovementType.sale.id,
          AppSchema.movementChange: -item.quantity,
          AppSchema.movementStockAfter: next,
          AppSchema.movementReason: 'فاتورة $invoiceNo',
          AppSchema.movementCreatedBy: createdBy,
          AppSchema.movementCreatedAt: timestamp,
        });
      }

      return saleId;
    });

    final Sale? created = await saleById(id);
    if (created == null) {
      throw AppRuleException('تعذر إنشاء الفاتورة');
    }
    return created;
  }

  Future<Sale> cancelSale(int id, {int? byUser}) async {
    final Sale? existing = await saleById(id);
    if (existing == null) {
      throw AppRuleException('الفاتورة غير موجودة');
    }
    if (existing.isCancelled) {
      throw AppRuleException('الفاتورة ملغاة بالفعل');
    }

    final String timestamp = _timestamp();
    await _db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> items = await txn.query(
        AppSchema.salesItems,
        where: '${AppSchema.saleItemSaleId} = ?',
        whereArgs: <Object?>[id],
      );

      for (final Map<String, Object?> item in items) {
        final int productId = (item[AppSchema.saleItemProductId] as int?) ?? 0;
        final int quantity = (item[AppSchema.saleItemQuantity] as int?) ?? 0;
        final List<Map<String, Object?>> rows = await txn.query(
          AppSchema.products,
          where: '${AppSchema.productId} = ?',
          whereArgs: <Object?>[productId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw AppRuleException('المنتج غير موجود');
        }
        final int current = (rows.first[AppSchema.productStock] as int?) ?? 0;
        final int next = current + quantity;
        await txn.update(
          AppSchema.products,
          <String, Object?>{
            AppSchema.productStock: next,
            AppSchema.productUpdatedAt: timestamp,
          },
          where: '${AppSchema.productId} = ?',
          whereArgs: <Object?>[productId],
        );
        await txn.insert(AppSchema.stockMovements, <String, Object?>{
          AppSchema.movementProductId: productId,
          AppSchema.movementType: MovementType.adjustment.id,
          AppSchema.movementChange: quantity,
          AppSchema.movementStockAfter: next,
          AppSchema.movementReason: 'إلغاء فاتورة ${existing.invoiceNo}',
          AppSchema.movementCreatedBy: byUser,
          AppSchema.movementCreatedAt: timestamp,
        });
      }

      final int updated = await txn.update(
        AppSchema.salesInvoices,
        <String, Object?>{
          AppSchema.saleStatus: SaleStatus.cancelled.id,
          AppSchema.saleCancelledAt: timestamp,
        },
        where: '${AppSchema.saleId} = ? AND ${AppSchema.saleStatus} != ?',
        whereArgs: <Object?>[id, SaleStatus.cancelled.id],
      );
      if (updated == 0) {
        throw AppRuleException('الفاتورة ملغاة بالفعل');
      }
    });

    final Sale? cancelled = await saleById(id);
    if (cancelled == null) {
      throw AppRuleException('تعذر إلغاء الفاتورة');
    }
    return cancelled;
  }

  Future<void> _ensureUniqueValue(
    String table,
    String column,
    String value,
    String message, {
    int? excludeId,
  }) async {
    String where = '$column = ? COLLATE NOCASE';
    final List<Object?> args = <Object?>[value];
    if (excludeId != null) {
      where = '$where AND ${AppSchema.productId} != ?';
      args.add(excludeId);
    }

    final List<Map<String, Object?>> rows = await _db.query(
      table,
      columns: <String>[AppSchema.productId],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw AppRuleException(message);
    }
  }

  static int _clampPageSize(int pageSize) {
    if (pageSize < 1) {
      return 10;
    }
    if (pageSize > 100) {
      return 100;
    }
    return pageSize;
  }

  static String _productSortColumn(ProductSort sort) {
    switch (sort) {
      case ProductSort.name:
        return 'p.${AppSchema.productName} COLLATE NOCASE';
      case ProductSort.sku:
        return 'p.${AppSchema.productSku}';
      case ProductSort.stock:
        return 'p.${AppSchema.productStock}';
      case ProductSort.salePrice:
        return 'p.${AppSchema.productSalePrice}';
      case ProductSort.updatedAt:
        return 'p.${AppSchema.productUpdatedAt}';
    }
  }

  static String _requireLabel(String value, String field) {
    final String clean = value.trim();
    if (clean.isEmpty) {
      throw AppRuleException('$field مطلوب');
    }
    if (clean.length > 80) {
      throw AppRuleException('$field طويل جداً');
    }
    return clean;
  }

  static String _requireSku(String value) {
    final String clean = value.trim().toUpperCase();
    if (clean.isEmpty) {
      throw AppRuleException('كود المنتج مطلوب');
    }
    if (clean.length > 30) {
      throw AppRuleException('كود المنتج طويل جداً');
    }
    if (clean.contains(' ')) {
      throw AppRuleException('كود المنتج لا يجوز أن يحتوي على مسافات');
    }
    return clean;
  }

  static void _validatePrice(double value, String field) {
    if (!value.isFinite || value < 0) {
      throw AppRuleException('$field لا يمكن أن يكون أقل من صفر');
    }
  }

  static void _validateCount(int value, String field) {
    if (value < 0) {
      throw AppRuleException('$field لا يمكن أن يكون أقل من صفر');
    }
  }

  static String? _cleanOptional(String? value) {
    final String clean = value?.trim() ?? '';
    if (clean.isEmpty) {
      return null;
    }
    if (clean.length > 200) {
      throw AppRuleException('النص طويل جداً');
    }
    return clean;
  }

  static String? _validatePhone(String? value) {
    final String clean = value?.trim() ?? '';
    if (clean.isEmpty) {
      return null;
    }
    if (clean.length > 20) {
      throw AppRuleException('رقم الهاتف طويل جداً');
    }
    final RegExp valid = RegExp(r'^[0-9+\-() ]+$');
    if (!valid.hasMatch(clean)) {
      throw AppRuleException('رقم الهاتف غير صالح');
    }
    return clean;
  }

  static String _cleanEmail(String email) {
    final String cleanEmail = email.trim().toLowerCase();
    final bool valid =
        cleanEmail.contains('@') &&
        cleanEmail.contains('.') &&
        cleanEmail.length >= 6 &&
        !cleanEmail.contains(' ');
    if (!valid) {
      throw AppRuleException('البريد الإلكتروني غير صالح');
    }
    return cleanEmail;
  }

  static void _validateFullName(String fullName) {
    if (fullName.trim().isEmpty) {
      throw AppRuleException('اسم المستخدم مطلوب');
    }
  }

  static void _validatePassword(String password) {
    if (password.length < 6) {
      throw AppRuleException('كلمة المرور يجب ألا تقل عن 6 أحرف');
    }
  }

  static String _timestamp() => DateTime.now().toUtc().toIso8601String();


static const String _supplierSelect =
      'SELECT su.*, (SELECT COUNT(*) FROM ${AppSchema.purchases} p '
      'WHERE p.${AppSchema.purchaseSupplierId} = su.${AppSchema.supplierId}) AS purchase_count '
      'FROM ${AppSchema.suppliers} su ';

  static const String _purchaseSelect =
      'SELECT p.*, su.${AppSchema.supplierName} AS supplier_name, '
      'u.${AppSchema.userFullName} AS user_name '
      'FROM ${AppSchema.purchases} p '
      'LEFT JOIN ${AppSchema.suppliers} su ON su.${AppSchema.supplierId} = p.${AppSchema.purchaseSupplierId} '
      'LEFT JOIN ${AppSchema.users} u ON u.${AppSchema.userId} = p.${AppSchema.purchaseUserId} ';

  Future<List<Supplier>> listSuppliers() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_supplierSelect ORDER BY ${AppSchema.supplierName} COLLATE NOCASE ASC',
    );
    return rows.map(Supplier.fromRow).toList();
  }

  Future<Supplier?> supplierById(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_supplierSelect WHERE su.${AppSchema.supplierId} = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return Supplier.fromRow(rows.first);
  }

  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? note,
    bool isActive = true,
  }) async {
    final String cleanName = _requireLabel(name, 'اسم المورد');
    final String? cleanPhone = _validatePhone(phone);
    final String? cleanNote = _cleanOptional(note);

    final String timestamp = _timestamp();
    final int id = await _db.insert(AppSchema.suppliers, <String, Object?>{
      AppSchema.supplierName: cleanName,
      AppSchema.supplierPhone: cleanPhone,
      AppSchema.supplierNote: cleanNote,
      AppSchema.supplierIsActive: isActive ? 1 : 0,
      AppSchema.supplierCreatedAt: timestamp,
      AppSchema.supplierUpdatedAt: timestamp,
    });

    final Supplier? created = await supplierById(id);
    if (created == null) {
      throw AppRuleException('تعذر إنشاء المورد');
    }
    return created;
  }

  Future<Supplier> updateSupplier(
    int id, {
    String? name,
    String? phone,
    String? note,
    bool? isActive,
  }) async {
    final Supplier? current = await supplierById(id);
    if (current == null) {
      throw AppRuleException('المورد غير موجود');
    }
    final Map<String, Object?> values = <String, Object?>{};

    if (name != null) {
      values[AppSchema.supplierName] = _requireLabel(name, 'اسم المورد');
    }
    if (phone != null) {
      values[AppSchema.supplierPhone] = _validatePhone(phone);
    }
    if (note != null) {
      values[AppSchema.supplierNote] = _cleanOptional(note);
    }
    if (isActive != null) {
      values[AppSchema.supplierIsActive] = isActive ? 1 : 0;
    }

    if (values.isNotEmpty) {
      values[AppSchema.supplierUpdatedAt] = _timestamp();
      await _db.update(
        AppSchema.suppliers,
        values,
        where: '${AppSchema.supplierId} = ?',
        whereArgs: <Object?>[id],
      );
    }

    final Supplier? updated = await supplierById(id);
    if (updated == null) {
      throw AppRuleException('تعذر تحديث المورد');
    }
    return updated;
  }

  Future<void> deleteSupplier(int id) async {
    final Supplier? current = await supplierById(id);
    if (current == null) {
      throw AppRuleException('المورد غير موجود');
    }
    final List<Map<String, Object?>> rows = await _db.query(
      AppSchema.purchases,
      columns: <String>[AppSchema.purchaseId],
      where: '${AppSchema.purchaseSupplierId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw AppRuleException('لا يمكن حذف مورد له أوامر شراء');
    }
    await _db.delete(
      AppSchema.suppliers,
      where: '${AppSchema.supplierId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<PagedResult<Purchase>> listPurchases({
    String search = '',
    PurchaseStatus? status,
    int page = 1,
    int pageSize = 10,
  }) async {
    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];

    final String cleanSearch = search.trim();
    if (cleanSearch.isNotEmpty) {
      clauses.add(
        '(p.${AppSchema.purchaseOrderNo} LIKE ? COLLATE NOCASE '
        'OR su.${AppSchema.supplierName} LIKE ? COLLATE NOCASE)',
      );
      args.add('%$cleanSearch%');
      args.add('%$cleanSearch%');
    }

    if (status != null) {
      clauses.add('p.${AppSchema.purchaseStatus} = ?');
      args.add(status.id);
    }

    final String where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';

    final List<Map<String, Object?>> countRows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${AppSchema.purchases} p '
      'LEFT JOIN ${AppSchema.suppliers} su '
      'ON su.${AppSchema.supplierId} = p.${AppSchema.purchaseSupplierId} $where',
      args,
    );
    final int total = (countRows.first['total'] as int?) ?? 0;

    final int size = _clampPageSize(pageSize);
    final int pageCount = total == 0 ? 1 : (total + size - 1) ~/ size;
    final int currentPage = page.clamp(1, pageCount).toInt();
    final int offset = (currentPage - 1) * size;

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_purchaseSelect$where '
      'ORDER BY p.${AppSchema.purchaseDate} DESC, p.${AppSchema.purchaseId} DESC '
      'LIMIT ? OFFSET ?',
      <Object?>[...args, size, offset],
    );

    return PagedResult<Purchase>(
      items: rows.map(Purchase.fromRow).toList(),
      total: total,
      page: currentPage,
      pageSize: size,
    );
  }

  Future<Purchase?> purchaseById(int id) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '$_purchaseSelect WHERE p.${AppSchema.purchaseId} = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }

    final List<Map<String, Object?>> itemRows = await _db.rawQuery(
      'SELECT * FROM ${AppSchema.purchaseItems} '
      'WHERE ${AppSchema.purchaseItemPurchaseId} = ? '
      'ORDER BY ${AppSchema.purchaseItemId} ASC',
      <Object?>[id],
    );
    return Purchase.fromRow(rows.first)
        .withItems(itemRows.map(PurchaseLine.fromRow).toList());
  }

  Future<Purchase> createPurchase({
    int? supplierId,
    required List<PurchaseLineInput> items,
    double discount = 0,
    String? notes,
    int? createdBy,
  }) async {
    if (items.isEmpty) {
      throw AppRuleException('يجب إضافة منتج واحد على الأقل');
    }
    if (discount < 0) {
      throw AppRuleException('الخصم لا يمكن أن يكون أقل من صفر');
    }
    final String? cleanNotes = _cleanOptional(notes);
    if (supplierId != null) {
      final Supplier? supplier = await supplierById(supplierId);
      if (supplier == null) {
        throw AppRuleException('المورد غير موجود');
      }
    }

    final Set<int> seen = <int>{};
    for (final PurchaseLineInput item in items) {
      if (item.productId <= 0) {
        throw AppRuleException('منتج غير صالح في أمر الشراء');
      }
      if (!seen.add(item.productId)) {
        throw AppRuleException('لا يمكن تكرار المنتج نفسه في أمر الشراء');
      }
      _validateCount(item.quantity, 'الكمية');
      _validatePrice(item.unitPrice, 'سعر التكلفة');
      if (item.quantity <= 0) {
        throw AppRuleException('الكمية يجب أن تكون أكبر من صفر');
      }
    }

    final String timestamp = _timestamp();
    final int id = await _db.transaction((Transaction txn) async {
      final Map<int, Map<String, Object?>> products =
          <int, Map<String, Object?>>{};
      double subtotal = 0;
      for (final PurchaseLineInput item in items) {
        final List<Map<String, Object?>> rows = await txn.query(
          AppSchema.products,
          where: '${AppSchema.productId} = ?',
          whereArgs: <Object?>[item.productId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw AppRuleException('المنتج غير موجود');
        }
        final Map<String, Object?> product = rows.first;
        if (((product[AppSchema.productIsActive] as int?) ?? 0) != 1) {
          throw AppRuleException(
            'المنتج «${product[AppSchema.productName]}» غير مفعل',
          );
        }
        products[item.productId] = product;
        subtotal += roundMoney(item.quantity * item.unitPrice);
      }

      subtotal = roundMoney(subtotal);
      final double cleanDiscount = roundMoney(discount);
      if (cleanDiscount > subtotal) {
        throw AppRuleException('الخصم أكبر من مجموع أمر الشراء');
      }
      final double total = roundMoney(subtotal - cleanDiscount);

      final List<Map<String, Object?>> sequenceRows = await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM ${AppSchema.purchases}',
      );
      final int sequence = (sequenceRows.first['c'] as int?) ?? 0;
      final String orderNo =
          'PUR-${(sequence + 1).toString().padLeft(6, '0')}';

      final int purchaseId = await txn.insert(
        AppSchema.purchases,
        <String, Object?>{
          AppSchema.purchaseOrderNo: orderNo,
          AppSchema.purchaseSupplierId: supplierId,
          AppSchema.purchaseUserId: createdBy,
          AppSchema.purchaseDate: timestamp,
          AppSchema.purchaseSubtotal: subtotal,
          AppSchema.purchaseDiscount: cleanDiscount,
          AppSchema.purchaseTotal: total,
          AppSchema.purchaseStatus: PurchaseStatus.completed.id,
          AppSchema.purchaseNotes: cleanNotes,
          AppSchema.purchaseCreatedAt: timestamp,
          AppSchema.purchaseCancelledAt: null,
        },
      );

      for (final PurchaseLineInput item in items) {
        final Map<String, Object?> product = products[item.productId]!;
        final String productName =
            (product[AppSchema.productName] as String?) ?? '';
        final String productSku =
            (product[AppSchema.productSku] as String?) ?? '';
        final double lineTotal = roundMoney(item.quantity * item.unitPrice);

        await txn.insert(AppSchema.purchaseItems, <String, Object?>{
          AppSchema.purchaseItemPurchaseId: purchaseId,
          AppSchema.purchaseItemProductId: item.productId,
          AppSchema.purchaseItemProductName: productName,
          AppSchema.purchaseItemProductSku: productSku,
          AppSchema.purchaseItemQuantity: item.quantity,
          AppSchema.purchaseItemUnitPrice: item.unitPrice,
          AppSchema.purchaseItemLineTotal: lineTotal,
        });

        final int current = (product[AppSchema.productStock] as int?) ?? 0;
        final int next = current + item.quantity;
        await txn.update(
          AppSchema.products,
          <String, Object?>{
            AppSchema.productStock: next,
            AppSchema.productUpdatedAt: timestamp,
          },
          where: '${AppSchema.productId} = ?',
          whereArgs: <Object?>[item.productId],
        );
        await txn.insert(AppSchema.stockMovements, <String, Object?>{
          AppSchema.movementProductId: item.productId,
          AppSchema.movementType: MovementType.purchase.id,
          AppSchema.movementChange: item.quantity,
          AppSchema.movementStockAfter: next,
          AppSchema.movementReason: ' أمر شراء $orderNo',
          AppSchema.movementCreatedBy: createdBy,
          AppSchema.movementCreatedAt: timestamp,
        });
      }

      return purchaseId;
    });

    final Purchase? created = await purchaseById(id);
    if (created == null) {
      throw AppRuleException('تعذر إنشاء أمر الشراء');
    }
    return created;
  }

  Future<Purchase> cancelPurchase(int id, {int? byUser}) async {
    final Purchase? existing = await purchaseById(id);
    if (existing == null) {
      throw AppRuleException(' أمر الشراء غير موجود');
    }
    if (existing.isCancelled) {
      throw AppRuleException(' أمر الشراء ملغى بالفعل');
    }

    final String timestamp = _timestamp();
    await _db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> items = await txn.query(
        AppSchema.purchaseItems,
        where: '${AppSchema.purchaseItemPurchaseId} = ?',
        whereArgs: <Object?>[id],
      );

      for (final Map<String, Object?> item in items) {
        final int productId =
            (item[AppSchema.purchaseItemProductId] as int?) ?? 0;
        final int quantity =
            (item[AppSchema.purchaseItemQuantity] as int?) ?? 0;
        final List<Map<String, Object?>> rows = await txn.query(
          AppSchema.products,
          where: '${AppSchema.productId} = ?',
          whereArgs: <Object?>[productId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw AppRuleException('المنتج غير موجود');
        }
        final int current = (rows.first[AppSchema.productStock] as int?) ?? 0;
        final int next = current - quantity;
        await txn.update(
          AppSchema.products,
          <String, Object?>{
            AppSchema.productStock: next,
            AppSchema.productUpdatedAt: timestamp,
          },
          where: '${AppSchema.productId} = ?',
          whereArgs: <Object?>[productId],
        );
        await txn.insert(AppSchema.stockMovements, <String, Object?>{
          AppSchema.movementProductId: productId,
          AppSchema.movementType: MovementType.adjustment.id,
          AppSchema.movementChange: -quantity,
          AppSchema.movementStockAfter: next,
          AppSchema.movementReason: 'إلغاء أمر شراء ${existing.orderNo}',
          AppSchema.movementCreatedBy: byUser,
          AppSchema.movementCreatedAt: timestamp,
        });
      }

      final int updated = await txn.update(
        AppSchema.purchases,
        <String, Object?>{
          AppSchema.purchaseStatus: PurchaseStatus.cancelled.id,
          AppSchema.purchaseCancelledAt: timestamp,
        },
        where: '${AppSchema.purchaseId} = ? AND ${AppSchema.purchaseStatus} != ?',
        whereArgs: <Object?>[id, PurchaseStatus.cancelled.id],
      );
      if (updated == 0) {
        throw AppRuleException(' أمر الشراء ملغى بالفعل');
      }
    });

    final Purchase? cancelled = await purchaseById(id);
    if (cancelled == null) {
      throw AppRuleException('تعذر إلغاء أمر الشراء');
    }
    return cancelled;
  }

}
