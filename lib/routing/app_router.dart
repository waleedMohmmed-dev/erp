import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shell/app_shell.dart';
import 'app_routes.dart';

class AppRouteInformationParser extends RouteInformationParser<String> {
  const AppRouteInformationParser();

  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) {
    return SynchronousFuture<String>(AppRoutes.fromUri(routeInformation.uri));
  }

  @override
  RouteInformation restoreRouteInformation(String configuration) {
    return RouteInformation(uri: Uri.parse(configuration));
  }
}

class AppRouterDelegate extends RouterDelegate<String> with ChangeNotifier {
  AppRouterDelegate({String initialLocation = AppRoutes.dashboard})
    : _path = AppRoutes.normalize(initialLocation),
      _history = <String>[] {
    _history.add(_path);
  }

  String _path;
  final List<String> _history;

  String get path => _path;

  List<String> get history => List<String>.unmodifiable(_history);

  @override
  String get currentConfiguration => _path;

  void go(String location) {
    final String target = AppRoutes.normalize(location);
    if (target == _path) {
      return;
    }
    _history.add(target);
    _path = target;
    notifyListeners();
  }

  void replace(String location) {
    final String target = AppRoutes.normalize(location);
    if (target == _path) {
      return;
    }
    if (_history.isEmpty) {
      _history.add(target);
    } else {
      _history[_history.length - 1] = target;
    }
    _path = target;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {
    final String target = AppRoutes.normalize(configuration);
    if (target == _path) {
      return;
    }
    if (_history.length > 1 && _history[_history.length - 2] == target) {
      _history.removeLast();
    } else {
      _history.add(target);
    }
    _path = target;
    notifyListeners();
  }

  @override
  Future<bool> popRoute() async {
    if (_history.length <= 1) {
      return false;
    }
    _history.removeLast();
    _path = _history.last;
    notifyListeners();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      pages: <Page<Object?>>[
        MaterialPage<Object?>(
          key: const ValueKey<String>('app-shell'),
          name: _path,
          child: AppShell(route: _path, onNavigate: go),
        ),
      ],
      onDidRemovePage: (Page<Object?> page) {},
    );
  }
}
