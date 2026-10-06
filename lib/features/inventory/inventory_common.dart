import 'package:flutter/material.dart';

import '../../core/inventory/inventory_models.dart';
import '../../core/theme/app_theme.dart';

void showAppMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

String formatDateTime(String raw) {
  final DateTime? parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) {
    return raw;
  }
  String two(int value) => value.toString().padLeft(2, '0');
  return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

Color stockStatusColor(StockStatus status) {
  switch (status) {
    case StockStatus.out:
      return AppColors.danger;
    case StockStatus.low:
      return AppColors.warning;
    case StockStatus.ok:
      return AppColors.success;
  }
}

class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.status});

  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = stockStatusColor(status);
    final String label = switch (status) {
      StockStatus.out => 'نفد',
      StockStatus.low => 'منخفض',
      StockStatus.ok => 'متوفر',
    };
    final IconData icon = switch (status) {
      StockStatus.out => Icons.remove_shopping_cart_outlined,
      StockStatus.low => Icons.warning_amber_outlined,
      StockStatus.ok => Icons.check_circle_outline,
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
            label,
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

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.from,
    required this.to,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.pageSize,
    required this.onPageSizeChanged,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
    this.suffix = 'عنصر',
  });

  final int from;
  final int to;
  final int total;
  final int page;
  final int pageCount;
  final int pageSize;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasPrevious = page > 1;
    final bool hasNext = page < pageCount;

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          'عرض $from–$to من $total $suffix',
          style: theme.textTheme.bodySmall,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('عدد الصفحات', style: theme.textTheme.bodySmall),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: pageSize,
                isDense: true,
                items: const <int>[10, 25, 50]
                    .map<DropdownMenuItem<int>>(
                      (int size) => DropdownMenuItem<int>(
                        value: size,
                        child: Text(size.toString()),
                      ),
                    )
                    .toList(),
                onChanged: (int? value) {
                  if (value != null && value != pageSize) {
                    onPageSizeChanged(value);
                  }
                },
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              onPressed: hasPrevious ? onFirst : null,
              child: const Text('الأولى'),
            ),
            TextButton(
              onPressed: hasPrevious ? onPrevious : null,
              child: const Text('السابقة'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'صفحة $page من $pageCount',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: hasNext ? onNext : null,
              child: const Text('التالية'),
            ),
            TextButton(
              onPressed: hasNext ? onLast : null,
              child: const Text('الأخيرة'),
            ),
          ],
        ),
      ],
    );
  }
}
