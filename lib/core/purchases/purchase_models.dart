import '../database/app_schema.dart';

enum PurchaseStatus {
  completed('completed', 'مكتملة'),
  cancelled('cancelled', 'ملغاة');

  const PurchaseStatus(this.id, this.label);

  final String id;
  final String label;

  static PurchaseStatus parse(String? raw) {
    for (final PurchaseStatus status in PurchaseStatus.values) {
      if (status.id == raw) {
        return status;
      }
    }
    return PurchaseStatus.completed;
  }
}

class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.note,
  });

  factory Supplier.fromRow(Map<String, Object?> row) {
    return Supplier(
      id: (row[AppSchema.supplierId] as int?) ?? 0,
      name: (row[AppSchema.supplierName] as String?) ?? '',
      phone: row[AppSchema.supplierPhone] as String?,
      note: row[AppSchema.supplierNote] as String?,
      isActive: ((row[AppSchema.supplierIsActive] as int?) ?? 0) == 1,
      createdAt: (row[AppSchema.supplierCreatedAt] as String?) ?? '',
      updatedAt: (row[AppSchema.supplierUpdatedAt] as String?) ?? '',
    );
  }

  final int id;
  final String name;
  final String? phone;
  final String? note;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
}

class PurchaseLine {
  const PurchaseLine({
    required this.productId,
    required this.productSku,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory PurchaseLine.fromRow(Map<String, Object?> row) {
    return PurchaseLine(
      productId: (row[AppSchema.purchaseItemProductId] as int?) ?? 0,
      productSku: (row[AppSchema.purchaseItemProductSku] as String?) ?? '',
      productName: (row[AppSchema.purchaseItemProductName] as String?) ?? '',
      quantity: (row[AppSchema.purchaseItemQuantity] as int?) ?? 0,
      unitPrice: ((row[AppSchema.purchaseItemUnitPrice] as num?) ?? 0)
          .toDouble(),
      lineTotal: ((row[AppSchema.purchaseItemLineTotal] as num?) ?? 0)
          .toDouble(),
    );
  }

  final int productId;
  final String productSku;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}

class Purchase {
  const Purchase({
    required this.id,
    required this.orderNo,
    required this.purchaseDate,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.status,
    required this.createdAt,
    this.supplierId,
    this.supplierName,
    this.userId,
    this.userName,
    this.notes,
    this.cancelledAt,
    this.items = const <PurchaseLine>[],
  });

  factory Purchase.fromRow(Map<String, Object?> row) {
    return Purchase(
      id: (row[AppSchema.purchaseId] as int?) ?? 0,
      orderNo: (row[AppSchema.purchaseOrderNo] as String?) ?? '',
      supplierId: row[AppSchema.purchaseSupplierId] as int?,
      supplierName: row['supplier_name'] as String?,
      userId: row[AppSchema.purchaseUserId] as int?,
      userName: row['user_name'] as String?,
      purchaseDate: (row[AppSchema.purchaseDate] as String?) ?? '',
      subtotal: ((row[AppSchema.purchaseSubtotal] as num?) ?? 0).toDouble(),
      discount: ((row[AppSchema.purchaseDiscount] as num?) ?? 0).toDouble(),
      total: ((row[AppSchema.purchaseTotal] as num?) ?? 0).toDouble(),
      status: PurchaseStatus.parse(row[AppSchema.purchaseStatus] as String?),
      notes: row[AppSchema.purchaseNotes] as String?,
      createdAt: (row[AppSchema.purchaseCreatedAt] as String?) ?? '',
      cancelledAt: row[AppSchema.purchaseCancelledAt] as String?,
    );
  }

  Purchase withItems(List<PurchaseLine> lines) {
    return Purchase(
      id: id,
      orderNo: orderNo,
      supplierId: supplierId,
      supplierName: supplierName,
      userId: userId,
      userName: userName,
      purchaseDate: purchaseDate,
      subtotal: subtotal,
      discount: discount,
      total: total,
      status: status,
      notes: notes,
      createdAt: createdAt,
      cancelledAt: cancelledAt,
      items: lines,
    );
  }

  final int id;
  final String orderNo;
  final int? supplierId;
  final String? supplierName;
  final int? userId;
  final String? userName;
  final String purchaseDate;
  final double subtotal;
  final double discount;
  final double total;
  final PurchaseStatus status;
  final String? notes;
  final String createdAt;
  final String? cancelledAt;
  final List<PurchaseLine> items;

  bool get isCancelled => status == PurchaseStatus.cancelled;
}

class PurchaseLineInput {
  const PurchaseLineInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  final int productId;
  final int quantity;
  final double unitPrice;
}
