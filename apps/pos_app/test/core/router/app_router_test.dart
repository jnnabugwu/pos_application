import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_app/core/router/app_router.dart';
import 'package:pos_app/core/router/app_routes.dart';
import 'package:pos_app/core/router/auth_listenable.dart';
import 'package:pos_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  group('buildRouter', () {
    testWidgets(
      'starts on /login rather than /menu, so no route builds and reads '
      'menu data before auth state is resolved',
      (tester) async {
        final authRepository = MockAuthRepository();
        // Never emits, so AuthListenable.ready stays false — simulates a
        // cold launch before the first authStateChanges() event arrives.
        when(
          () => authRepository.authStateChanges(),
        ).thenAnswer((_) => const Stream.empty());

        final authListenable = AuthListenable(authRepository);
        final authBloc = AuthBloc(authRepository);
        addTearDown(authListenable.dispose);
        addTearDown(authBloc.close);

        await tester.pumpWidget(
          BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: ShadcnApp.router(routerConfig: buildRouter(authListenable)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sign in'), findsWidgets);
      },
    );
  });

  group('resolveRedirect', () {
    test('does not redirect until auth state is ready', () {
      expect(
        resolveRedirect(
          isReady: false,
          isLoggedIn: false,
          location: AppRoutes.menu(),
        ),
        isNull,
      );
      expect(
        resolveRedirect(
          isReady: false,
          isLoggedIn: true,
          location: AppRoutes.login(),
        ),
        isNull,
      );
    });

    test('redirects signed-out users away from protected routes to /login', () {
      expect(
        resolveRedirect(
          isReady: true,
          isLoggedIn: false,
          location: AppRoutes.menu(),
        ),
        AppRoutes.login(),
      );
    });

    test('does not redirect a signed-out user already on /login', () {
      expect(
        resolveRedirect(
          isReady: true,
          isLoggedIn: false,
          location: AppRoutes.login(),
        ),
        isNull,
      );
    });

    test('redirects signed-in users away from /login to /menu', () {
      expect(
        resolveRedirect(
          isReady: true,
          isLoggedIn: true,
          location: AppRoutes.login(),
        ),
        AppRoutes.menu(),
      );
    });

    test('does not redirect a signed-in user already on /menu', () {
      expect(
        resolveRedirect(
          isReady: true,
          isLoggedIn: true,
          location: AppRoutes.menu(),
        ),
        isNull,
      );
    });
  });
}
