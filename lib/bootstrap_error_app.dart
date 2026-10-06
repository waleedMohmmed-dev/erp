import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_info.dart';
import 'core/theme/app_theme.dart';

class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({super.key, required this.error, this.onRetry});

  final Object error;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = AppTheme.light();

    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme,
      home: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.error_outline,
                    size: 52,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'تعذّرت بدء مساحة العمل',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'تعذر فتح قاعدة البيانات المحلية. '
                    'تأكد من وجود الملفين sqlite3.wasm و sqflite_sw.js داخل مجلد web.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (onRetry != null) ...<Widget>[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
