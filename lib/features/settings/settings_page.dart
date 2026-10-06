import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/auth/permission_action.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/app_page_scaffold.dart';
import '../../core/widgets/section_card.dart';
import '../../routing/app_routes.dart';
import '../permissions/permission_checks.dart';
import 'settings_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _companyNameController;
  late final TextEditingController _currencyController;
  late Future<DatabaseOverview> _overview;

  String? _companyNameError;
  String? _currencyError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final SettingsController settings = context.read<SettingsController>();
    _companyNameController = TextEditingController(text: settings.companyName);
    _currencyController = TextEditingController(text: settings.currency);
    _overview = context.read<AppDatabase>().overview();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = context.canDo(
      AppRoutes.settings,
      PermissionAction.edit,
    );

    return AppPageScaffold(
      title: 'الإعدادات',
      subtitle: 'المظهر وملف الشركة وقاعدة البيانات المحلية',
      actions: <Widget>[
        FilledButton.icon(
          onPressed: canEdit && !_saving ? _save : null,
          icon: Icon(_saving ? Icons.hourglass_top : Icons.save, size: 18),
          label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!canEdit) ...<Widget>[
            _ReadOnlyNotice(),
            const SizedBox(height: 14),
          ],
          _buildAppearance(canEdit: canEdit),
          const SizedBox(height: 18),
          _buildProfile(canEdit: canEdit),
          const SizedBox(height: 18),
          _buildDatabase(),
          const SizedBox(height: 18),
          _buildAbout(),
        ],
      ),
    );
  }

  Widget _buildAppearance({required bool canEdit}) {
    final SettingsController settings = context.watch<SettingsController>();

    return SectionCard(
      title: 'المظهر',
      subtitle: 'يتم حفظ الوضع المختار في المتصفح',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto, size: 18),
                label: Text('النظام'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode, size: 18),
                label: Text('فاتح'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode, size: 18),
                label: Text('داكن'),
              ),
            ],
            selected: <ThemeMode>{settings.themeMode},
            onSelectionChanged: canEdit
                ? (Set<ThemeMode> selection) =>
                      settings.setThemeMode(selection.first)
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            'الوضع الحالي: ${_themeLabel(settings.themeMode)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildProfile({required bool canEdit}) {
    final ThemeData theme = Theme.of(context);

    return SectionCard(
      title: 'ملف الشركة',
      subtitle: 'يُحفظ في جدول app_settings بقاعدة البيانات المحلية',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget nameField = TextField(
                controller: _companyNameController,
                readOnly: !canEdit,
                decoration: const InputDecoration(
                  labelText: 'اسم الشركة',
                  hintText: 'مثال: شركتي',
                ),
                onChanged: (_) {
                  if (_companyNameError != null) {
                    setState(() => _companyNameError = null);
                  }
                },
              );

              final Widget currencyField = TextField(
                controller: _currencyController,
                readOnly: !canEdit,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'العملة',
                  hintText: 'USD',
                  counterText: '',
                  errorText: _currencyError,
                ),
                onChanged: (_) {
                  if (_currencyError != null) {
                    setState(() => _currencyError = null);
                  }
                },
              );

              if (constraints.maxWidth < 620) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 340, child: nameField),
                    SizedBox(width: 200, child: currencyField),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 3, child: nameField),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: currencyField),
                ],
              );
            },
          ),
          if (_companyNameError != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _companyNameError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'يُستخدم كترويسة افتراضية للمستندات والتقارير القادمة.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDatabase() {
    final ThemeData theme = Theme.of(context);

    return SectionCard(
      title: 'قاعدة البيانات المحلية',
      subtitle: 'SQLite يعمل داخل المتصفح ويبقى بعد التحديث',
      actions: <Widget>[
        OutlinedButton.icon(
          onPressed: _refreshOverview,
          icon: const Icon(Icons.health_and_safety_outlined, size: 18),
          label: const Text('فحص السلامة'),
        ),
      ],
      child: FutureBuilder<DatabaseOverview>(
        future: _overview,
        builder:
            (BuildContext context, AsyncSnapshot<DatabaseOverview> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Text(
                  'جارٍ قراءة قاعدة البيانات…',
                  style: theme.textTheme.bodySmall,
                );
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'خطأ في قاعدة البيانات: ${snapshot.error}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _refreshOverview,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                );
              }

              final DatabaseOverview overview = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _infoRow(theme, 'الملف', overview.fileName),
                  _infoRow(theme, 'إصدار المخطط', 'v${overview.schemaVersion}'),
                  _infoRow(
                    theme,
                    'السلامة',
                    overview.isHealthy
                        ? 'سليم'
                        : overview.integrity.toUpperCase(),
                  ),
                  _infoRow(
                    theme,
                    'الجداول / السجلات',
                    '${overview.tables.length} / ${overview.totalRows}',
                    ltr: true,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: overview.tables
                        .map(
                          (TableStat table) => Chip(
                            label: Text('${table.name} · ${table.rows}'),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              );
            },
      ),
    );
  }

  Widget _buildAbout() {
    final ThemeData theme = Theme.of(context);

    return SectionCard(
      title: 'حول التطبيق',
      child: Column(
        children: <Widget>[
          _infoRow(theme, 'التطبيق', '${AppInfo.name} v${AppInfo.version}'),
          _infoRow(theme, 'التخزين', AppInfo.storage),
          _infoRow(
            theme,
            'الخلفية',
            'لا يوجد في هذه المرحلة · بيانات محلية فقط',
          ),
          _infoRow(
            theme,
            'الاستمرارية',
            'تبقى البيانات بعد تحديث المتصفح',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    ThemeData theme,
    String label,
    String value, {
    bool isLast = false,
    bool ltr = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color:
                      theme.dividerTheme.color ??
                      theme.colorScheme.outlineVariant,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              textAlign: ltr ? TextAlign.left : TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _refreshOverview() {
    setState(() {
      _overview = context.read<AppDatabase>().overview();
    });
  }

  Future<void> _save() async {
    final String name = _companyNameController.text.trim();
    final String currency = _currencyController.text.trim();

    final String? nameError = name.isEmpty ? 'اسم الشركة مطلوب' : null;
    final String? currencyError = currency.isEmpty
        ? 'العملة مطلوبة'
        : currency.length > 6
        ? 'بحد أقصى 6 أحرف'
        : null;

    setState(() {
      _companyNameError = nameError;
      _currencyError = currencyError;
    });

    if (nameError != null || currencyError != null) {
      return;
    }

    setState(() => _saving = true);

    try {
      await context.read<SettingsController>().setCompanyProfile(
        name: name,
        currencyCode: currency,
      );
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      _showMessage('تم حفظ الإعدادات في قاعدة البيانات المحلية');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      final String message = error is ArgumentError
          ? '${error.message ?? 'قيمة غير صالحة'}'
          : 'تعذر حفظ الإعدادات: $error';
      _showMessage(message, isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final ThemeData theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: isError
                  ? theme.colorScheme.onError
                  : theme.colorScheme.onInverseSurface,
            ),
          ),
          backgroundColor: isError ? theme.colorScheme.error : null,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'النظام';
      case ThemeMode.light:
        return 'فاتح';
      case ThemeMode.dark:
        return 'داكن';
    }
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.dividerTheme.color ?? theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.lock_outline, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'للقراءة فقط: دورك الحالي لا يملك صلاحية «تعديل» في صفحة الإعدادات.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
