import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/inventory/inventory_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/section_card.dart';
import 'inventory_common.dart';

class MovementsTab extends StatefulWidget {
  const MovementsTab({super.key});

  @override
  State<MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<MovementsTab> {
  String _search = '';
  MovementType? _type;
  int _page = 1;
  int _pageSize = 10;
  late Future<PagedResult<StockMovement>> _movements;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _movements = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<PagedResult<StockMovement>> _load() {
    return context.read<AppDatabase>().listMovements(
      search: _search,
      type: _type,
      page: _page,
      pageSize: _pageSize,
    );
  }

  void _update() {
    setState(() {
      _movements = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SingleChildScrollView(
      child: SectionCard(
        title: 'حركات المخزون',
        subtitle: 'كل تغيير في الرصيد موثّق بالتاريخ والسبب والمنفّذ',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (String value) {
                      _search = value;
                      _page = 1;
                      _update();
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'ابحث باسم المنتج أو السبب…',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<MovementType?>(
                    value: _type,
                    isDense: true,
                    items: <DropdownMenuItem<MovementType?>>[
                      const DropdownMenuItem<MovementType?>(
                        value: null,
                        child: Text('كل الأنواع'),
                      ),
                      for (final MovementType type in MovementType.values)
                        DropdownMenuItem<MovementType?>(
                          value: type,
                          child: Text(type.label),
                        ),
                    ],
                    onChanged: (MovementType? value) {
                      _type = value;
                      _page = 1;
                      _update();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<PagedResult<StockMovement>>(
              future: _movements,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<PagedResult<StockMovement>> snapshot,
                  ) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Text(
                        'جارٍ تحميل الحركات…',
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'تعذر قراءة الحركات: ${snapshot.error}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      );
                    }

                    final PagedResult<StockMovement> result =
                        snapshot.data ??
                        PagedResult<StockMovement>(
                          items: const <StockMovement>[],
                          total: 0,
                          page: 1,
                          pageSize: _pageSize,
                        );

                    if (result.items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'لا توجد حركات مخزون',
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _buildTable(result, theme),
                        ),
                        const SizedBox(height: 12),
                        PaginationBar(
                          from: result.from,
                          to: result.to,
                          total: result.total,
                          page: result.page,
                          pageCount: result.pageCount,
                          pageSize: result.pageSize,
                          suffix: 'حركة',
                          onPageSizeChanged: (int size) {
                            _pageSize = size;
                            _page = 1;
                            _update();
                          },
                          onFirst: () {
                            _page = 1;
                            _update();
                          },
                          onPrevious: () {
                            _page = result.page - 1;
                            _update();
                          },
                          onNext: () {
                            _page = result.page + 1;
                            _update();
                          },
                          onLast: () {
                            _page = result.pageCount;
                            _update();
                          },
                        ),
                      ],
                    );
                  },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(PagedResult<StockMovement> result, ThemeData theme) {
    return DataTable(
      headingRowHeight: 42,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 64,
      columnSpacing: 32,
      columns: const <DataColumn>[
        DataColumn(label: Text('التاريخ')),
        DataColumn(label: Text('المنتج')),
        DataColumn(label: Text('النوع')),
        DataColumn(label: Text('التغيير'), numeric: true),
        DataColumn(label: Text('الرصيد بعد'), numeric: true),
        DataColumn(label: Text('السبب')),
        DataColumn(label: Text('المنفّذ')),
      ],
      rows: result.items.map((StockMovement movement) {
        final Color changeColor = movement.quantityChange >= 0
            ? AppColors.success
            : AppColors.danger;
        final String changeLabel = movement.quantityChange > 0
            ? '+${movement.quantityChange}'
            : movement.quantityChange.toString();

        return DataRow(
          cells: <DataCell>[
            DataCell(
              Text(
                formatDateTime(movement.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ),
            DataCell(
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    movement.productName ?? 'محذوف',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    movement.productSku ?? '',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            DataCell(_MovementBadge(type: movement.type)),
            DataCell(
              Text(
                changeLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: changeColor,
                ),
              ),
            ),
            DataCell(
              Text(
                movement.stockAfter.toString(),
                style: theme.textTheme.bodySmall,
              ),
            ),
            DataCell(Text(movement.reason, style: theme.textTheme.bodySmall)),
            DataCell(
              Text(
                movement.createdByName ?? 'النظام',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _MovementBadge extends StatelessWidget {
  const _MovementBadge({required this.type});

  final MovementType type;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (Color color, IconData icon) = switch (type) {
      MovementType.initial => (AppColors.brand, Icons.flag_outlined),
      MovementType.adjustment => (AppColors.warning, Icons.tune),
      MovementType.purchase => (AppColors.success, Icons.arrow_downward),
      MovementType.sale => (AppColors.danger, Icons.arrow_upward),
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
            type.label,
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
