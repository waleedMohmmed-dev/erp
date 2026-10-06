import 'package:flutter/material.dart';

import 'app_page_scaffold.dart';
import 'section_card.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppPageScaffold(
      title: 'الصفحة غير موجودة',
      subtitle: 'هذا الرابط لا يطابق أي شاشة في مساحة العمل',
      child: SectionCard(
        title: 'مسار غير معروف',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.explore_off_outlined,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'تحقق من القائمة الجانبية، أو ارجع إلى لوحة التحكم.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (onBack != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: const Text('فتح لوحة التحكم'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
