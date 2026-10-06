import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_erp/core/database/app_database.dart';

import '../../core/database/app_database.dart';
import '../../core/purchases/purchase_models.dart';
import '../../core/theme/app_theme.dart';

class SuppliersTab extends StatefulWidget {
  const SuppliersTab({super.key});

  @override
  State<SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<SuppliersTab> {
  late Future<List<Supplier>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppDatabase>().listSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Supplier>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        final suppliers = snapshot.data ?? [];
        return ListView.builder(
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            final s = suppliers[index];
            return ListTile(
              title: Text(s.name),
              subtitle: Text(s.phone ?? 'بدون هاتف'),
              trailing: Chip(
                label: Text(s.isActive ? 'نشط' : 'غير نشط'),
                backgroundColor: s.isActive
                    ? AppColors.success
                    : AppColors.warning,
              ),
            );
          },
        );
      },
    );
  }
}
