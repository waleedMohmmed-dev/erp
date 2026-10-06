import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_info.dart';
import '../core/auth/permission_action.dart';
import '../core/layout/breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/no_access_page.dart';
import '../core/widgets/not_found_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/session_controller.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/partners/partners_page.dart';
import '../features/permissions/permission_checks.dart';
import '../features/permissions/permissions_page.dart';
import '../features/purchases/purchases_page.dart';
import '../features/reports/reports_page.dart';
import '../features/sales/sales_page.dart';
import '../features/settings/settings_page.dart';
import '../features/users/users_page.dart';
import '../routing/app_routes.dart';
import 'app_top_bar.dart';
import 'side_menu.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.route, required this.onNavigate});

  final String route;
  final ValueChanged<String> onNavigate;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _menuExpanded = true;

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();

    if (session.restoring) {
      return const _SplashScreen();
    }

    if (!session.isAuthenticated) {
      return LoginPage(onLoggedIn: _afterLogin);
    }

    final bool onLoginRoute = widget.route == AppRoutes.login;
    if (onLoginRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.route == AppRoutes.login) {
          widget.onNavigate(AppRoutes.dashboard);
        }
      });
    }

    final bool allowed =
        onLoginRoute ||
        !AppRoutes.isKnown(widget.route) ||
        context.canDo(widget.route, PermissionAction.view);

    final String route = onLoginRoute ? AppRoutes.dashboard : widget.route;
    final bool blocked = !allowed;

    final ShellLayout layout = context.shellLayout;
    final bool showSidebar = layout != ShellLayout.compact;
    final bool menuExpanded = layout == ShellLayout.expanded && _menuExpanded;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: showSidebar
          ? null
          : Drawer(
              width: Breakpoints.compactDrawerWidth,
              child: SideMenu(
                route: route,
                expanded: true,
                onNavigate: _handleNavigate,
              ),
            ),
      body: Row(
        children: <Widget>[
          if (showSidebar) ...<Widget>[
            SideMenu(
              route: route,
              expanded: menuExpanded,
              onNavigate: _handleNavigate,
            ),
          ],
          Expanded(
            child: Column(
              children: <Widget>[
                AppTopBar(
                  onOpenMenu: showSidebar
                      ? null
                      : () => _scaffoldKey.currentState?.openDrawer(),
                  onToggleMenu: layout == ShellLayout.expanded
                      ? _toggleMenu
                      : null,
                  menuExpanded: menuExpanded,
                  onLogout: _handleLogout,
                ),
                Expanded(
                  child: blocked
                      ? NoAccessPage(
                          onBack: () => widget.onNavigate(AppRoutes.dashboard),
                        )
                      : _RouteHost(route: route, onNavigate: widget.onNavigate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _afterLogin() {
    widget.onNavigate(AppRoutes.dashboard);
  }

  Future<void> _handleLogout() async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    final SessionController session = context.read<SessionController>();
    await session.logout();
    if (!mounted) {
      return;
    }
    widget.onNavigate(AppRoutes.login);
  }

  void _toggleMenu() {
    setState(() {
      _menuExpanded = !_menuExpanded;
    });
  }

  void _handleNavigate(String path) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    widget.onNavigate(path);
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.account_balance,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(height: 16),
            Text('جارٍ تحميل مساحة العمل…', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(AppInfo.name, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _RouteHost extends StatelessWidget {
  const _RouteHost({required this.route, required this.onNavigate});

  final String route;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: ValueKey<String>(route), child: _pageFor()),
    );
  }

  Widget _pageFor() {
    switch (route) {
      case AppRoutes.dashboard:
        return const DashboardPage();
      case AppRoutes.inventory:
        return const InventoryPage();
      case AppRoutes.sales:
        return const SalesPage();
      case AppRoutes.purchases:
        return const PurchasesPage();
      case AppRoutes.partners:
        return const PartnersPage();
      case AppRoutes.reports:
        return const ReportsPage();
      case AppRoutes.settings:
        return const SettingsPage();
      case AppRoutes.users:
        return const UsersPage();
      case AppRoutes.permissions:
        return const PermissionsPage();
      default:
        return NotFoundPage(onBack: onNavigateToDashboard);
    }
  }

  void onNavigateToDashboard() => onNavigate(AppRoutes.dashboard);
}
