import 'package:flutter/material.dart';

import '../../core/purchases/purchase_models.dart';
import '../../core/theme/app_theme.dart';

export '../sales/sales_common.dart'
    show PaginationBar, formatDateTime, formatMoney, showAppMessage;

class PurchaseStatusFilter {
  const PurchaseStatusFilter({this.status, required this.label});
  final PurchaseStatus? status;
  final String label;

  static const List<PurchaseStatusFilter> values = <PurchaseStatusFilter>[
    PurchaseStatusFilter(status: null, label: 'الكل'),
    PurchaseStatusFilter(status: PurchaseStatus.completed, label: 'مكتملة'),
    PurchaseStatusFilter(status: PurchaseStatus.cancelled, label: 'ملغاة'),
  ];
}

class PurchaseQuery {
  const PurchaseQuery({
    this.search = '',
    this.status,
    this.page = 1,
    this.pageSize = 10,
  });

  final String search;
  final PurchaseStatus? status;
  final int page;
  final int pageSize;

  PurchaseQuery copyWith({
    String? search,
    PurchaseStatus? status,
    bool clearStatus = false,
    int? page,
    int? pageSize,
  }) {
    return PurchaseQuery(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

class PurchaseStatusBadge extends StatelessWidget {
  const PurchaseStatusBadge({super.key, required this.status});
  final PurchaseStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = status == PurchaseStatus.completed
        ? AppColors.success
        : AppColors.danger;
    final IconData icon = status == PurchaseStatus.completed
        ? Icons.check_circle_outline
        : Icons.cancel_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

typedef PurchaseDraftLine = ({
  int productId,
  String productSku,
  String productName,
  int quantity,
  double unitPrice,
});

typedef PurchaseLineInput = ({int productId, int quantity, double unitPrice});
