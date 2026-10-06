import 'package:flutter/material.dart';

import '../../routing/app_routes.dart';
import 'permission_action.dart';
import 'permission_defaults.dart';

enum UserRole {
  admin,
  manager,
  accountant,
  storekeeper,
  sales;

  String get id => name;

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'مدير النظام';
      case UserRole.manager:
        return 'مدير عام';
      case UserRole.accountant:
        return 'محاسب';
      case UserRole.storekeeper:
        return 'أمين مخزن';
      case UserRole.sales:
        return 'مندوب مبيعات';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.admin:
        return Icons.admin_panel_settings_outlined;
      case UserRole.manager:
        return Icons.badge_outlined;
      case UserRole.accountant:
        return Icons.calculate_outlined;
      case UserRole.storekeeper:
        return Icons.warehouse_outlined;
      case UserRole.sales:
        return Icons.sell_outlined;
    }
  }

  static UserRole parse(String? raw) {
    for (final UserRole role in UserRole.values) {
      if (role.id == raw) {
        return role;
      }
    }
    return UserRole.sales;
  }

  List<String> get allowedPaths {
    return <String>[
      for (final String resource in PermissionDefaults.resources)
        if (PermissionDefaults.can(this, resource, PermissionAction.view))
          resource,
    ];
  }

  bool canAccess(String path) {
    if (path == AppRoutes.login) {
      return true;
    }
    return PermissionDefaults.can(this, path, PermissionAction.view);
  }

  bool can(String path, PermissionAction action) {
    if (path == AppRoutes.login) {
      return true;
    }
    return PermissionDefaults.can(this, path, action);
  }
}
