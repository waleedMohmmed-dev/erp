import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_info.dart';
import '../core/auth/auth_user.dart';
import '../core/database/app_database.dart';
import '../core/layout/breakpoints.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/session_controller.dart';
import '../features/settings/settings_controller.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    this.onOpenMenu,
    this.onToggleMenu,
    this.menuExpanded = true,
    this.onLogout,
  });

  final VoidCallback? onOpenMenu;
  final VoidCallback? onToggleMenu;
  final bool menuExpanded;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final String companyName = context.select<SettingsController, String>(
      (SettingsController controller) => controller.companyName,
    );

    return Container(
      height: Breakpoints.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: isDark ? AppColors.topBarDark : AppColors.brand,
      child: Row(
        children: <Widget>[
          if (onOpenMenu != null)
            IconButton(
              onPressed: onOpenMenu,
              tooltip: 'فتح القائمة',
              color: Colors.white,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.menu, size: 22),
            ),
          _CompanyBlock(companyName: companyName),
          const Spacer(),
          const _DatabaseStatusChip(),
          const SizedBox(width: 6),
          const _ThemeMenu(),
          if (onLogout != null) ...<Widget>[
            const SizedBox(width: 4),
            _UserMenu(onLogout: onLogout!),
          ],
          if (onToggleMenu != null)
            IconButton(
              onPressed: onToggleMenu,
              tooltip: menuExpanded ? 'طي القائمة' : 'توسيع القائمة',
              color: Colors.white,
              visualDensity: VisualDensity.compact,
              icon: Icon(menuExpanded ? Icons.menu_open : Icons.menu, size: 21),
            ),
        ],
      ),
    );
  }
}

class _CompanyBlock extends StatelessWidget {
  const _CompanyBlock({required this.companyName});

  final String companyName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.storefront, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              const Text(
                AppInfo.branch,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();
    final AuthUser? user = session.user;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'الحساب',
      padding: EdgeInsets.zero,
      onSelected: (String value) {
        if (value == 'logout') {
          onLogout();
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(
              user.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  user.role.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 20, color: Colors.white),
        ],
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  user.email,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'الدور: ${user.role.label}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: <Widget>[
              Icon(Icons.logout, size: 18),
              SizedBox(width: 10),
              Text('تسجيل الخروج'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeMenu extends StatelessWidget {
  const _ThemeMenu();

  @override
  Widget build(BuildContext context) {
    final ThemeMode mode = context.select<SettingsController, ThemeMode>(
      (SettingsController controller) => controller.themeMode,
    );

    return PopupMenuButton<ThemeMode>(
      tooltip: 'المظهر',
      icon: Icon(
        mode == ThemeMode.system
            ? Icons.brightness_auto
            : mode == ThemeMode.light
            ? Icons.light_mode
            : Icons.dark_mode,
        size: 20,
        color: Colors.white,
      ),
      onSelected: (ThemeMode value) =>
          context.read<SettingsController>().setThemeMode(value),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<ThemeMode>>[
        _entry(
          context,
          ThemeMode.system,
          Icons.brightness_auto,
          'النظام',
          mode,
        ),
        _entry(context, ThemeMode.light, Icons.light_mode, 'فاتح', mode),
        _entry(context, ThemeMode.dark, Icons.dark_mode, 'داكن', mode),
      ],
    );
  }

  static PopupMenuItem<ThemeMode> _entry(
    BuildContext context,
    ThemeMode value,
    IconData icon,
    String label,
    ThemeMode current,
  ) {
    return CheckedPopupMenuItem<ThemeMode>(
      value: value,
      checked: current == value,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _DatabaseStatusChip extends StatefulWidget {
  const _DatabaseStatusChip();

  @override
  State<_DatabaseStatusChip> createState() => _DatabaseStatusChipState();
}

class _DatabaseStatusChipState extends State<_DatabaseStatusChip> {
  late Future<String> _check;

  @override
  void initState() {
    super.initState();
    _check = context.read<AppDatabase>().integrityCheck();
  }

  void _recheck() {
    setState(() {
      _check = context.read<AppDatabase>().integrityCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _check,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final bool pending = snapshot.connectionState != ConnectionState.done;
        final bool ok = snapshot.data?.toLowerCase() == 'ok';
        final Color color = pending
            ? Colors.white70
            : ok
            ? const Color(0xFF5CE08B)
            : const Color(0xFFFFB4A9);
        final String label = pending
            ? 'جارٍ الفحص'
            : ok
            ? 'قاعدة محلية'
            : 'مشكلة في القاعدة';

        return Tooltip(
          message: snapshot.hasError
              ? 'فشل فحص قاعدة البيانات: ${snapshot.error}'
              : pending
              ? 'جارٍ تشغيل فحص سلامة SQLite'
              : 'فحص سلامة SQLite: ${snapshot.data ?? 'غير معروف'}',
          child: InkWell(
            onTap: _recheck,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
