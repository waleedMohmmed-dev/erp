import 'package:flutter/material.dart';

import '../../core/auth/permission_action.dart';
import '../../core/auth/permission_defaults.dart';
import '../../core/auth/user_role.dart';
import '../../core/database/app_database.dart';

class PermissionsController extends ChangeNotifier {
  PermissionsController({required this.database});

  final AppDatabase database;

  final Set<String> _granted = <String>{};
  bool _loaded = false;

  bool get loaded => _loaded;

  static String keyOf(String role, String resource, String action) =>
      '$role|$resource|$action';

  Future<void> load() async {
    try {
      final List<PermissionGrant> grants = await database.listPermissions();
      _granted
        ..clear()
        ..addAll(
          grants
              .where((PermissionGrant grant) => grant.allowed)
              .map(
                (PermissionGrant grant) =>
                    keyOf(grant.role, grant.resource, grant.action),
              ),
        );
      _loaded = true;
    } finally {
      notifyListeners();
    }
  }

  bool can(String roleId, String resource, PermissionAction action) {
    if (roleId == UserRole.admin.id) {
      return true;
    }
    if (!loaded || !PermissionDefaults.isResource(resource)) {
      return false;
    }

    if (action == PermissionAction.view) {
      return PermissionAction.values.any(
        (PermissionAction candidate) =>
            _granted.contains(keyOf(roleId, resource, candidate.id)),
      );
    }

    return _granted.contains(keyOf(roleId, resource, action.id));
  }

  Set<PermissionAction> grantedActions(String roleId, String resource) {
    return PermissionAction.values
        .where((PermissionAction action) => can(roleId, resource, action))
        .toSet();
  }

  Future<void> set({
    required String role,
    required String resource,
    required PermissionAction action,
    required bool allowed,
  }) async {
    if (role == UserRole.admin.id) {
      return;
    }

    final String viewKey = keyOf(role, resource, PermissionAction.view.id);

    if (action == PermissionAction.view && !allowed) {
      final bool otherGranted = PermissionAction.values
          .where(
            (PermissionAction candidate) => candidate != PermissionAction.view,
          )
          .any(
            (PermissionAction candidate) =>
                _granted.contains(keyOf(role, resource, candidate.id)),
          );
      if (otherGranted) {
        return;
      }
    }

    if (action != PermissionAction.view &&
        allowed &&
        !_granted.contains(viewKey)) {
      _granted.add(viewKey);
      await database.setPermission(
        role: role,
        resource: resource,
        action: PermissionAction.view.id,
        allowed: true,
      );
    }

    await database.setPermission(
      role: role,
      resource: resource,
      action: action.id,
      allowed: allowed,
    );

    final String key = keyOf(role, resource, action.id);
    if (allowed) {
      _granted.add(key);
    } else {
      _granted.remove(key);
    }
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await database.resetPermissions();
    await load();
  }
}
