import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/export_csv.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_scaffold.dart';
import '../../core/widgets/section_card.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<Map<String, dynamic>> _stats;

  @override
  void initState() {
    super.initState();
    _stats = _loadStats();
  }

  Future<Map<String, dynamic>> _loadStats() async {
    final AppDatabase db = context.read<AppDatabase>();
    final Database _db = (db as dynamic)._db as Database;
    final List<Map<String, Object?>> sales = await _db.rawQuery(
      'SELECT COUNT(*) AS c, SUM(subtotal) AS s FROM sales_invoices WHERE status = ?',
      <Object?>['completed'],
    );
    final List<Map<String, Object?>> purchases = await _db.rawQuery(
      'SELECT COUNT(*) AS c, SUM(subtotal) AS s FROM purchases WHERE status = ?',
      <Object?>['completed'],
    );
    final List<Map<String, Object?>> products = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM products WHERE is_active = 1',
    );
    final List<Map<String, Object?>> lowStock = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM products WHERE stock <= min_stock AND is_active = 1',
    );
    return <String, dynamic>{
      'salesCount': (sales.first['c'] as int?) ?? 0,
      'salesSubtotal': ((sales.first['s'] as num?) ?? 0).toDouble(),
      'purchaseCount': (purchases.first['c'] as int?) ?? 0,
      'purchaseSubtotal': ((purchases.first['s'] as num?) ?? 0).toDouble(),
      'productCount': (products.first['c'] as int?) ?? 0,
      'lowStockCount': (lowStock.first['c'] as int?) ?? 0,
    };
  }

  void _refresh() {
    setState(() {
      _stats = _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppPageScaffold(
      title: 'التقارير',
      subtitle: 'إحصائيات حقيقية من قاعدة البيانات المحلية',
      actions: <Widget>[
        OutlinedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('تحديث'),
        ),
        FilledButton.icon(
          onPressed: () {
            exportCsv('reports.csv', <List<String>>[
              <String>['نوع', 'عدد', 'إجمالي'],
              <String>['مبيعات', '0', '0'],
              <String>['مشتريات', '0', '0'],
            ]);
          },
          icon: const Icon(Icons.download, size: 18),
          label: const Text('تصدير'),
        ),
      ],
      child: FutureBuilder<Map<String, dynamic>>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          final Map<String, dynamic> data = snapshot.data ?? {};
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionCard(
                  title: 'إحصائيات المبيعات',
                  child: Row(
                    children: <Widget>[
                      _kpi(theme, 'عدد الفواتير', '${data['salesCount']}'),
                      _kpi(
                        theme,
                        'إجمالي المبيعات',
                        '${data['salesSubtotal'].toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'إحصائيات المشتريات',
                  child: Row(
                    children: <Widget>[
                      _kpi(theme, 'عدد الأوامر', '${data['purchaseCount']}'),
                      _kpi(
                        theme,
                        'إجمالي المشتريات',
                        '${data['purchaseSubtotal'].toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'المخزون',
                  child: Row(
                    children: <Widget>[
                      _kpi(theme, 'المنتجات النشطة', '${data['productCount']}'),
                      _kpi(
                        theme,
                        'منخفض المخزون',
                        '${data['lowStockCount']}',
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kpi(ThemeData theme, String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color ?? theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
