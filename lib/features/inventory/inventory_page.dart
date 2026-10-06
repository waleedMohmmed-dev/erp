import 'package:flutter/material.dart';

import '../../core/widgets/app_page_scaffold.dart';
import 'categories_tab.dart';
import 'movements_tab.dart';
import 'products_tab.dart';
import 'units_tab.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'المخزون',
      subtitle: 'المنتجات والتصنيفات والوحدات وحركات المخزون',
      child: DefaultTabController(
        length: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const TabBar(
              isScrollable: true,
              tabs: <Widget>[
                Tab(
                  text: 'المنتجات',
                  icon: Icon(Icons.inventory_2_outlined, size: 20),
                ),
                Tab(
                  text: 'التصنيفات',
                  icon: Icon(Icons.category_outlined, size: 20),
                ),
                Tab(
                  text: 'الوحدات',
                  icon: Icon(Icons.straighten_outlined, size: 20),
                ),
                Tab(
                  text: 'حركات المخزون',
                  icon: Icon(Icons.swap_vert_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 600,
              child: TabBarView(
                children: <Widget>[
                  ProductsTab(),
                  CategoriesTab(),
                  UnitsTab(),
                  MovementsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
