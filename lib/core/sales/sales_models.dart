import '../database/app_schema.dart';

enum SaleStatus {
  completed('completed', 'مكتملة'),
  cancelled('cancelled', 'ملغاة');

  const SaleStatus(this.id, this.label);

  final String id;
  final String label;

  static SaleStatus parse(String? raw) {
    for (final SaleStatus status in SaleStatus.values) {
      if (status.id == raw) {
        return status;
      }
    }
    return SaleStatus.completed;
  }
}

enum SaleStatusFilter {
  all('الكل'),
  completed('مكتملة'),
  cancelled('ملغاة');

  const SaleStatusFilter(this.label);

  final String label;

  SaleStatus? get status {
    switch (this) {
      case SaleStatusFilter.all:
        return null;
      case SaleStatusFilter.completed:
        return SaleStatus.completed;
      case SaleStatusFilter.cancelled:
        return SaleStatus.cancelled;
    }
  }
}

double roundMoney(double value) => (value * 100).roundToDouble() / 100;

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.note,
    this.saleCount = 0,
  });

  factory Customer.fromRow(Map<String, Object?> row) {
    return Customer(
      id: (row[AppSchema.customerId] as int?) ?? 0,
      name: (row[AppSchema.customerName] as String?) ?? '',
      phone: row[AppSchema.customerPhone] as String?,
      note: row[AppSchema.customerNote] as String?,
      isActive: ((row[AppSchema.customerIsActive] as int?) ?? 0) == 1,
      saleCount: (row['sale_count'] as int?) ?? 0,
      createdAt: (row[AppSchema.customerCreatedAt] as String?) ?? '',
      updatedAt: (row[AppSchema.customerUpdatedAt] as String?) ?? '',
    );
  }

  final int id;
  final String name;
  final String? phone;
  final String? note;
  final bool isActive;
  final int saleCount;
  final String createdAt;
  final String updatedAt;
}

class SaleLine {
  const SaleLine({
    required this.productId,
    required this.productSku,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory SaleLine.fromRow(Map<String, Object?> row) {
    return SaleLine(
      productId: (row[AppSchema.saleItemProductId] as int?) ?? 0,
      productSku: (row[AppSchema.saleItemProductSku] as String?) ?? '',
      productName: (row[AppSchema.saleItemProductName] as String?) ?? '',
      quantity: (row[AppSchema.saleItemQuantity] as int?) ?? 0,
      unitPrice: ((row[AppSchema.saleItemUnitPrice] as num?) ?? 0).toDouble(),
      lineTotal: ((row[AppSchema.saleItemLineTotal] as num?) ?? 0).toDouble(),
    );
  }

  final int productId;
  final String productSku;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}

class Sale {
  const Sale({
    required this.id,
    required this.invoiceNo,
    required this.saleDate,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.status,
    required this.createdAt,
    this.customerId,
    this.customerName,
    this.userId,
    this.userName,
    this.notes,
    this.cancelledAt,
    this.items = const <SaleLine>[],
  });

  factory Sale.fromRow(Map<String, Object?> row) {
    return Sale(
      id: (row[AppSchema.saleId] as int?) ?? 0,
      invoiceNo: (row[AppSchema.saleInvoiceNo] as String?) ?? '',
      customerId: row[AppSchema.saleCustomerId] as int?,
      customerName: row['customer_name'] as String?,
      userId: row[AppSchema.saleUserId] as int?,
      userName: row['user_name'] as String?,
      saleDate: (row[AppSchema.saleDate] as String?) ?? '',
      subtotal: ((row[AppSchema.saleSubtotal] as num?) ?? 0).toDouble(),
      discount: ((row[AppSchema.saleDiscount] as num?) ?? 0).toDouble(),
      total: ((row[AppSchema.saleTotal] as num?) ?? 0).toDouble(),
      status: SaleStatus.parse(row[AppSchema.saleStatus] as String?),
      notes: row[AppSchema.saleNotes] as String?,
      createdAt: (row[AppSchema.saleCreatedAt] as String?) ?? '',
      cancelledAt: row[AppSchema.saleCancelledAt] as String?,
    );
  }

  Sale withItems(List<SaleLine> lines) {
    return Sale(
      id: id,
      invoiceNo: invoiceNo,
      customerId: customerId,
      customerName: customerName,
      userId: userId,
      userName: userName,
      saleDate: saleDate,
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
  final String invoiceNo;
  final int? customerId;
  final String? customerName;
  final int? userId;
  final String? userName;
  final String saleDate;
  final double subtotal;
  final double discount;
  final double total;
  final SaleStatus status;
  final String? notes;
  final String createdAt;
  final String? cancelledAt;
  final List<SaleLine> items;

  String get customerDisplay {
    final String? name = customerName;
    if (name == null || name.trim().isEmpty) {
      return 'عميل نقدي';
    }
    return name;
  }

  bool get isCancelled => status == SaleStatus.cancelled;
}

class SaleQuery {
  const SaleQuery({
    this.search = '',
    this.status,
    this.page = 1,
    this.pageSize = 10,
  });

  final String search;
  final SaleStatus? status;
  final int page;
  final int pageSize;

  SaleQuery copyWith({
    String? search,
    SaleStatus? status,
    bool clearStatus = false,
    int? page,
    int? pageSize,
  }) {
    return SaleQuery(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

typedef SaleDraftLine = ({
  int productId,
  String productSku,
  String productName,
  int quantity,
  double unitPrice,
});

typedef SaleLineInput = ({int productId, int quantity, double unitPrice});
