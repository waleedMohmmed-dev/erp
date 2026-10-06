import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/session_controller.dart';
import 'app_page_scaffold.dart';
import 'section_card.dart';

class NoAccessPage extends StatelessWidget {
  const NoAccessPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = context.watch<SessionController>();
    final String role = session.user?.role.label ?? 'غير معروف';

    return AppPageScaffold(
      title: 'ليس لديك صلاحية',
      subtitle: 'هذه الصفحة غير متاحة ضمن صلاحيات دورك الحالي',
      child: SectionCard(
        title: 'الوصول مرفوض',
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
                    Icons.lock_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'دورك الحالي: $role. تواصل مع مدير النظام لطلب صلاحية '
                    'الوصول إلى هذه الصفحة.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.dashboard_outlined, size: 18),
              label: const Text('فتح لوحة التحكم'),
            ),
          ],
        ),
      ),
    );
  }
}
