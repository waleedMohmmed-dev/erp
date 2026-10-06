import 'package:flutter/material.dart';

import '../../core/widgets/app_page_scaffold.dart';
import 'customers_tab.dart';
import 'invoices_tab.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'المبيعات',
      subtitle: 'العملاء والفواتير والمخزون الصادر',
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const TabBar(
              isScrollable: true,
              tabs: <Widget>[
                Tab(
                  text: 'الفواتير',
                  icon: Icon(Icons.receipt_long_outlined, size: 20),
                ),
                Tab(
                  text: 'العملاء',
                  icon: Icon(Icons.people_outline, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 600,
              child: TabBarView(
                children: <Widget>[InvoicesTab(), CustomersTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
