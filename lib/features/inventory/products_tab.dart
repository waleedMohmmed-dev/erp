import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/inventory/inventory_models.dart';
import '../../core/widgets/section_card.dart';
import '../../routing/app_routes.dart';
import '../auth/session_controller.dart';
import '../permissions/permission_checks.dart';
import 'inventory_common.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  late ProductQuery _query;
  late Future<PagedResult<Product>> _products;
  late Future<List<InventoryCategory>> _categories;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query = const ProductQuery();
    _products = context.read<AppDatabase>().listProducts(_query);
    _categories = context.read<AppDatabase>().listCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    _products = context.read<AppDatabase>().listProducts(_query);
    _categories = context.read<AppDatabase>().listCategories();
  }

  void _update(ProductQuery query) {
    setState(() {
      _query = query;
      _reload();
    });
  }

  void Function(int, bool) _onSort(ProductSort sort) {
    return (int columnIndex, bool ascending) {
      _update(_query.copyWith(sort: sort, ascending: ascending, page: 1));
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canCreate = context.canCreate(AppRoutes.inventory);
    final bool canEdit = context.canEdit(AppRoutes.inventory);
    final bool canDelete = context.canDelete(AppRoutes.inventory);

    return SingleChildScrollView(
      child: SectionCard(
        title: 'المنتجات',
        subtitle: 'بحث وتصفية وفرز وترقيم صفحات لكل منتجات المخزون',
        actions: <Widget>[
          if (canCreate)
            FilledButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة منتج'),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildToolbar(),
            const SizedBox(height: 14),
            FutureBuilder<PagedResult<Product>>(
              future: _products,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<PagedResult<Product>> snapshot,
                  ) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Text(
                        'جارٍ تحميل المنتجات…',
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'تعذر قراءة المنتجات: ${snapshot.error}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      );
                    }

                    final PagedResult<Product> result =
                        snapshot.data ??
                        PagedResult<Product>(
                          items: const <Product>[],
                          total: 0,
                          page: 1,
                          pageSize: _query.pageSize,
                        );

                    if (result.items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'لا توجد منتجات مطابقة للبحث',
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _buildTable(
                            result,
                            canEdit: canEdit,
                            canDelete: canDelete,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PaginationBar(
                          from: result.from,
                          to: result.to,
                          total: result.total,
                          page: result.page,
                          pageCount: result.pageCount,
                          pageSize: result.pageSize,
                          suffix: 'منتج',
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
              hintText: 'ابحث بالاسم أو الكود…',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
        ),
        FutureBuilder<List<InventoryCategory>>(
          future: _categories,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<InventoryCategory>> snapshot,
              ) {
                final List<InventoryCategory> categories =
                    snapshot.data ?? const <InventoryCategory>[];
                final int? selected =
                    categories.any(
                      (InventoryCategory c) => c.id == _query.categoryId,
                    )
                    ? _query.categoryId
                    : null;
                return DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: selected,
                    isDense: true,
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('كل التصنيفات'),
                      ),
                      for (final InventoryCategory category in categories)
                        DropdownMenuItem<int?>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: (int? value) => _update(
                      _query.copyWith(
                        categoryId: value,
                        clearCategory: value == null,
                        page: 1,
                      ),
                    ),
                  ),
                );
              },
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final StockFilter filter in StockFilter.values)
              ChoiceChip(
                label: Text(filter.label),
                selected: _query.stockFilter == filter,
                onSelected: (bool selected) {
                  if (selected) {
                    _update(_query.copyWith(stockFilter: filter, page: 1));
                  }
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTable(
    PagedResult<Product> result, {
    required bool canEdit,
    required bool canDelete,
  }) {
    final ThemeData theme = Theme.of(context);
    final int? sortIndex = _sortIndexOf(_query.sort);

    return DataTable(
      headingRowHeight: 42,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 64,
      columnSpacing: 32,
      sortColumnIndex: sortIndex,
      sortAscending: _query.ascending,
      columns: <DataColumn>[
        DataColumn(
          label: Text(_sortLabel('الكود', ProductSort.sku)),
          onSort: _onSort(ProductSort.sku),
        ),
        DataColumn(
          label: Text(_sortLabel('المنتج', ProductSort.name)),
          onSort: _onSort(ProductSort.name),
        ),
        const DataColumn(label: Text('التصنيف')),
        const DataColumn(label: Text('الوحدة')),
        DataColumn(
          label: Text(_sortLabel('المخزون', ProductSort.stock)),
          numeric: true,
          onSort: _onSort(ProductSort.stock),
        ),
        const DataColumn(label: Text('الحد الأدنى'), numeric: true),
        DataColumn(
          label: Text(_sortLabel('سعر البيع', ProductSort.salePrice)),
          numeric: true,
          onSort: _onSort(ProductSort.salePrice),
        ),
        if (canEdit || canDelete) const DataColumn(label: Text('إجراءات')),
      ],
      rows: result.items.map((Product product) {
        return DataRow(
          cells: <DataCell>[
            DataCell(
              Text(
                product.sku,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall,
              ),
            ),
            DataCell(
              Text(
                product.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            DataCell(
              Text(
                product.categoryName ?? '—',
                style: theme.textTheme.bodySmall,
              ),
            ),
            DataCell(
              Text(product.unitName ?? '—', style: theme.textTheme.bodySmall),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    product.stock.toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: stockStatusColor(product.status),
                    ),
                  ),
                  const SizedBox(width: 6),
                  StockBadge(status: product.status),
                ],
              ),
            ),
            DataCell(
              Text(
                product.minStock.toString(),
                style: theme.textTheme.bodySmall,
              ),
            ),
            DataCell(
              Text(
                product.salePrice.toStringAsFixed(2),
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (canEdit || canDelete)
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (canEdit)
                      IconButton(
                        tooltip: 'تعديل الرصيد',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.change_circle_outlined,
                          size: 19,
                        ),
                        onPressed: () => _openAdjust(product),
                      ),
                    if (canEdit)
                      IconButton(
                        tooltip: 'تعديل',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined, size: 19),
                        onPressed: () => _openEdit(product),
                      ),
                    if (canDelete)
                      IconButton(
                        tooltip: 'حذف',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 19,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => _confirmDelete(product),
                      ),
                  ],
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  String _sortLabel(String label, ProductSort sort) {
    if (_query.sort != sort) {
      return label;
    }
    return '$label ${_query.ascending ? '▲' : '▼'}';
  }

  int? _sortIndexOf(ProductSort sort) {
    switch (sort) {
      case ProductSort.sku:
        return 0;
      case ProductSort.name:
        return 1;
      case ProductSort.stock:
        return 4;
      case ProductSort.salePrice:
        return 6;
      case ProductSort.updatedAt:
        return null;
    }
  }

  Future<void> _openCreate() async {
    final bool saved =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => const ProductFormDialog(),
        ) ??
        false;
    if (saved && mounted) {
      setState(() => _reload());
      showAppMessage(context, 'تمت إضافة المنتج');
    }
  }

  Future<void> _openEdit(Product product) async {
    final bool saved =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) =>
              ProductFormDialog(existing: product),
        ) ??
        false;
    if (saved && mounted) {
      setState(() => _reload());
      showAppMessage(context, 'تم تحديث بيانات المنتج');
    }
  }

  Future<void> _openAdjust(Product product) async {
    final bool saved =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) =>
              StockAdjustDialog(product: product),
        ) ??
        false;
    if (saved && mounted) {
      setState(() => _reload());
      showAppMessage(context, 'تم تعديل رصيد المنتج');
    }
  }

  Future<void> _confirmDelete(Product product) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text(
          'سيتم حذف المنتج «${product.name}» ورصيده الابتدائي من قاعدة البيانات. لا يمكن التراجع.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await context.read<AppDatabase>().deleteProduct(product.id);
      if (!mounted) return;
      setState(() => _reload());
      showAppMessage(context, 'تم حذف المنتج');
    } on AppRuleException catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.message, error: true);
    }
  }
}

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({super.key, this.existing});

  final Product? existing;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _costController;
  late final TextEditingController _saleController;
  late final TextEditingController _minStockController;
  late final TextEditingController _stockController;
  late Future<List<InventoryCategory>> _categories;
  late Future<List<InventoryUnit>> _units;
  int? _categoryId;
  int? _unitId;
  late bool _active;

  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final Product? existing = widget.existing;
    _skuController = TextEditingController(text: existing?.sku ?? '');
    _nameController = TextEditingController(text: existing?.name ?? '');
    _costController = TextEditingController(
      text: existing == null ? '' : existing.costPrice.toStringAsFixed(2),
    );
    _saleController = TextEditingController(
      text: existing == null ? '' : existing.salePrice.toStringAsFixed(2),
    );
    _minStockController = TextEditingController(
      text: existing == null ? '' : existing.minStock.toString(),
    );
    _stockController = TextEditingController();
    _categoryId = existing?.categoryId;
    _unitId = existing?.unitId;
    _active = existing?.isActive ?? true;
    _categories = context.read<AppDatabase>().listCategories();
    _units = context.read<AppDatabase>().listUnits();
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _costController.dispose();
    _saleController.dispose();
    _minStockController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEdit ? 'تعديل المنتج' : 'إضافة منتج'),
      content: SizedBox(
        width: 470,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _skuController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'كود المنتج',
                  hintText: 'SKP-1009',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'اسم المنتج',
                  hintText: 'مثال: بروتين شوكولاتة 1 كجم',
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<InventoryCategory>>(
                future: _categories,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<InventoryCategory>> snapshot,
                    ) {
                      final List<InventoryCategory> categories =
                          snapshot.data ?? const <InventoryCategory>[];
                      final int? selected =
                          categories.any(
                            (InventoryCategory c) => c.id == _categoryId,
                          )
                          ? _categoryId
                          : null;
                      return InputDecorator(
                        decoration: const InputDecoration(labelText: 'التصنيف'),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: selected,
                            isDense: true,
                            isExpanded: true,
                            items: <DropdownMenuItem<int?>>[
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('بدون تصنيف'),
                              ),
                              for (final InventoryCategory category
                                  in categories)
                                DropdownMenuItem<int?>(
                                  value: category.id,
                                  child: Text(category.name),
                                ),
                            ],
                            onChanged: (int? value) =>
                                setState(() => _categoryId = value),
                          ),
                        ),
                      );
                    },
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<InventoryUnit>>(
                future: _units,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<InventoryUnit>> snapshot,
                    ) {
                      final List<InventoryUnit> units =
                          snapshot.data ?? const <InventoryUnit>[];
                      final int? selected =
                          units.any((InventoryUnit u) => u.id == _unitId)
                          ? _unitId
                          : null;
                      return InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'وحدة القياس',
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: selected,
                            isDense: true,
                            isExpanded: true,
                            items: <DropdownMenuItem<int?>>[
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('اختر الوحدة'),
                              ),
                              for (final InventoryUnit unit in units)
                                DropdownMenuItem<int?>(
                                  value: unit.id,
                                  child: Text(unit.name),
                                ),
                            ],
                            onChanged: (int? value) =>
                                setState(() => _unitId = value),
                          ),
                        ),
                      );
                    },
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'سعر التكلفة',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _saleController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'سعر البيع'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _minStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الحد الأدنى للتنبيه',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isEdit
                        ? Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'الرصيد: ${widget.existing!.stock}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : TextField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'الرصيد الابتدائي',
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('منتج نشط'),
                subtitle: Text(
                  _active
                      ? 'يظهر في قائمة البيع والشراء'
                      : 'مخفي من العمليات الجديدة',
                  style: theme.textTheme.bodySmall,
                ),
                value: _active,
                onChanged: (bool value) => setState(() => _active = value),
              ),
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

  double? _parsePrice(String raw) {
    final String clean = raw.trim().replaceAll(',', '.');
    if (clean.isEmpty) {
      return 0;
    }
    return double.tryParse(clean);
  }

  int? _parseCount(String raw) {
    final String clean = raw.trim();
    if (clean.isEmpty) {
      return 0;
    }
    return int.tryParse(clean);
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final double? cost = _parsePrice(_costController.text);
    final double? sale = _parsePrice(_saleController.text);
    final int? minStock = _parseCount(_minStockController.text);
    final int? initialStock = _parseCount(_stockController.text);

    if (cost == null || sale == null) {
      setState(() {
        _saving = false;
        _error = 'سعر غير صالح، استخدم أرقاماً فقط';
      });
      return;
    }
    if (minStock == null) {
      setState(() {
        _saving = false;
        _error = 'الحد الأدنى غير صالح، استخدم عدداً صحيحاً';
      });
      return;
    }
    if (initialStock == null) {
      setState(() {
        _saving = false;
        _error = 'الرصيد الابتدائي غير صالح، استخدم عدداً صحيحاً';
      });
      return;
    }
    if (_unitId == null) {
      setState(() {
        _saving = false;
        _error = 'اختر وحدة القياس';
      });
      return;
    }

    final AppDatabase database = context.read<AppDatabase>();

    try {
      if (_isEdit) {
        await database.updateProduct(
          id: widget.existing!.id,
          sku: _skuController.text,
          name: _nameController.text,
          categoryId: _categoryId,
          unitId: _unitId!,
          costPrice: cost,
          salePrice: sale,
          minStock: minStock,
          isActive: _active,
        );
      } else {
        await database.createProduct(
          sku: _skuController.text,
          name: _nameController.text,
          categoryId: _categoryId,
          unitId: _unitId!,
          costPrice: cost,
          salePrice: sale,
          stock: initialStock,
          minStock: minStock,
          isActive: _active,
        );
      }
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
          _error = 'حدث خطأ غير متوقع أثناء الحفظ';
        });
      }
    }
  }
}

