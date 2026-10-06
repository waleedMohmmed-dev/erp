import 'package:flutter/material.dart';

import '../../core/widgets/app_page_scaffold.dart';
import 'suppliers_tab.dart';
import 'orders_tab.dart';

class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'المشتريات',
      subtitle: 'الموردون وأوامر الشراء والمخزون الوارد',
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const TabBar(
              isScrollable: true,
              tabs: <Widget>[
                Tab(
                  text: 'أوامر الشراء',
                  icon: Icon(Icons.shopping_cart_outlined, size: 20),
                ),
                Tab(
                  text: 'الموردون',
                  icon: Icon(Icons.store_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 600,
              child: TabBarView(
                children: <Widget>[OrdersTab(), SuppliersTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
