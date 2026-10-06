import 'package:flutter/material.dart';

import '../../core/sales/sales_models.dart';
import '../../core/theme/app_theme.dart';

export '../inventory/inventory_common.dart'
    show PaginationBar, formatDateTime, showAppMessage;

String formatMoney(double value) => value.toStringAsFixed(2);

Color saleStatusColor(SaleStatus status) {
  switch (status) {
    case SaleStatus.completed:
      return AppColors.success;
    case SaleStatus.cancelled:
      return AppColors.danger;
  }
}

class SaleStatusBadge extends StatelessWidget {
  const SaleStatusBadge({super.key, required this.status});

  final SaleStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = saleStatusColor(status);
    final IconData icon = switch (status) {
      SaleStatus.completed => Icons.check_circle_outline,
      SaleStatus.cancelled => Icons.cancel_outlined,
    };

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
