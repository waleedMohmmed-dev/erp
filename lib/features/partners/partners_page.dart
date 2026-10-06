import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_page_scaffold.dart';
import '../../core/widgets/feature_placeholder.dart';
import '../../routing/app_router.dart';
import '../../routing/app_routes.dart';

class PartnersPage extends StatelessWidget {
  const PartnersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الشركاء',
      subtitle: 'دليل العملاء والموردين',
      child: FeaturePlaceholder(
        phase: 'المرحلتان 4 و 5 · الشركاء',
        description: 'تُشارك سجلات الشركاء بين وحدتي المبيعات والمشتريات.',
        highlights: const <String>[
          'سجلات العملاء',
          'سجلات الموردين',
          'بيانات الاتصال والعناوين',
          'المستندات المرتبطة لكل شريك',
        ],
        onBack: () => context.read<AppRouterDelegate>().go(AppRoutes.dashboard),
      ),
    );
  }
}
