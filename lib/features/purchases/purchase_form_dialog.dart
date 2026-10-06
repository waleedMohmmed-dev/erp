import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/inventory/inventory_models.dart';
import '../../core/purchases/purchase_models.dart';
import '../../core/sales/sales_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/section_card.dart';
import '../../routing/app_routes.dart';
import '../auth/session_controller.dart';
import '../permissions/permission_checks.dart';
import 'purchases_common.dart' hide PurchaseLineInput;

class PurchaseFormDialog extends StatefulWidget {
  const PurchaseFormDialog({super.key});

  @override
  State<PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<PurchaseFormDialog> {
  late final Future<List<Product>> _products;
  late final Future<List<Supplier>> _suppliers;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );

  final List<PurchaseDraftLine> _lines = <PurchaseDraftLine>[];
  int? _supplierId;
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
    _suppliers = database.listSuppliers();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _subtotal => _lines.fold<double>(
    0,
    (double sum, PurchaseDraftLine line) =>
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
      title: const Text(' أمر شراء جديد'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildSupplierField(),
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
              Text('أصناف أمر الشراء', style: theme.textTheme.titleSmall),
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

  Widget _buildSupplierField() {
    return FutureBuilder<List<Supplier>>(
      future: _suppliers,
      builder: (BuildContext context, AsyncSnapshot<List<Supplier>> snapshot) {
        final List<Supplier> suppliers = snapshot.data ?? const <Supplier>[];
        final int? selected = suppliers.any((Supplier s) => s.id == _supplierId)
            ? _supplierId
            : null;
        return InputDecorator(
          decoration: const InputDecoration(labelText: 'المورد'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selected,
              isDense: true,
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('بدون مورد'),
                ),
                for (final Supplier s in suppliers)
                  DropdownMenuItem<int?>(
                    value: s.id,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
              ],
              onChanged: (int? value) {
                setState(() {
                  _supplierId = value;
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

  Widget _buildLineRow(ThemeData theme, PurchaseDraftLine line, int index) {
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
    if (_lines.any((PurchaseDraftLine line) => line.productId == productId)) {
      setState(() {
        _error = 'المنتج مضاف بالفعل في أمر الشراء';
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

    final double? cost = _parsePrice(_costController.text);
    if (cost == null || cost < 0) {
      setState(() {
        _error = 'سعر التكلفة غير صالح، استخدم أرقاماً فقط';
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
        unitPrice: cost,
      ));
      _quantityController.text = '1';
      _costController.clear();
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
        _error = 'الخصم أكبر من مجموع أمر الشراء';
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
      final Purchase created = await database.createPurchase(
        supplierId: _supplierId,
        items: <PurchaseLineInput>[
          for (final PurchaseDraftLine line in _lines)
            PurchaseLineInput(
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
                        _costController.text = picked.costPrice.toStringAsFixed(
                          2,
                        );
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
            controller: _costController,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'سعر التكلفة',
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

class PurchaseViewDialog extends StatelessWidget {
  const PurchaseViewDialog({super.key, required this.purchaseId});
  final int purchaseId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppDatabase database = context.read<AppDatabase>();

    return AlertDialog(
      title: const Text('تفاصيل أمر الشراء'),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<Purchase?>(
          future: database.purchaseById(purchaseId),
          builder: (BuildContext context, AsyncSnapshot<Purchase?> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('جارٍ تحميل أمر الشراء…'),
              );
            }
            final Purchase? purchase = snapshot.data;
            if (purchase == null) {
              return const Text(' أمر الشراء غير موجود');
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _infoRow(theme, 'رقم الأمر', purchase.orderNo, ltr: true),
                  _infoRow(
                    theme,
                    'المورد',
                    purchase.supplierName ?? 'غير محدد',
                  ),
                  _infoRow(
                    theme,
                    'التاريخ',
                    formatDateTime(purchase.purchaseDate),
                  ),
                  Row(
                    children: <Widget>[
                      Text('الحالة: ', style: theme.textTheme.bodySmall),
                      PurchaseStatusBadge(status: purchase.status),
                    ],
                  ),
                  if (purchase.notes != null) ...<Widget>[
                    const SizedBox(height: 6),
                    _infoRow(theme, 'ملاحظات', purchase.notes!),
                  ],
                  const SizedBox(height: 12),
                  Text('أصناف الأمر', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  if (purchase.items.isNotEmpty)
                    DataTable(
                      headingRowHeight: 36,
                      dataRowMinHeight: 36,
                      columnSpacing: 12,
                      columns: const <DataColumn>[
                        DataColumn(label: Text('المنتج')),
                        DataColumn(label: Text('الكمية'), numeric: true),
                        DataColumn(label: Text('سعر التكلفة'), numeric: true),
                        DataColumn(label: Text('الإجمالي'), numeric: true),
                      ],
                      rows: purchase.items.map((PurchaseLine line) {
                        return DataRow(
                          cells: <DataCell>[
                            DataCell(Text(line.productName)),
                            DataCell(Text('${line.quantity}')),
                            DataCell(Text(formatMoney(line.unitPrice))),
                            DataCell(Text(formatMoney(line.lineTotal))),
                          ],
                        );
                      }).toList(),
                    )
                  else
                    const Text('لا توجد أصناف'),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Text(
                        'المجموع الفرعي: ',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        formatMoney(purchase.subtotal),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Text('الخصم: ', style: theme.textTheme.bodySmall),
                      Text(
                        formatMoney(purchase.discount),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 18),
                      Text('الإجمالي: ', style: theme.textTheme.bodySmall),
                      Text(
                        formatMoney(purchase.total),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              '$label: ',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
              textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}

class PurchaseCancelDialog extends StatelessWidget {
  const PurchaseCancelDialog({super.key, required this.purchase});
  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إلغاء أمر الشراء'),
      content: Text(
        'هل أنت متأكد من إلغاء أمر الشراء ${purchase.orderNo}؟\n'
        'سيتم إعادة المخزون للمنتجات المضافة.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('تراجع'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.block, size: 18),
          label: const Text('إلغاء'),
        ),
      ],
    );
  }
}
