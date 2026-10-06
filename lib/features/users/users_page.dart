import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_user.dart';
import '../../core/auth/user_role.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_scaffold.dart';
import '../../core/widgets/section_card.dart';
import '../../routing/app_routes.dart';
import '../auth/session_controller.dart';
import '../permissions/permission_checks.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<List<AuthUser>> _users;

  @override
  void initState() {
    super.initState();
    _users = context.read<AppDatabase>().listUsers();
  }

  void _refresh() {
    setState(() {
      _users = context.read<AppDatabase>().listUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canCreate = context.canCreate(AppRoutes.users);
    final bool canEdit = context.canEdit(AppRoutes.users);
    final bool canDelete = context.canDelete(AppRoutes.users);

    return AppPageScaffold(
      title: 'المستخدمون',
      subtitle: 'حسابات الدخول المحلية: الاسم والبريد والدور وحالة الحساب',
      actions: <Widget>[
        if (canCreate)
          FilledButton.icon(
            onPressed: _openCreate,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('إضافة مستخدم'),
          ),
      ],
      child: SectionCard(
        title: 'حسابات النظام',
        subtitle: 'كل حساب له دور يحدد ما يمكنه الوصول إليه داخل النظام',
        child: FutureBuilder<List<AuthUser>>(
          future: _users,
          builder:
              (BuildContext context, AsyncSnapshot<List<AuthUser>> snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Text(
                    'جارٍ تحميل المستخدمين…',
                    style: theme.textTheme.bodySmall,
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'تعذر قراءة المستخدمين: ${snapshot.error}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  );
                }

                final List<AuthUser> users = snapshot.data ?? <AuthUser>[];
                if (users.isEmpty) {
                  return Text(
                    'لا توجد حسابات بعد',
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
                      const DataColumn(label: Text('المستخدم')),
                      const DataColumn(label: Text('الدور')),
                      const DataColumn(label: Text('الحالة')),
                      const DataColumn(label: Text('آخر دخول')),
                      if (canEdit || canDelete)
                        const DataColumn(label: Text('إجراءات')),
                    ],
                    rows: users.map((AuthUser user) {
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  user.fullName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  user.email,
                                  textDirection: TextDirection.ltr,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          DataCell(_RoleBadge(role: user.role)),
                          DataCell(_StatusBadge(active: user.isActive)),
                          DataCell(
                            Text(
                              user.lastLoginAt == null
                                  ? 'لم يسجّل الدخول'
                                  : _formatTimestamp(user.lastLoginAt!),
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
                                      onPressed: () => _openEdit(user),
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
                                      onPressed: () => _confirmDelete(user),
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
          builder: (BuildContext context) => const UserFormDialog(),
        ) ??
        false;
    if (saved && mounted) {
      _refresh();
      _showMessage('تمت إضافة المستخدم');
    }
  }

  Future<void> _openEdit(AuthUser user) async {
    final bool saved =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => UserFormDialog(existing: user),
        ) ??
        false;
    if (saved && mounted) {
      _refresh();
      _showMessage('تم تحديث بيانات المستخدم');
    }
  }

  Future<void> _confirmDelete(AuthUser user) async {
    final AuthUser? me = context.read<SessionController>().user;
    if (me != null && me.id == user.id) {
      _showMessage('لا يمكنك حذف حسابك الحالي', error: true);
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content: Text(
          'سيتم حذف حساب «${user.fullName}» وإلغاء جلساته المفتوحة. لا يمكن التراجع.',
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
      await context.read<AppDatabase>().deleteUser(user.id);
      if (!mounted) return;
      _refresh();
      _showMessage('تم حذف المستخدم');
    } on AppRuleException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, error: true);
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

  static String _formatTimestamp(String raw) {
    final DateTime? parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) {
      return raw;
    }
    String two(int value) => value.toString().padLeft(2, '0');
    return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }
}

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key, this.existing});

  final AuthUser? existing;

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late UserRole _role;
  late bool _active;

  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existing?.fullName ?? '',
    );
    _emailController = TextEditingController(
      text: widget.existing?.email ?? '',
    );
    _passwordController = TextEditingController();
    _role = widget.existing?.role ?? UserRole.sales;
    _active = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEdit ? 'تعديل المستخدم' : 'إضافة مستخدم'),
      content: SizedBox(
        width: 470,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  hintText: 'مثال: أحمد محمد',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  hintText: 'name@company.com',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isEdit ? 'كلمة المرور الجديدة' : 'كلمة المرور',
                  hintText: _isEdit
                      ? 'اتركه فارغاً للإبقاء على كلمة المرور الحالية'
                      : '6 أحرف على الأقل',
                ),
              ),
              const SizedBox(height: 18),
              Text('الدور', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: UserRole.values.map((UserRole role) {
                  return ChoiceChip(
                    label: Text(role.label),
                    avatar: role == UserRole.admin
                        ? const Icon(Icons.lock_outline, size: 15)
                        : null,
                    selected: _role == role,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _role = role);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('حساب نشط'),
                subtitle: Text(
                  _active
                      ? 'يستطيع الدخول إلى النظام'
                      : 'ممنوع من الدخول حتى يُفعَّل مجدداً',
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

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final AppDatabase database = context.read<AppDatabase>();
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    try {
      if (_isEdit) {
        await database.updateUser(
          id: widget.existing!.id,
          email: email,
          fullName: name,
          role: _role,
          isActive: _active,
          password: password.isEmpty ? null : password,
        );
      } else {
        await database.createUser(
          email: email,
          password: password,
          fullName: name,
          role: _role,
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

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(role.icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            role.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = active ? AppColors.success : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            active ? Icons.check_circle : Icons.block,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'نشط' : 'معطل',
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
