import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/inventory/inventory_models.dart';
import '../../core/sales/sales_models.dart';
import '../../core/widgets/section_card.dart';
import '../../routing/app_routes.dart';
import '../permissions/permission_checks.dart';
import 'sales_common.dart';

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  int _page = 1;
  int _pageSize = 10;
  late Future<PagedResult<Customer>> _customers;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customers = _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  PagedResult<Customer> _placeholder() {
    return PagedResult<Customer>(
      items: const <Customer>[],
      total: 0,
      page: 1,
      pageSize: _pageSize,
    );
  }

  Future<PagedResult<Customer>> _fetch() {
    return context.read<AppDatabase>().listCustomers(
      search: _searchController.text,
      page: _page,
      pageSize: _pageSize,
    );
  }

  void _reload() {
    _customers = _fetch();
  }

  void _update({int? page, int? pageSize}) {
    setState(() {
      _page = page ?? _page;
      _pageSize = pageSize ?? _pageSize;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canCreate = context.canCreate(AppRoutes.sales);
    final bool canEdit = context.canEdit(AppRoutes.sales);
    final bool canDelete = context.canDelete(AppRoutes.sales);

    return SingleChildScrollView(
      child: SectionCard(
        title: 'العملاء',
        subtitle: 'سجل العملاء المرتبط بفواتير المبيعات',
        actions: <Widget>[
          if (canCreate)
            FilledButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة عميل'),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 250,
              child: TextField(
                controller: _searchController,
                onChanged: (String value) => _update(page: 1),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'ابحث بالاسم أو رقم الهاتف…',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<PagedResult<Customer>>(
              future: _customers,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<PagedResult<Customer>> snapshot,
                  ) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Text(
                        'جارٍ تحميل العملاء…',
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'تعذر قراءة العملاء: ${snapshot.error}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      );
                    }

                    final PagedResult<Customer> result =
                        snapshot.data ?? _placeholder();

                    if (result.items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'لا يوجد عملاء مطابقون للبحث',
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
                          suffix: 'عميل',
                          onPageSizeChanged: (int size) =>
                              _update(pageSize: size, page: 1),
                          onFirst: () => _update(page: 1),
                          onPrevious: () => _update(page: result.page - 1),
                          onNext: () => _update(page: result.page + 1),
                          onLast: () => _update(page: result.pageCount),
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

  Widget _buildTable(
    PagedResult<Customer> result, {
    required bool canEdit,
    required bool canDelete,
  }) {
    final ThemeData theme = Theme.of(context);

    return DataTable(
      headingRowHeight: 42,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 64,
      columnSpacing: 36,
      columns: <DataColumn>[
        const DataColumn(label: Text('الاسم')),
        const DataColumn(label: Text('الهاتف')),
        const DataColumn(label: Text('الملاحظة')),
        const DataColumn(label: Text('الفواتير'), numeric: true),
        const DataColumn(label: Text('الحالة')),
        if (canEdit || canDelete) const DataColumn(label: Text('إجراءات')),
      ],
      rows: result.items.map((Customer customer) {
        return DataRow(
          cells: <DataCell>[
            DataCell(
              Text(
                customer.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            DataCell(
              Text(
                customer.phone ?? '—',
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall,
              ),
            ),
            DataCell(
              Text(customer.note ?? '—', style: theme.textTheme.bodySmall),
            ),
            DataCell(
              Text(
                customer.saleCount.toString(),
                style: theme.textTheme.bodySmall,
              ),
            ),
            DataCell(
              Text(
                customer.isActive ? 'نشط' : 'موقوف',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: customer.isActive
                      ? theme.colorScheme.primary
                      : theme.hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (canEdit || canDelete)
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (canEdit)
                      IconButton(
                        tooltip: 'تعديل',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined, size: 19),
                        onPressed: () => _openEdit(customer),
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
                        onPressed: () => _confirmDelete(customer),
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
    final bool saved =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => const CustomerFormDialog(),
        ) ??
        false;
    if (saved && mounted) {
      _update();
      showAppMessage(context, 'تمت إضافة العميل');
    }
  }

  Future<void> _openEdit(Customer customer) async {
    final bool saved =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) =>
              CustomerFormDialog(existing: customer),
        ) ??
        false;
    if (saved && mounted) {
      _update();
      showAppMessage(context, 'تم تحديث العميل');
    }
  }

  Future<void> _confirmDelete(Customer customer) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('حذف العميل'),
        content: Text(
          'سيتم حذف عميل «${customer.name}» من قاعدة البيانات. لا يمكن التراجع.',
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
      await context.read<AppDatabase>().deleteCustomer(customer.id);
      if (!mounted) return;
      _update();
      showAppMessage(context, 'تم حذف العميل');
    } on AppRuleException catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.message, error: true);
    }
  }
}

class CustomerFormDialog extends StatefulWidget {
  const CustomerFormDialog({super.key, this.existing});

  final Customer? existing;

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;
  late bool _active;

  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _phoneController = TextEditingController(
      text: widget.existing?.phone ?? '',
    );
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
    _active = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'تعديل العميل' : 'إضافة عميل'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل',
                  hintText: 'مثال: أحمد محمد',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phoneController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  hintText: 'اختياري',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'الملاحظة',
                  hintText: 'اختياري',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('نشط'),
                value: _active,
                onChanged: (bool value) {
                  setState(() {
                    _active = value;
                  });
                },
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

    final AppDatabase database = context.read<AppDatabase>();

    try {
      if (_isEdit) {
        await database.updateCustomer(
          widget.existing!.id,
          name: _nameController.text,
          phone: _phoneController.text,
          note: _noteController.text,
          isActive: _active,
        );
      } else {
        await database.createCustomer(
          name: _nameController.text,
          phone: _phoneController.text,
          note: _noteController.text,
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
