import 'package:flutter/material.dart';

abstract final class AppRoutes {
  static const String dashboard = '/';
  static const String login = '/login';
  static const String inventory = '/inventory';
  static const String sales = '/sales';
  static const String purchases = '/purchases';
  static const String partners = '/partners';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String users = '/users';
  static const String permissions = '/permissions';

  static const List<String> all = <String>[
    dashboard,
    login,
    inventory,
    sales,
    purchases,
    partners,
    reports,
    settings,
    users,
    permissions,
  ];

  static bool isKnown(String path) => all.contains(path);

  static String normalize(String location) {
    String path = location.trim();
    if (path.isEmpty) {
      return dashboard;
    }
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  static String fromUri(Uri uri) {
    final String fragment = uri.fragment;
    if (fragment.startsWith('/')) {
      return normalize(fragment);
    }
    if (uri.path.isEmpty) {
      return dashboard;
    }
    return normalize(uri.path);
  }
}

enum NavSection { overview, operations, insights, management }

extension NavSectionTitle on NavSection {
  String get title {
    switch (this) {
      case NavSection.overview:
        return 'نظرة عامة';
      case NavSection.operations:
        return 'العمليات';
      case NavSection.insights:
        return 'التحليلات';
      case NavSection.management:
        return 'الإدارة';
    }
  }
}

class NavDestination {
  const NavDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.section,
    this.pageTitle = '',
    this.caption = '',
  });

  final String path;
  final String label;
  final IconData icon;
  final NavSection section;
  final String pageTitle;
  final String caption;

  String get resolvedTitle => pageTitle.isEmpty ? label : pageTitle;
}

const List<NavDestination> navDestinations = <NavDestination>[
  NavDestination(
    path: AppRoutes.dashboard,
    label: 'لوحة التحكم',
    icon: Icons.dashboard_outlined,
    section: NavSection.overview,
    caption: 'نظرة عامة على مساحة العمل وحالة النظام',
  ),
  NavDestination(
    path: AppRoutes.inventory,
    label: 'المخزون',
    icon: Icons.inventory_2_outlined,
    section: NavSection.operations,
    caption: 'المنتجات والتصنيفات والوحدات والمخزون',
  ),
  NavDestination(
    path: AppRoutes.sales,
    label: 'المبيعات',
    icon: Icons.point_of_sale,
    section: NavSection.operations,
    caption: 'العملاء والفواتير والمخزون الصادر',
  ),
  NavDestination(
    path: AppRoutes.purchases,
    label: 'المشتريات',
    icon: Icons.shopping_bag_outlined,
    section: NavSection.operations,
    caption: 'الموردون وأوامر الشراء والمخزون الوارد',
  ),
  NavDestination(
    path: AppRoutes.partners,
    label: 'الشركاء',
    icon: Icons.people_outlined,
    section: NavSection.operations,
    caption: 'دليل العملاء والموردين',
  ),
  NavDestination(
    path: AppRoutes.reports,
    label: 'التقارير',
    icon: Icons.bar_chart,
    section: NavSection.insights,
    caption: 'إحصائيات وتصديرات من بيانات حقيقية',
  ),
];

const NavDestination settingsDestination = NavDestination(
  path: AppRoutes.settings,
  label: 'الإعدادات',
  icon: Icons.settings_outlined,
  section: NavSection.insights,
  caption: 'المظهر وملف الشركة وقاعدة البيانات',
);

const List<NavDestination> managementDestinations = <NavDestination>[
  NavDestination(
    path: AppRoutes.users,
    label: 'المستخدمون',
    icon: Icons.manage_accounts_outlined,
    section: NavSection.management,
    caption: 'حسابات المستخدمين والأدوار وحالة الدخول',
  ),
  NavDestination(
    path: AppRoutes.permissions,
    label: 'الصلاحيات',
    icon: Icons.verified_user_outlined,
    section: NavSection.management,
    caption: 'تحديد الإجراءات المسموح بها لكل دور',
  ),
];

const List<NavDestination> menuDestinations = <NavDestination>[
  ...navDestinations,
  settingsDestination,
  ...managementDestinations,
];

NavDestination destinationFor(String path) {
  for (final NavDestination destination in menuDestinations) {
    if (destination.path == path) {
      return destination;
    }
  }
  if (path == AppRoutes.login) {
    return const NavDestination(
      path: AppRoutes.login,
      label: 'تسجيل الدخول',
      icon: Icons.login,
      section: NavSection.overview,
      caption: 'الدخول إلى حساب المستخدم',
    );
  }
  return const NavDestination(
    path: AppRoutes.dashboard,
    label: 'غير موجود',
    icon: Icons.error_outline,
    section: NavSection.overview,
  );
}
