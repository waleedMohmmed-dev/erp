import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/inventory/inventory_models.dart';
import '../../core/widgets/section_card.dart';
import '../../routing/app_routes.dart';
import '../permissions/permission_checks.dart';
import 'inventory_common.dart';

class UnitsTab extends StatefulWidget {
  const UnitsTab({super.key});

  @override
  State<UnitsTab> createState() => _UnitsTabState();
}

class _UnitsTabState extends State<UnitsTab> {
  late Future<List<InventoryUnit>> _units;

  @override
  void initState() {
    super.initState();
    _units = context.read<AppDatabase>().listUnits();
  }

  void _reload() {
    setState(() {
      _units = context.read<AppDatabase>().listUnits();
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
        title: 'وحدات القياس',
        subtitle: 'الوحدات المستخدمة في تعريف المنتجات والكميات',
        actions: <Widget>[
          if (canCreate)
            FilledButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة وحدة'),
            ),
        ],
        child: FutureBuilder<List<InventoryUnit>>(
          future: _units,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<InventoryUnit>> snapshot,
              ) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Text(
                    'جارٍ تحميل الوحدات…',
                    style: theme.textTheme.bodySmall,
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'تعذر قراءة الوحدات: ${snapshot.error}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  );
                }

                final List<InventoryUnit> units =
                    snapshot.data ?? const <InventoryUnit>[];
                if (units.isEmpty) {
                  return Text(
                    'لا توجد وحدات بعد',
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
                      const DataColumn(label: Text('الوحدة')),
                      const DataColumn(
                        label: Text('عدد المنتجات'),
                        numeric: true,
                      ),
                      if (canEdit || canDelete)
                        const DataColumn(label: Text('إجراءات')),
                    ],
                    rows: units.map((InventoryUnit unit) {
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(
                            Text(
                              unit.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              unit.productCount.toString(),
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
                                      onPressed: () => _openEdit(unit),
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
                                      onPressed: () => _confirmDelete(unit),
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
          builder: (BuildContext context) => const UnitFormDialog(),
        ) ??
        false;
    if (saved && mounted) {
      _reload();
      showAppMessage(context, 'تمت إضافة الوحدة');
    }
  }

  Future<void> _openEdit(InventoryUnit unit) async {
    final bool saved =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => UnitFormDialog(existing: unit),
        ) ??
        false;
    if (saved && mounted) {
      _reload();
      showAppMessage(context, 'تم تحديث الوحدة');
    }
  }

  Future<void> _confirmDelete(InventoryUnit unit) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('حذف الوحدة'),
        content: Text(
          'سيتم حذف وحدة «${unit.name}» من قاعدة البيانات. لا يمكن التراجع.',
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
      await context.read<AppDatabase>().deleteUnit(unit.id);
      if (!mounted) return;
      _reload();
      showAppMessage(context, 'تم حذف الوحدة');
    } on AppRuleException catch (error) {
      if (!mounted) return;
      showAppMessage(context, error.message, error: true);
    }
  }
}

class UnitFormDialog extends StatefulWidget {
  const UnitFormDialog({super.key, this.existing});

  final InventoryUnit? existing;

  @override
  State<UnitFormDialog> createState() => _UnitFormDialogState();
}

class _UnitFormDialogState extends State<UnitFormDialog> {
  late final TextEditingController _nameController;

  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'تعديل الوحدة' : 'إضافة وحدة'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'اسم الوحدة',
                hintText: 'مثال: كيلوجرام',
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
        await database.updateUnit(widget.existing!.id, _nameController.text);
      } else {
        await database.createUnit(_nameController.text);
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
