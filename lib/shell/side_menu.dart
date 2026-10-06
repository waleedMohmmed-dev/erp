import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/layout/breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../features/permissions/permission_checks.dart';
import '../routing/app_routes.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({
    super.key,
    required this.route,
    required this.onNavigate,
    required this.expanded,
  });

  final String route;
  final ValueChanged<String> onNavigate;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double width = expanded
        ? Breakpoints.sidebarWidth
        : Breakpoints.railWidth;

    return Container(
      width: width,
      color: theme.brightness == Brightness.dark
          ? AppColors.sidebarDark
          : AppColors.sidebarLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(context),
          Divider(indent: expanded ? 12 : 0, endIndent: expanded ? 12 : 0),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 12 : 8,
                vertical: 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildSections(context),
              ),
            ),
          ),
          if (expanded) _buildStatus(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final Widget logo = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.account_balance, size: 20, color: Colors.white),
    );

    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Align(alignment: Alignment.center, child: logo),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 14),
      child: Row(
        children: <Widget>[
          logo,
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _AppName(),
                SizedBox(height: 2),
                _AppTagline(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> children = <Widget>[];

    for (final NavSection section in NavSection.values) {
      final List<NavDestination> items = menuDestinations
          .where(
            (NavDestination destination) =>
                destination.section == section &&
                context.canView(destination.path),
          )
          .toList();
      if (items.isEmpty) {
        continue;
      }

      if (expanded) {
        children.add(
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 12, 10, 8),
            child: Text(
              section.title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      } else {
        children.add(const SizedBox(height: 14));
      }

      for (final NavDestination item in items) {
        children.add(
          _MenuItem(
            destination: item,
            selected: route == item.path,
            expanded: expanded,
            onNavigate: onNavigate,
          ),
        );
      }

      children.add(const SizedBox(height: 4));
    }

    return children;
  }

  Widget _buildStatus(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('SQLite · محلي فقط', style: theme.textTheme.labelSmall),
                Text(
                  'v${AppInfo.version}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppName extends StatelessWidget {
  const _AppName();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppInfo.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5),
    );
  }
}

class _AppTagline extends StatelessWidget {
  const _AppTagline();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppInfo.tagline,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onNavigate,
  });

  final NavDestination destination;
  final bool selected;
  final bool expanded;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color foreground = selected
        ? AppColors.success
        : scheme.onSurfaceVariant;

    final Widget leading = Icon(destination.icon, size: 20, color: foreground);

    final Widget child = expanded
        ? Row(
            children: <Widget>[
              leading,
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    height: 1.3,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          )
        : Center(child: leading);

    final Widget item = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onNavigate(destination.path),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 40,
          padding: expanded
              ? const EdgeInsets.symmetric(horizontal: 12)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: AppColors.success, width: 1.4)
                : Border.all(color: Colors.transparent, width: 1.4),
          ),
          child: child,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 2 : 0, vertical: 2),
      child: expanded ? item : Tooltip(message: destination.label, child: item),
    );
  }
}
