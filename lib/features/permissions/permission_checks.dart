import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/permission_action.dart';
import '../../routing/app_routes.dart';
import '../auth/session_controller.dart';
import 'permissions_controller.dart';

extension PermissionChecks on BuildContext {
  SessionController get session => watch<SessionController>();

  PermissionsController get permissions => watch<PermissionsController>();

  String? get currentRoleId => session.user?.role.id;

  bool canDo(String resource, PermissionAction action) {
    final String? roleId = currentRoleId;
    if (roleId == null) {
      return false;
    }
    return permissions.can(roleId, resource, action);
  }

  bool canView(String resource) => canDo(resource, PermissionAction.view);

  bool canCreate(String resource) => canDo(resource, PermissionAction.create);

  bool canEdit(String resource) => canDo(resource, PermissionAction.edit);

  bool canDelete(String resource) => canDo(resource, PermissionAction.delete);

  bool get isAdmin => currentRoleId == 'admin';
}

bool routeIsViewable(BuildContext context, String route) {
  if (route == AppRoutes.login || !AppRoutes.isKnown(route)) {
    return true;
  }
  return context.canView(route);
}
