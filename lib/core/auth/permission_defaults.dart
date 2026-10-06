import '../../routing/app_routes.dart';
import 'permission_action.dart';
import 'user_role.dart';

abstract final class PermissionDefaults {
  static const Set<PermissionAction> full = <PermissionAction>{
    PermissionAction.view,
    PermissionAction.create,
    PermissionAction.edit,
    PermissionAction.delete,
  };

  static const Set<PermissionAction> viewOnly = <PermissionAction>{
    PermissionAction.view,
  };

  static const Set<PermissionAction> viewEdit = <PermissionAction>{
    PermissionAction.view,
    PermissionAction.edit,
  };

  static const Set<PermissionAction> viewCreateEdit = <PermissionAction>{
    PermissionAction.view,
    PermissionAction.create,
    PermissionAction.edit,
  };

  static const List<String> resources = <String>[
    AppRoutes.dashboard,
    AppRoutes.inventory,
    AppRoutes.sales,
    AppRoutes.purchases,
    AppRoutes.partners,
    AppRoutes.reports,
    AppRoutes.settings,
    AppRoutes.users,
    AppRoutes.permissions,
  ];

  static const Map<UserRole, Map<String, Set<PermissionAction>>> matrix =
      <UserRole, Map<String, Set<PermissionAction>>>{
        UserRole.admin: <String, Set<PermissionAction>>{
          AppRoutes.dashboard: full,
          AppRoutes.inventory: full,
          AppRoutes.sales: full,
          AppRoutes.purchases: full,
          AppRoutes.partners: full,
          AppRoutes.reports: full,
          AppRoutes.settings: full,
          AppRoutes.users: full,
          AppRoutes.permissions: full,
        },
        UserRole.manager: <String, Set<PermissionAction>>{
          AppRoutes.dashboard: viewOnly,
          AppRoutes.inventory: full,
          AppRoutes.sales: full,
          AppRoutes.purchases: full,
          AppRoutes.partners: full,
          AppRoutes.reports: viewOnly,
          AppRoutes.settings: viewEdit,
          AppRoutes.users: viewCreateEdit,
          AppRoutes.permissions: viewOnly,
        },
        UserRole.accountant: <String, Set<PermissionAction>>{
          AppRoutes.dashboard: viewOnly,
          AppRoutes.inventory: viewOnly,
          AppRoutes.sales: viewOnly,
          AppRoutes.purchases: viewOnly,
          AppRoutes.partners: viewCreateEdit,
          AppRoutes.reports: viewOnly,
          AppRoutes.settings: viewOnly,
        },
        UserRole.storekeeper: <String, Set<PermissionAction>>{
          AppRoutes.dashboard: viewOnly,
          AppRoutes.inventory: full,
          AppRoutes.purchases: viewCreateEdit,
          AppRoutes.reports: viewOnly,
        },
        UserRole.sales: <String, Set<PermissionAction>>{
          AppRoutes.dashboard: viewOnly,
          AppRoutes.sales: viewCreateEdit,
          AppRoutes.partners: viewCreateEdit,
        },
      };

  static bool isResource(String resource) => resources.contains(resource);

  static Set<PermissionAction> grants(UserRole role, String resource) {
    return matrix[role]?[resource] ?? const <PermissionAction>{};
  }

  static bool can(UserRole role, String resource, PermissionAction action) {
    if (role == UserRole.admin) {
      return true;
    }
    final Set<PermissionAction> granted = grants(role, resource);
    if (action == PermissionAction.view) {
      return granted.isNotEmpty;
    }
    return granted.contains(action);
  }

  static List<(String, String, String)> seedRows() {
    final List<(String, String, String)> rows = <(String, String, String)>[];
    matrix.forEach((UserRole role, Map<String, Set<PermissionAction>> pages) {
      pages.forEach((String resource, Set<PermissionAction> granted) {
        for (final PermissionAction action in granted) {
          rows.add((role.id, resource, action.id));
        }
      });
    });
    return rows;
  }
}
