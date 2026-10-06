import 'package:flutter_test/flutter_test.dart';
import 'package:web_erp/routing/app_routes.dart';

void main() {
  group('AppRoutes.normalize', () {
    test('empty location becomes the dashboard', () {
      expect(AppRoutes.normalize(''), AppRoutes.dashboard);
      expect(AppRoutes.normalize('   '), AppRoutes.dashboard);
    });

    test('adds a leading slash', () {
      expect(AppRoutes.normalize('inventory'), '/inventory');
      expect(AppRoutes.normalize('sales'), '/sales');
    });

    test('removes trailing slashes', () {
      expect(AppRoutes.normalize('/inventory/'), '/inventory');
      expect(AppRoutes.normalize('/'), '/');
      expect(AppRoutes.normalize('//'), '/');
    });

    test('keeps known paths untouched', () {
      expect(AppRoutes.normalize('/settings'), '/settings');
      expect(AppRoutes.normalize('  /reports  '), '/reports');
    });
  });

  group('AppRoutes.fromUri', () {
    test('reads a plain path', () {
      expect(AppRoutes.fromUri(Uri.parse('/inventory')), '/inventory');
    });

    test('reads a hash based web url', () {
      expect(
        AppRoutes.fromUri(Uri.parse('http://localhost:8080/#/sales')),
        '/sales',
      );
      expect(
        AppRoutes.fromUri(Uri.parse('http://localhost:8080/')),
        AppRoutes.dashboard,
      );
    });

    test('falls back to the dashboard for an empty uri', () {
      expect(AppRoutes.fromUri(Uri.parse('')), AppRoutes.dashboard);
    });
  });

  group('route registry', () {
    test('knows every built-in route', () {
      for (final String path in AppRoutes.all) {
        expect(AppRoutes.isKnown(path), isTrue, reason: path);
      }
    });

    test('rejects unknown routes', () {
      expect(AppRoutes.isKnown('/nope'), isFalse);
      expect(destinationFor('/nope').label, 'غير موجود');
    });

    test('resolves destinations for each menu entry', () {
      for (final NavDestination destination in navDestinations) {
        expect(destinationFor(destination.path).label, destination.label);
      }
      expect(destinationFor(AppRoutes.settings).label, 'الإعدادات');
    });
  });
}
