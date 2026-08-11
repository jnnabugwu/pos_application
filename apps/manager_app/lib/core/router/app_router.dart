import 'package:core/core.dart' as core;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/view/login_page.dart';
import '../../features/menu/presentation/bloc/menu_bloc.dart';
import '../../features/menu/presentation/bloc/menu_event.dart';
import '../../features/menu/presentation/view/menu_item_form_page.dart';
import '../../features/menu/presentation/view/menu_page.dart';
import '../di/injection.dart';
import 'app_routes.dart';

/// Pure redirect decision, kept separate from [GoRouter] so it's unit
/// testable without a BuildContext/GoRouterState.
@visibleForTesting
String? resolveRedirect({
  required bool isReady,
  required bool isLoggedIn,
  required String location,
}) {
  if (!isReady) return null;
  final loggingIn = location == AppRoutes.login();
  if (!isLoggedIn && !loggingIn) return AppRoutes.login();
  if (isLoggedIn && loggingIn) return AppRoutes.menu();
  return null;
}

GoRouter buildRouter(core.AuthListenable authListenable) {
  return GoRouter(
    // Start on /login, not /menu: until core.AuthListenable.ready flips true the
    // redirect below is a no-op, so landing on /menu would build MenuPage
    // and fire a Firestore read before we know whether anyone is signed in.
    initialLocation: AppRoutes.login(),
    refreshListenable: authListenable,
    redirect: (context, state) => resolveRedirect(
      isReady: authListenable.ready,
      isLoggedIn: authListenable.currentUser != null,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.login(),
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.menu(),
        builder: (context, state) => BlocProvider<MenuBloc>(
          create: (_) => getIt<MenuBloc>()..add(const WatchMenuStarted()),
          child: const MenuPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.newItem(),
        builder: (context, state) => const MenuItemFormPage(),
      ),
      GoRoute(
        path: AppRoutes.editItem(),
        // `extra` only exists for the in-memory navigation from MenuPage's
        // tile tap — a deep link, browser refresh (web), or restored route
        // has no way to carry it, so guard rather than crash on the cast.
        redirect: (context, state) =>
            state.extra is core.MenuItem ? null : AppRoutes.menu(),
        builder: (context, state) =>
            MenuItemFormPage(item: state.extra as core.MenuItem),
      ),
    ],
  );
}
