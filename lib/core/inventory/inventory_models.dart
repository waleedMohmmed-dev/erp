import 'dart:math';

import '../database/app_schema.dart';

enum StockStatus { out, low, ok }

enum StockFilter {
  all('الكل'),
  out('نفد المخزون'),
  low('مخزون منخفض'),
  ok('متوفر');

  const StockFilter(this.label);

  final String label;
}

enum ProductSort { name, sku, stock, salePrice, updatedAt }

enum MovementType {
  initial('initial', 'رصيد افتتاحي'),
  adjustment('adjustment', 'تسوية جرد'),
  purchase('purchase', 'وارد شراء'),
  sale('sale', 'صادر بيع');

  const MovementType(this.id, this.label);

  final String id;
  final String label;

  static MovementType? parse(String? raw) {
    for (final MovementType type in MovementType.values) {
      if (type.id == raw) {
        return type;
      }
    }
    return null;
  }
}

class InventoryCategory {
  const InventoryCategory({
    required this.id,
    required this.name,
    this.description,
    this.productCount = 0,
  });

  factory InventoryCategory.fromRow(Map<String, Object?> row) {
    return InventoryCategory(
      id: (row[AppSchema.categoryId] as int?) ?? 0,
      name: (row[AppSchema.categoryName] as String?) ?? '',
      description: row[AppSchema.categoryDescription] as String?,
      productCount: (row['product_count'] as int?) ?? 0,
    );
  }

  final int id;
  final String name;
  final String? description;
  final int productCount;
}

class InventoryUnit {
  const InventoryUnit({
    required this.id,
    required this.name,
    this.productCount = 0,
  });

  factory InventoryUnit.fromRow(Map<String, Object?> row) {
    return InventoryUnit(
      id: (row[AppSchema.unitId] as int?) ?? 0,
      name: (row[AppSchema.unitName] as String?) ?? '',
      productCount: (row['product_count'] as int?) ?? 0,
    );
  }

  final int id;
  final String name;
  final int productCount;
}

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.unitId,
    required this.costPrice,
    required this.salePrice,
    required this.stock,
    required this.minStock,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.categoryName,
    this.unitName,
  });

  factory Product.fromRow(Map<String, Object?> row) {
    return Product(
      id: (row[AppSchema.productId] as int?) ?? 0,
      sku: (row[AppSchema.productSku] as String?) ?? '',
      name: (row[AppSchema.productName] as String?) ?? '',
      categoryId: row[AppSchema.productCategoryId] as int?,
      categoryName: row['category_name'] as String?,
      unitId: (row[AppSchema.productUnitId] as int?) ?? 0,
      unitName: row['unit_name'] as String?,
      costPrice: ((row[AppSchema.productCostPrice] as num?) ?? 0).toDouble(),
      salePrice: ((row[AppSchema.productSalePrice] as num?) ?? 0).toDouble(),
      stock: (row[AppSchema.productStock] as int?) ?? 0,
      minStock: (row[AppSchema.productMinStock] as int?) ?? 0,
      isActive: ((row[AppSchema.productIsActive] as int?) ?? 0) == 1,
      createdAt: (row[AppSchema.productCreatedAt] as String?) ?? '',
      updatedAt: (row[AppSchema.productUpdatedAt] as String?) ?? '',
    );
  }

  final int id;
  final String sku;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final int unitId;
  final String? unitName;
  final double costPrice;
  final double salePrice;
  final int stock;
  final int minStock;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  StockStatus get status {
    if (stock <= 0) {
      return StockStatus.out;
    }
    if (stock <= minStock) {
      return StockStatus.low;
    }
    return StockStatus.ok;
  }
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantityChange,
    required this.stockAfter,
    required this.reason,
    required this.createdAt,
    this.productName,
    this.productSku,
    this.createdBy,
    this.createdByName,
  });

  factory StockMovement.fromRow(Map<String, Object?> row) {
    return StockMovement(
      id: (row[AppSchema.movementId] as int?) ?? 0,
      productId: (row[AppSchema.movementProductId] as int?) ?? 0,
      productName: row['product_name'] as String?,
      productSku: row['product_sku'] as String?,
      type:
          MovementType.parse(row[AppSchema.movementType] as String?) ??
          MovementType.adjustment,
      quantityChange: (row[AppSchema.movementChange] as int?) ?? 0,
      stockAfter: (row[AppSchema.movementStockAfter] as int?) ?? 0,
      reason: (row[AppSchema.movementReason] as String?) ?? '',
      createdBy: row[AppSchema.movementCreatedBy] as int?,
      createdByName: row['created_by_name'] as String?,
      createdAt: (row[AppSchema.movementCreatedAt] as String?) ?? '',
    );
  }

  final int id;
  final int productId;
  final String? productName;
  final String? productSku;
  final MovementType type;
  final int quantityChange;
  final int stockAfter;
  final String reason;
  final int? createdBy;
  final String? createdByName;
  final String createdAt;
}

class ProductQuery {
  const ProductQuery({
    this.search = '',
    this.categoryId,
    this.stockFilter = StockFilter.all,
    this.sort = ProductSort.name,
    this.ascending = true,
    this.page = 1,
    this.pageSize = 10,
  });

  final String search;
  final int? categoryId;
  final StockFilter stockFilter;
  final ProductSort sort;
  final bool ascending;
  final int page;
  final int pageSize;

  ProductQuery copyWith({
    String? search,
    int? categoryId,
    bool clearCategory = false,
    StockFilter? stockFilter,
    ProductSort? sort,
    bool? ascending,
    int? page,
    int? pageSize,
  }) {
    return ProductQuery(
      search: search ?? this.search,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      stockFilter: stockFilter ?? this.stockFilter,
      sort: sort ?? this.sort,
      ascending: ascending ?? this.ascending,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  int get pageCount {
    if (total == 0 || pageSize <= 0) {
      return 1;
    }
    return max(1, (total + pageSize - 1) ~/ pageSize);
  }

  int get from => total == 0 ? 0 : (page - 1) * pageSize + 1;

  int get to => min(total, page * pageSize);
}
