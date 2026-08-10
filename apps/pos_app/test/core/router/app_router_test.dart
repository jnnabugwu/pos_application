import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/router/app_router.dart';
import 'package:pos_app/core/router/app_routes.dart';

void main() {
  group('resolveRedirect', () {
    test('does not redirect until auth state is ready', () {
      expect(
        resolveRedirect(isReady: false, isLoggedIn: false, location: AppRoutes.menu()),
        isNull,
      );
      expect(
        resolveRedirect(isReady: false, isLoggedIn: true, location: AppRoutes.login()),
        isNull,
      );
    });

    test('redirects signed-out users away from protected routes to /login', () {
      expect(
        resolveRedirect(isReady: true, isLoggedIn: false, location: AppRoutes.menu()),
        AppRoutes.login(),
      );
    });

    test('does not redirect a signed-out user already on /login', () {
      expect(
        resolveRedirect(isReady: true, isLoggedIn: false, location: AppRoutes.login()),
        isNull,
      );
    });

    test('redirects signed-in users away from /login to /menu', () {
      expect(
        resolveRedirect(isReady: true, isLoggedIn: true, location: AppRoutes.login()),
        AppRoutes.menu(),
      );
    });

    test('does not redirect a signed-in user already on /menu', () {
      expect(
        resolveRedirect(isReady: true, isLoggedIn: true, location: AppRoutes.menu()),
        isNull,
      );
    });
  });
}
