import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/view/login_page.dart';
import '../../features/menu/presentation/bloc/menu_bloc.dart';
import '../../features/menu/presentation/bloc/menu_event.dart';
import '../../features/menu/presentation/view/menu_page.dart';
import '../di/injection.dart';
import 'app_routes.dart';
import 'auth_listenable.dart';

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

GoRouter buildRouter(AuthListenable authListenable) {
  return GoRouter(
    initialLocation: AppRoutes.menu(),
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
    ],
  );
}
