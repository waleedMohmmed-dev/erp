import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/inventory/inventory_models.dart';
import '../../core/sales/sales_models.dart';
import '../../core/widgets/section_card.dart';
import '../../routing/app_routes.dart';
import '../auth/session_controller.dart';
import '../permissions/permission_checks.dart';
import 'sales_common.dart';

class InvoicesTab extends StatefulWidget {
  const InvoicesTab({super.key});

  @override
  State<InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<InvoicesTab> {
  late SaleQuery _query;
  late Future<PagedResult<Sale>> _sales;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query = const SaleQuery();
    _sales = context.read<AppDatabase>().listSales(_query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    _sales = context.read<AppDatabase>().listSales(_query);
  }

  void _update(SaleQuery query) {
    setState(() {
      _query = query;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canCreate = context.canCreate(AppRoutes.sales);
    final bool canEdit = context.canEdit(AppRoutes.sales);

    return SingleChildScrollView(
      child: SectionCard(
        title: 'فواتير المبيعات',
        subtitle: 'إنشاء وعرض وإلغاء الفواتير مع تحديث المخزون تلقائياً',
        actions: <Widget>[
          if (canCreate)
            FilledButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('فاتورة جديدة'),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildToolbar(),
            const SizedBox(height: 14),
            FutureBuilder<PagedResult<Sale>>(
              future: _sales,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<PagedResult<Sale>> snapshot,
                  ) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Text(
                        'جارٍ تحميل الفواتير…',
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'تعذر قراءة الفواتير: ${snapshot.error}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      );
                    }

                    final PagedResult<Sale> result =
                        snapshot.data ??
                        PagedResult<Sale>(
                          items: const <Sale>[],
                          total: 0,
                          page: 1,
                          pageSize: _query.pageSize,
                        );

                    if (result.items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'لا توجد فواتير مطابقة للبحث',
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
                          suffix: 'فاتورة',
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
              hintText: 'ابحث برقم الفاتورة أو اسم العميل…',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final SaleStatusFilter filter in SaleStatusFilter.values)
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

  Widget _buildTable(PagedResult<Sale> result, {required bool canEdit}) {
    final ThemeData theme = Theme.of(context);

    return DataTable(
      headingRowHeight: 42,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 64,
      columnSpacing: 36,
      columns: <DataColumn>[
        const DataColumn(label: Text('رقم الفاتورة')),
        const DataColumn(label: Text('العميل')),
        const DataColumn(label: Text('التاريخ')),
        const DataColumn(label: Text('الإجمالي'), numeric: true),
        const DataColumn(label: Text('الحالة')),
        const DataColumn(label: Text('إجراءات')),
      ],
      rows: result.items.map((Sale sale) {
        return DataRow(
          cells: <DataCell>[
            DataCell(
              Text(
                sale.invoiceNo,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            DataCell(
              Text(sale.customerDisplay, style: theme.textTheme.bodySmall),
            ),
            DataCell(
              Text(
                formatDateTime(sale.saleDate),
                style: theme.textTheme.bodySmall,
              ),
            ),
            DataCell(
              Text(
                formatMoney(sale.total),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            DataCell(SaleStatusBadge(status: sale.status)),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'عرض الفاتورة',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.visibility_outlined, size: 19),
                    onPressed: () => _openView(sale),
                  ),
                  if (canEdit && !sale.isCancelled)
                    IconButton(
                      tooltip: 'إلغاء الفاتورة',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.block_outlined,
                        size: 19,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () => _confirmCancel(sale),
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
    final Sale? created = await showDialog<Sale>(
      context: context,
      builder: (BuildContext context) => const SaleFormDialog(),
    );
    if (created != null && mounted) {
      _update(_query);
      showAppMessage(context, 'تم إنشاء الفاتورة ${created.invoiceNo}');
    }
  }

  Future<void> _openView(Sale sale) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => SaleViewDialog(saleId: sale.id),
    );
  }

  Future<void> _confirmCancel(Sale sale) async {
    final bool? cancelled = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => SaleCancelDialog(sale: sale),
    );
    if (cancelled == true && mounted) {
      _update(_query);
      showAppMessage(context, 'تم إلغاء الفاتورة ${sale.invoiceNo}');
    }
  }
}

class SaleFormDialog extends StatefulWidget {
  const SaleFormDialog({super.key});

  @override
  State<SaleFormDialog> createState() => _SaleFormDialogState();
}

class _SaleFormDialogState extends State<SaleFormDialog> {
  late final Future<List<Product>> _products;
  late final Future<List<Customer>> _customers;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );

  final List<SaleDraftLine> _lines = <SaleDraftLine>[];
  int? _customerId;
  int? _productId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final AppDatabase database = context.read<AppDatabase>();
    _products = database.listProducts(const ProductQuery(pageSize: 100)).then((
      PagedResult<Product> result,
    ) {
      return result.items.where((Product product) => product.isActive).toList();
    });
    _customers = database.activeCustomers();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _subtotal => _lines.fold<double>(
    0,
    (double sum, SaleDraftLine line) =>
        sum + roundMoney(line.quantity * line.unitPrice),
  );

  double get _discount {
    final double? parsed = _parsePrice(_discountController.text);
    if (parsed == null || parsed < 0) {
      return 0;
    }
    return parsed;
  }

  double get _total {
    final double value = _subtotal - _discount;
    return value < 0 ? 0 : roundMoney(value);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: const Text('فاتورة مبيعات جديدة'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildCustomerField(),
              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  hintText: 'اختياري',
                ),
              ),
              const SizedBox(height: 18),
              Text('أصناف الفاتورة', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              _buildAddRow(theme),
              if (_lines.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _buildLinesList(theme),
              ],
              const SizedBox(height: 14),
              _buildTotals(theme),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: Icon(_saving ? Icons.hourglass_top : Icons.save, size: 18),
          label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
    );
  }

  Widget _buildCustomerField() {
    return FutureBuilder<List<Customer>>(
      future: _customers,
      builder: (BuildContext context, AsyncSnapshot<List<Customer>> snapshot) {
        final List<Customer> customers = snapshot.data ?? const <Customer>[];
        final int? selected =
            customers.any((Customer customer) => customer.id == _customerId)
            ? _customerId
            : null;
        return InputDecorator(
          decoration: const InputDecoration(labelText: 'العميل'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selected,
              isDense: true,
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('عميل نقدي'),
                ),
                for (final Customer customer in customers)
                  DropdownMenuItem<int?>(
                    value: customer.id,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(
                        customer.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
              onChanged: (int? value) {
                setState(() {
                  _customerId = value;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinesList(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: <Widget>[
          for (int index = 0; index < _lines.length; index++)
            _buildLineRow(theme, _lines[index], index),
        ],
      ),
    );
  }

  Widget _buildLineRow(ThemeData theme, SaleDraftLine line, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              line.productName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${line.quantity} × ${formatMoney(line.unitPrice)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 80,
            child: Text(
              formatMoney(roundMoney(line.quantity * line.unitPrice)),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'إزالة',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 17, color: theme.colorScheme.error),
            onPressed: () {
              setState(() {
                _lines.removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTotals(ThemeData theme) {
    return Row(
      children: <Widget>[
        Text('المجموع: ', style: theme.textTheme.bodySmall),
        Text(
          formatMoney(_subtotal),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _discountController,
            onChanged: (String value) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'الخصم',
            ),
          ),
        ),
        const SizedBox(width: 18),
        Text('الإجمالي: ', style: theme.textTheme.bodySmall),
        Text(
          formatMoney(_total),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  double? _parsePrice(String raw) {
    final String clean = raw.trim().replaceAll(',', '.');
    if (clean.isEmpty) {
      return 0;
    }
    return double.tryParse(clean);
  }

  void _addLine() {
    setState(() {
      _error = null;
    });

    final int? productId = _productId;
    if (productId == null) {
      setState(() {
        _error = 'اختر المنتج أولاً';
      });
      return;
    }
    if (_lines.any((SaleDraftLine line) => line.productId == productId)) {
      setState(() {
        _error = 'المنتج مضاف بالفعل في الفاتورة';
      });
      return;
    }

    final String quantityRaw = _quantityController.text.trim();
    final int? quantity = int.tryParse(quantityRaw);
    if (quantity == null || quantity <= 0) {
      setState(() {
        _error = 'الكمية يجب أن تكون عدداً أكبر من صفر';
      });
      return;
    }

    final double? price = _parsePrice(_priceController.text);
    if (price == null || price < 0) {
      setState(() {
        _error = 'سعر غير صالح، استخدم أرقاماً فقط';
      });
      return;
    }

    final List<Product> products = _cachedProducts;
    final Product? product = products
        .where((Product item) => item.id == productId)
        .firstOrNull;
    if (product == null) {
      setState(() {
        _error = 'المنتج غير موجود';
      });
      return;
    }

    setState(() {
      _lines.add((
        productId: product.id,
        productSku: product.sku,
        productName: product.name,
        quantity: quantity,
        unitPrice: price,
      ));
      _quantityController.text = '1';
      _priceController.clear();
      _productId = null;
      _error = null;
    });
  }

  List<Product> _cachedProducts = const <Product>[];

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      setState(() {
        _error = 'يجب إضافة منتج واحد على الأقل';
      });
      return;
    }

    final double? discount = _parsePrice(_discountController.text);
    if (discount == null || discount < 0) {
      setState(() {
        _error = 'الخصم غير صالح، استخدم أرقاماً فقط';
      });
      return;
    }
    if (discount > _subtotal) {
      setState(() {
        _error = 'الخصم أكبر من مجموع الفاتورة';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final AppDatabase database = context.read<AppDatabase>();
    final SessionController session = context.read<SessionController>();

    try {
      final Sale created = await database.createSale(
        customerId: _customerId,
        items: <SaleLineInput>[
          for (final SaleDraftLine line in _lines)
            (
              productId: line.productId,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
            ),
        ],
        discount: discount,
        notes: _notesController.text,
        createdBy: session.user?.id,
      );
      if (mounted) {
        Navigator.of(context).pop(created);
      }
    } on AppRuleException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'حدث خطأ غير متوقع أثناء الحفظ';
        });
      }
    }
  }

  Widget _buildProductPicker(ThemeData theme) {
    return FutureBuilder<List<Product>>(
      future: _products,
      builder: (BuildContext context, AsyncSnapshot<List<Product>> snapshot) {
        final List<Product> products = _cachedProducts =
            snapshot.data ?? const <Product>[];
        final Product? selected = products
            .where((Product product) => product.id == _productId)
            .firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InputDecorator(
              decoration: const InputDecoration(labelText: 'المنتج'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: selected?.id,
                  isDense: true,
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('اختر منتجاً…'),
                    ),
                    for (final Product product in products)
                      DropdownMenuItem<int?>(
                        value: product.id,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: Text(
                            '${product.name} (${product.sku})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (int? value) {
                    setState(() {
                      _productId = value;
                      _error = null;
                      final Product? picked = products
                          .where((Product product) => product.id == value)
                          .firstOrNull;
                      if (picked != null) {
                        _priceController.text = picked.salePrice
                            .toStringAsFixed(2);
                      }
                    });
                  },
                ),
              ),
            ),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'المتوفر: ${selected.stock}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAddRow(ThemeData theme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: <Widget>[
        SizedBox(width: 250, child: _buildProductPicker(theme)),
        SizedBox(
          width: 80,
          child: TextField(
            controller: _quantityController,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'الكمية',
            ),
          ),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: _priceController,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'سعر البيع',
            ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: _addLine,
          icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
          label: const Text('إضافة'),
        ),
      ],
    );
  }
}

class SaleViewDialog extends StatelessWidget {
  const SaleViewDialog({super.key, required this.saleId});

  final int saleId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppDatabase database = context.read<AppDatabase>();

    return AlertDialog(
      title: const Text('تفاصيل الفاتورة'),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<Sale?>(
          future: database.saleById(saleId),
          builder: (BuildContext context, AsyncSnapshot<Sale?> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('جارٍ تحميل الفاتورة…'),
              );
            }
            final Sale? sale = snapshot.data;
            if (sale == null) {
              return const Text('الفاتورة غير موجودة');
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _infoRow(theme, 'رقم الفاتورة', sale.invoiceNo, ltr: true),
                  _infoRow(theme, 'العميل', sale.customerDisplay),
                  _infoRow(theme, 'التاريخ', formatDateTime(sale.saleDate)),
                  Row(
                    children: <Widget>[
                      Text('الحالة: ', style: theme.textTheme.bodySmall),
                      SaleStatusBadge(status: sale.status),
                    ],
                  ),
                  if (sale.notes != null) ...<Widget>[
                    const SizedBox(height: 6),
                    _infoRow(theme, 'ملاحظات', sale.notes!),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: <Widget>[
                        _itemHeader(theme),
                        for (final SaleLine line in sale.items)
                          _itemRow(theme, line),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _totalRow(theme, 'المجموع', formatMoney(sale.subtotal)),
                  _totalRow(theme, 'الخصم', formatMoney(sale.discount)),
                  const Divider(height: 18),
                  _totalRow(
                    theme,
                    'الإجمالي',
                    formatMoney(sale.total),
                    strong: true,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  Widget _infoRow(
    ThemeData theme,
    String label,
    String value, {
    bool ltr = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Text('$label: ', style: theme.textTheme.bodySmall),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.hoverColor,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'المنتج',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              'الكمية',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'السعر',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'الإجمالي',
              textAlign: TextAlign.end,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(ThemeData theme, SaleLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              line.productName,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              line.quantity.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              formatMoney(line.unitPrice),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              formatMoney(line.lineTotal),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    ThemeData theme,
    String label,
    String value, {
    bool strong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: strong
                ? theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )
                : theme.textTheme.bodySmall,
          ),
          Text(
            value,
            style: strong
                ? theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
          ),
        ],
      ),
    );
  }
}

class SaleCancelDialog extends StatefulWidget {
  const SaleCancelDialog({super.key, required this.sale});

  final Sale sale;

  @override
  State<SaleCancelDialog> createState() => _SaleCancelDialogState();
}

class _SaleCancelDialogState extends State<SaleCancelDialog> {
  String? _error;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إلغاء الفاتورة ${widget.sale.invoiceNo}'),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'سيتم إرجاع الكميات إلى المخزون وتسجيل الفاتورة كملغاة. لا يمكن التراجع.',
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('تراجع'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'جارٍ الإلغاء…' : 'إلغاء الفاتورة'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final AppDatabase database = context.read<AppDatabase>();
    final SessionController session = context.read<SessionController>();

    try {
      await database.cancelSale(widget.sale.id, byUser: session.user?.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AppRuleException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'حدث خطأ غير متوقع أثناء الإلغاء';
        });
      }
    }
  }
}