enum _AdjustMode { set, add, remove }

class StockAdjustDialog extends StatefulWidget {
  const StockAdjustDialog({super.key, required this.product});

  final Product product;

  @override
  State<StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<StockAdjustDialog> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  _AdjustMode _mode = _AdjustMode.set;

  String? _error;
  bool _saving = false;

  int get _current => widget.product.stock;

  int? get _preview {
    final int? quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null) {
      return null;
    }
    switch (_mode) {
      case _AdjustMode.set:
        return quantity;
      case _AdjustMode.add:
        return _current + quantity;
      case _AdjustMode.remove:
        return _current - quantity;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? preview = _preview;
    final StockStatus? previewStatus = preview == null
        ? null
        : preview <= 0
        ? StockStatus.out
        : preview <= widget.product.minStock
        ? StockStatus.low
        : StockStatus.ok;

    return AlertDialog(
      title: const Text('تعديل رصيد المنتج'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.product.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.product.sku} · الرصيد الحالي: $_current '
                '${widget.product.unitName ?? ''}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('تعيين رصيد جديد'),
                    selected: _mode == _AdjustMode.set,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _mode = _AdjustMode.set);
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('زيادة على الرصيد'),
                    selected: _mode == _AdjustMode.add,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _mode = _AdjustMode.add);
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('خصم من الرصيد'),
                    selected: _mode == _AdjustMode.remove,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _mode = _AdjustMode.remove);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                onChanged: (String value) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'الكمية',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'سبب التعديل',
                  hintText: 'مثال: جرد المخزن',
                ),
              ),
              if (preview != null && previewStatus != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'الرصيد بعد التعديل: $preview',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: stockStatusColor(previewStatus),
                  ),
                ),
              ],
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

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final int? quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 0) {
      setState(() {
        _saving = false;
        _error = 'أدخل كمية صحيحة غير سالبة';
      });
      return;
    }
    if (quantity == 0 && _mode != _AdjustMode.set) {
      setState(() {
        _saving = false;
        _error = 'أدخل كمية أكبر من صفر';
      });
      return;
    }

    final String reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() {
        _saving = false;
        _error = 'سبب التعديل مطلوب';
      });
      return;
    }

    final int newQuantity = switch (_mode) {
      _AdjustMode.set => quantity,
      _AdjustMode.add => _current + quantity,
      _AdjustMode.remove => _current - quantity,
    };

    final AppDatabase database = context.read<AppDatabase>();
    final SessionController session = context.read<SessionController>();

    try {
      await database.adjustStock(
        productId: widget.product.id,
        newQuantity: newQuantity,
        reason: reason,
        createdBy: session.user?.id,
      );
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
          _error = 'حدث خطأ غير متوقع أثناء الحفظ';
        });
      }
    }
  }
}
