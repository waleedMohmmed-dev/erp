import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/inventory/inventory_models.dart';
import '../../core/purchases/purchase_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/section_card.dart';
import '../../routing/app_routes.dart';
import '../auth/session_controller.dart';
import '../permissions/permission_checks.dart';
import 'purchases_common.dart';
import 'purchase_form_dialog.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  late PurchaseQuery _query;
  late Future<PagedResult<Purchase>> _orders;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query = const PurchaseQuery();
    _orders = context.read<AppDatabase>().listPurchases(
      search: _query.search,
      status: _query.status,
      page: _query.page,
      pageSize: _query.pageSize,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    _orders = context.read<AppDatabase>().listPurchases(
      search: _query.search,
      status: _query.status,
      page: _query.page,
      pageSize: _query.pageSize,
    );
  }

  void _update(PurchaseQuery query) {
    setState(() {
      _query = query;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canCreate = context.canCreate(AppRoutes.purchases);
    final bool canEdit = context.canEdit(AppRoutes.purchases);

    return SingleChildScrollView(
      child: SectionCard(
        title: 'أوامر الشراء',
        subtitle: 'إنشاء وعرض وإلغاء أوامر الشراء مع تحديث المخزون تلقائياً',
        actions: <Widget>[
          if (canCreate)
            FilledButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('أمر جديد'),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildToolbar(),
            const SizedBox(height: 14),
            FutureBuilder<PagedResult<Purchase>>(
              future: _orders,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<PagedResult<Purchase>> snapshot,
                  ) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'تعذر قراءة أوامر الشراء: ${snapshot.error}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      );
                    }

                    final PagedResult<Purchase> result =
                        snapshot.data ??
                        PagedResult<Purchase>(
                          items: const <Purchase>[],
                          total: 0,
                          page: 1,
                          pageSize: _query.pageSize,
                        );

                    if (result.items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'لا توجد أوامر شراء مطابقة للبحث',
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _buildTable(result, canEdit: canEdit),
                        ),
                        const SizedBox(height: 12),
                        PaginationBar(
                          from: result.from,
                          to: result.to,
                          total: result.total,
                          page: result.page,
                          pageCount: result.pageCount,
                          pageSize: result.pageSize,
                          suffix: 'أمر',
                          onPageSizeChanged: (int size) =>
                              _update(_query.copyWith(pageSize: size, page: 1)),
                          onFirst: () => _update(_query.copyWith(page: 1)),
                          onPrevious: () =>
                              _update(_query.copyWith(page: result.page - 1)),
                          onNext: () =>
                              _update(_query.copyWith(page: result.page + 1)),
                          onLast: () =>
                              _update(_query.copyWith(page: result.pageCount)),
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

  Widget _buildToolbar() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 250,
          child: TextField(
            controller: _searchController,
            onChanged: (String value) =>
                _update(_query.copyWith(search: value, page: 1)),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'ابحث برقم الأمر أو اسم المورد…',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final PurchaseStatusFilter filter
                in PurchaseStatusFilter.values)
              ChoiceChip(
                label: Text(filter.label),
                selected:
                    (filter.status == null && _query.status == null) ||
                    (_query.status != null && _query.status == filter.status),
                onSelected: (bool selected) {
                  if (selected) {
                    _update(
                      _query.copyWith(
                        status: filter.status,
                        clearStatus: filter.status == null,
                        page: 1,
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTable(PagedResult<Purchase> result, {required bool canEdit}) {
    final ThemeData theme = Theme.of(context);

    return DataTable(
      headingRowHeight: 42,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 64,
      columnSpacing: 36,
      columns: const <DataColumn>[
        DataColumn(label: Text('رقم الأمر')),
        DataColumn(label: Text('المورد')),
        DataColumn(label: Text('التاريخ')),
        DataColumn(label: Text('الإجمالي'), numeric: true),
        DataColumn(label: Text('الحالة')),
        DataColumn(label: Text('إجراءات')),
      ],
      rows: result.items.map((Purchase purchase) {
        return DataRow(
          cells: <DataCell>[
            DataCell(
              Text(
                purchase.orderNo,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            DataCell(
              Text(
                purchase.supplierName ?? 'غير محدد',
                style: theme.textTheme.bodySmall,
              ),
            ),
            DataCell(
              Text(
                formatDateTime(purchase.purchaseDate),
                style: theme.textTheme.bodySmall,
              ),
            ),
            DataCell(
              Text(
                formatMoney(purchase.total),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            DataCell(PurchaseStatusBadge(status: purchase.status)),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'عرض الأمر',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.visibility_outlined, size: 19),
                    onPressed: () => _openView(purchase),
                  ),
                  if (canEdit && !purchase.isCancelled)
                    IconButton(
                      tooltip: 'إلغاء الأمر',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.block_outlined,
                        size: 19,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () => _confirmCancel(purchase),
                    ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _openCreate() async {
    final Purchase? created = await showDialog<Purchase>(
      context: context,
      builder: (BuildContext context) => const PurchaseFormDialog(),
    );
    if (created != null && mounted) {
      _update(_query);
      showAppMessage(context, 'تم إنشاء أمر الشراء ${created.orderNo}');
    }
  }

  Future<void> _openView(Purchase purchase) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          PurchaseViewDialog(purchaseId: purchase.id),
    );
  }

  Future<void> _confirmCancel(Purchase purchase) async {
    final bool? cancelled = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          PurchaseCancelDialog(purchase: purchase),
    );
    if (cancelled == true && mounted) {
      _update(_query);
      showAppMessage(context, 'تم إلغاء أمر الشراء ${purchase.orderNo}');
    }
  }
}
