import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_scaffold.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/section_card.dart';
import '../settings/settings_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DatabaseOverview> _overview;

  @override
  void initState() {
    super.initState();
    _overview = context.read<AppDatabase>().overview();
  }

  void _refresh() {
    setState(() {
      _overview = context.read<AppDatabase>().overview();
    });
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();

    return AppPageScaffold(
      title: 'لوحة التحكم',
      subtitle: 'حالة مساحة العمل المقروءة من قاعدة البيانات المحلية',
      actions: <Widget>[
        OutlinedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('تحديث'),
        ),
      ],
      child: FutureBuilder<DatabaseOverview>(
        future: _overview,
        builder:
            (BuildContext context, AsyncSnapshot<DatabaseOverview> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _LoadingState();
              }
              if (snapshot.hasError) {
                return _ErrorState(error: snapshot.error!, onRetry: _refresh);
              }

              final DatabaseOverview overview = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildKpis(context, overview, settings),
                  const SizedBox(height: 18),
                  _buildOverviewRow(context, overview),
                  const SizedBox(height: 18),
                  _buildTables(context, overview),
                ],
              );
            },
      ),
    );
  }

  Widget _buildKpis(
    BuildContext context,
    DatabaseOverview overview,
    SettingsController settings,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 18;
        final double cardWidth = ((constraints.maxWidth - gap * 3) / 4)
            .clamp(220.0, 320.0)
            .toDouble();

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            SizedBox(
              width: cardWidth,
              child: KpiCard(
                label: 'مخطط القاعدة',
                value: 'v${overview.schemaVersion}',
                caption: 'مستوى ترحيل قاعدة البيانات',
                icon: Icons.storage,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: KpiCard(
                label: 'الجداول',
                value: '${overview.tables.length}',
                caption: 'الجداول المنشأة في SQLite المحلي',
                icon: Icons.table_chart,
                accent: Theme.of(context).colorScheme.secondary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: KpiCard(
                label: 'السجلات',
                value: '${overview.totalRows}',
                caption: 'إجمالي السجلات المخزنة',
                icon: Icons.list_alt,
                accent: AppColors.warning,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: KpiCard(
                label: 'الشركة',
                value: settings.companyName,
                caption: '${settings.currency} · ملف محلي',
                icon: Icons.business,
                accent: AppColors.success,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewRow(BuildContext context, DatabaseOverview overview) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget databaseCard = _DatabaseCard(overview: overview);
        final Widget roadmapCard = const _RoadmapCard();

        if (constraints.maxWidth < 940) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              databaseCard,
              const SizedBox(height: 18),
              roadmapCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: databaseCard),
            const SizedBox(width: 18),
            Expanded(child: roadmapCard),
          ],
        );
      },
    );
  }

  Widget _buildTables(BuildContext context, DatabaseOverview overview) {
    final ThemeData theme = Theme.of(context);

    if (overview.tables.isEmpty) {
      return const SectionCard(
        title: 'جداول قاعدة البيانات',
        subtitle: 'لم يتم إنشاء أي جداول مستخدم بعد',
        child: Text('سيتوسع المخطط مع كل مرحلة منفَّذة.'),
      );
    }

    return SectionCard(
      title: 'جداول قاعدة البيانات',
      subtitle:
          '${overview.tables.length} جدول · ${overview.totalRows} سجل مخزن محلياً',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 42,
          dataRowMaxHeight: 48,
          columnSpacing: 56,
          columns: const <DataColumn>[
            DataColumn(label: Text('الجدول')),
            DataColumn(label: Text('التخزين'), numeric: false),
            DataColumn(label: Text('السجلات'), numeric: true),
          ],
          rows: overview.tables
              .map(
                (TableStat table) => DataRow(
                  cells: <DataCell>[
                    DataCell(
                      Text(table.name, style: theme.textTheme.bodyMedium),
                    ),
                    DataCell(
                      Text(AppInfo.storage, style: theme.textTheme.bodySmall),
                    ),
                    DataCell(
                      Text(
                        '${table.rows}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _DatabaseCard extends StatelessWidget {
  const _DatabaseCard({required this.overview});

  final DatabaseOverview overview;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'قاعدة البيانات المحلية',
      subtitle: 'مساحة التخزين بالمتصفح لهذه المساحة',
      child: Column(
        children: <Widget>[
          _InfoRow(label: 'الملف', value: overview.fileName),
          _InfoRow(label: 'التخزين', value: AppInfo.storage),
          _InfoRow(label: 'إصدار المخطط', value: 'v${overview.schemaVersion}'),
          _InfoRow(
            label: 'فحص السلامة',
            value: overview.isHealthy ? 'سليم' : overview.integrity,
            trailing: _StatusBadge(healthy: overview.isHealthy),
          ),
          _InfoRow(
            label: 'الجداول / السجلات',
            value: '${overview.tables.length} / ${overview.totalRows}',
            ltrValue: true,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.trailing,
    this.isLast = false,
    this.ltrValue = false,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final bool isLast;
  final bool ltrValue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
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
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: ltrValue ? TextDirection.ltr : null,
              textAlign: ltrValue ? TextAlign.left : TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.healthy});

  final bool healthy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = healthy ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            healthy ? Icons.check_circle : Icons.error,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            healthy ? 'سليم' : 'فشل',
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

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard();

  static const List<_Phase> _phases = <_Phase>[
    _Phase('0', 'الأساس', _PhaseStatus.done),
    _Phase('1', 'المصادقة', _PhaseStatus.done),
    _Phase('2', 'الأدوار والصلاحيات', _PhaseStatus.done),
    _Phase('3', 'المخزون', _PhaseStatus.done),
    _Phase('4', 'المبيعات', _PhaseStatus.done),
    _Phase('5', 'المشتريات', _PhaseStatus.next),
    _Phase('6', 'لوحة التحكم والتقارير', _PhaseStatus.planned),
    _Phase('7', 'التحسينات والذكاء الاصطناعي', _PhaseStatus.planned),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SectionCard(
      title: 'خارطة طريق المشروع',
      subtitle: 'المراحل المكتملة فقط متاحة في القائمة',
      child: Column(
        children: _phases.asMap().entries.map((MapEntry<int, _Phase> entry) {
          final _Phase phase = entry.value;
          final bool isLast = entry.key == _phases.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
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
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    phase.number,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    phase.title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: phase.status == _PhaseStatus.done
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _PhaseBadge(status: phase.status),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

enum _PhaseStatus { done, next, planned }

class _Phase {
  const _Phase(this.number, this.title, this.status);

  final String number;
  final String title;
  final _PhaseStatus status;
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.status});

  final _PhaseStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final (String label, Color color, IconData icon) = switch (status) {
      _PhaseStatus.done => ('مكتمل', AppColors.success, Icons.check_circle),
      _PhaseStatus.next => ('التالي', AppColors.brand, Icons.arrow_back),
      _PhaseStatus.planned => (
        'مخطط',
        theme.colorScheme.outline,
        Icons.schedule,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: List<Widget>.generate(
            4,
            (int index) => Expanded(
              child: Container(
                height: 116,
                margin: EdgeInsetsDirectional.only(end: index == 3 ? 0 : 18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: <Widget>[
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 14),
              Text(
                'جارٍ قراءة قاعدة البيانات…',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SectionCard(
      title: 'تعذر الوصول إلى قاعدة البيانات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$error', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
