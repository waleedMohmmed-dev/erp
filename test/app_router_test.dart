import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_erp/routing/app_router.dart';
import 'package:web_erp/routing/app_routes.dart';

void main() {
  group('AppRouteInformationParser', () {
    const AppRouteInformationParser parser = AppRouteInformationParser();

    test('parses route information', () async {
      expect(
        await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse('/purchases')),
        ),
        '/purchases',
      );
    });

    test('round trips a configuration', () async {
      final RouteInformation restored = parser.restoreRouteInformation(
        '/reports',
      );
      expect(restored.uri.path, '/reports');
      expect(await parser.parseRouteInformation(restored), '/reports');
    });
  });

  group('AppRouterDelegate', () {
    late AppRouterDelegate delegate;

    setUp(() {
      delegate = AppRouterDelegate();
    });

    tearDown(() {
      delegate.dispose();
    });

    test('starts on the dashboard', () {
      expect(delegate.path, AppRoutes.dashboard);
      expect(delegate.currentConfiguration, AppRoutes.dashboard);
      expect(delegate.history, <String>[AppRoutes.dashboard]);
    });

    test('go pushes a new history entry', () {
      delegate.go(AppRoutes.inventory);

      expect(delegate.path, AppRoutes.inventory);
      expect(delegate.history, <String>['/', '/inventory']);
    });

    test('go ignores the current path', () {
      delegate.go(AppRoutes.sales);
      delegate.go(AppRoutes.sales);

      expect(delegate.history, <String>['/', '/sales']);
    });

    test('go normalizes the given location', () {
      delegate.go('reports');

      expect(delegate.path, '/reports');
    });

    test('popRoute walks back through the history', () async {
      delegate.go(AppRoutes.sales);
      delegate.go(AppRoutes.settings);

      expect(await delegate.popRoute(), isTrue);
      expect(delegate.path, AppRoutes.sales);

      expect(await delegate.popRoute(), isTrue);
      expect(delegate.path, AppRoutes.dashboard);

      expect(await delegate.popRoute(), isFalse);
      expect(delegate.path, AppRoutes.dashboard);
    });

    test('setNewRoutePath handles browser back', () async {
      delegate.go(AppRoutes.purchases);
      delegate.go(AppRoutes.settings);

      await delegate.setNewRoutePath(AppRoutes.purchases);

      expect(delegate.path, AppRoutes.purchases);
      expect(delegate.history, <String>['/', '/purchases']);
    });

    test('setNewRoutePath handles an external deep link', () async {
      await delegate.setNewRoutePath('/partners');

      expect(delegate.path, '/partners');
      expect(delegate.history, <String>['/', '/partners']);
    });

    test('setNewRoutePath keeps unknown routes reachable', () async {
      await delegate.setNewRoutePath('/does-not-exist');

      expect(delegate.path, '/does-not-exist');
      expect(delegate.currentConfiguration, '/does-not-exist');
    });

    test('replace swaps the last history entry', () {
      delegate.go(AppRoutes.sales);
      delegate.replace(AppRoutes.reports);

      expect(delegate.history, <String>['/', '/reports']);
      expect(delegate.path, AppRoutes.reports);
    });

    test('notifies listeners on navigation', () {
      int notifications = 0;
      delegate.addListener(() => notifications++);

      delegate.go(AppRoutes.inventory);

      expect(notifications, 1);
    });
  });
}
