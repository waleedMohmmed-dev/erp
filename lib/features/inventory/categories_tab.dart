import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/inventory/inventory_models.dart';
import '../../core/widgets/section_card.dart';
import '../../routing/app_routes.dart';
import '../permissions/permission_checks.dart';
import 'inventory_common.dart';

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  late Future<List<InventoryCategory>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = context.read<AppDatabase>().listCategories();
  }

  void _reload() {
    setState(() {
      _categories = context.read<AppDatabase>().listCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canCreate = context.canCreate(AppRoutes.inventory);
    final bool canEdit = context.canEdit(AppRoutes.inventory);
    final bool canDelete = context.canDelete(AppRoutes.inventory);

    return SingleChildScrollView(
      child: SectionCard(
        title: 'التصنيفات',
        subtitle: 'تجميع المنتجات في مجموعات واضحة داخل المخزون',
        actions: <Widget>[
          if (canCreate)
            FilledButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة تصنيف'),
            ),
        ],
        child: FutureBuilder<List<InventoryCategory>>(
          future: _categories,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<InventoryCategory>> snapshot,
              ) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Text(
                    'جارٍ تحميل التصنيفات…',
                    style: theme.textTheme.bodySmall,
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'تعذر قراءة التصنيفات: ${snapshot.error}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  );
                }

                final List<InventoryCategory> categories =
                    snapshot.data ?? const <InventoryCategory>[];
                if (categories.isEmpty) {
                  return Text(
                    'لا توجد تصنيفات بعد',
                    style: theme.textTheme.bodySmall,
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 42,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 64,
                    columnSpacing: 40,
                    columns: <DataColumn>[
                      const DataColumn(label: Text('التصنيف')),
                      const DataColumn(label: Text('الوصف')),
                      const DataColumn(
                        label: Text('عدد المنتجات'),
                        numeric: true,
                      ),
                      if (canEdit || canDelete)
                        const DataColumn(label: Text('إجراءات')),
                    ],
                    rows: categories.map((InventoryCategory category) {
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(
                            Text(
                              category.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              category.description ?? '—',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          DataCell(
                            Text(
                              category.productCount.toString(),
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
                                      tooltip: 'تعديل',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 19,
                                      ),
                                      onPressed: () => _openEdit(category),
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
                                      onPressed: () => _confirmDelete(category),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
        ),
      ),
    );
  }

  Future<void> _openCreate() async {
    final bool saved =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => const CategoryFormDialog(),
        ) ??
        false;
    if (saved && mounted) {
      _reload();
      showAppMessage(context, 'تمت إضافة التصنيف');
    }
  }

  Future<void> _openEdit(InventoryCategory category) async {
    final bool saved =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) =>
              CategoryFormDialog(existing: category),
        ) ??
        false;
    if (saved && mounted) {
      _reload();
      showAppMessage(context, 'تم تحديث التصنيف');
    }
  }

  Future<void> _confirmDelete(InventoryCategory category) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('حذف التصنيف'),
        content: Text(
          'سيتم حذف تصنيف «${category.name}» من قاعدة البيانات. لا يمكن التراجع.',
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
      await context.read<AppDatabase>().deleteCategory(category.id);
      if (!mounted) return;
      _reload();
      showAppMessage(context, 'تم حذف التصنيف');
    } on AppRuleException catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.message, error: true);
    }
  }
}

class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({super.key, this.existing});

  final InventoryCategory? existing;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'تعديل التصنيف' : 'إضافة تصنيف'),
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
                  labelText: 'اسم التصنيف',
                  hintText: 'مثال: مشروبات',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  hintText: 'اختياري',
                ),
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
        await database.updateCategory(
          widget.existing!.id,
          name: _nameController.text,
          description: _descriptionController.text,
        );
      } else {
        await database.createCategory(
          name: _nameController.text,
          description: _descriptionController.text,
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
