import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/permission_action.dart';
import '../../core/auth/permission_defaults.dart';
import '../../core/auth/user_role.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_scaffold.dart';
import '../../core/widgets/section_card.dart';
import '../../routing/app_routes.dart';
import 'permission_checks.dart';
import 'permissions_controller.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  UserRole _role = UserRole.manager;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PermissionsController permissions = context.permissions;
    final bool isAdmin = context.isAdmin;
    final String roleId = _role.id;
    final bool lockedRole = _role == UserRole.admin;

    return AppPageScaffold(
      title: 'الصلاحيات',
      subtitle:
          'حدد لكل دور ما يمكنه تنفيذه في كل صفحة: عرض، إضافة، تعديل، حذف',
      actions: <Widget>[
        if (isAdmin)
          OutlinedButton.icon(
            onPressed: _busy ? null : _resetToDefaults,
            icon: const Icon(Icons.settings_backup_restore, size: 18),
            label: const Text('استعادة الافتراضي'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionCard(
            title: 'الدور',
            subtitle: 'اختر الدور لعرض صلاحياته وتعديلها',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: UserRole.values.map((UserRole role) {
                return ChoiceChip(
                  avatar: role == UserRole.admin
                      ? const Icon(Icons.lock_outline, size: 15)
                      : null,
                  label: Text(role.label),
                  selected: _role == role,
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() => _role = role);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'جدول الإجراءات',
            subtitle: !isAdmin
                ? 'للقراءة فقط — تعديل الصلاحيات متاح لمدير النظام'
                : lockedRole
                ? 'صلاحية مدير النظام ثابتة ولا يمكن تقييدها'
                : 'التغييرات تُحفظ تلقائياً في قاعدة البيانات المحلية',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columnSpacing: 34,
                columns: <DataColumn>[
                  const DataColumn(label: Text('الصفحة')),
                  ...PermissionAction.values.map(
                    (PermissionAction action) => DataColumn(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(action.icon, size: 16),
                          const SizedBox(width: 6),
                          Text(action.label),
                        ],
                      ),
                    ),
                  ),
                ],
                rows: PermissionDefaults.resources.map((String resource) {
                  final NavDestination destination = destinationFor(resource);
                  return DataRow(
                    cells: <DataCell>[
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              destination.icon,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(destination.label),
                          ],
                        ),
                      ),
                      ...PermissionAction.values.map((PermissionAction action) {
                        final bool allowed = permissions.can(
                          roleId,
                          resource,
                          action,
                        );
                        final bool editable = isAdmin && !lockedRole && !_busy;

                        return DataCell(
                          Checkbox(
                            key: ValueKey<String>(
                              'perm|$resource|${action.id}',
                            ),
                            value: allowed,
                            onChanged: editable
                                ? (bool? value) =>
                                      _toggle(resource, action, value ?? false)
                                : null,
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'الصفحات التي يملك الدور «عرض» فيها فقط تظهر له في القائمة الجانبية، '
            'والصفحة تُفتح للقراءة فقط إذا لم يكن لديه «تعديل».',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
    String resource,
    PermissionAction action,
    bool allowed,
  ) async {
    if (_busy) {
      return;
    }

    final PermissionsController permissions = context
        .read<PermissionsController>();
    final String roleId = _role.id;

    setState(() => _busy = true);
    try {
      await permissions.set(
        role: roleId,
        resource: resource,
        action: action,
        allowed: allowed,
      );
      if (!mounted) return;

      final bool stillViewable = permissions.can(
        roleId,
        resource,
        PermissionAction.view,
      );
      if (action == PermissionAction.view && !allowed && stillViewable) {
        _showMessage(
          'لا يمكن إلغاء «عرض» ما دام أي إجراء آخر مسموح في هذه الصفحة',
          error: true,
        );
      }
    } on AppRuleException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, error: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('استعادة الصلاحيات الافتراضية'),
        content: const Text(
          'سيتم إرجاع جدول الصلاحيات إلى الإعدادات الأصلية لكل الأدوار. هل تريد المتابعة؟',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await context.read<PermissionsController>().resetToDefaults();
      if (mounted) {
        _showMessage('تمت استعادة الصلاحيات الافتراضية');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
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
}
