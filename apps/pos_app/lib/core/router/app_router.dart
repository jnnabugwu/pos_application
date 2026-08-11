import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/view/login_page.dart';
import '../../features/order/presentation/bloc/order_bloc.dart';
import '../../features/order/presentation/bloc/order_event.dart';
import '../../features/order/presentation/view/order_page.dart';
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
  if (isLoggedIn && loggingIn) return AppRoutes.order();
  return null;
}

GoRouter buildRouter(AuthListenable authListenable) {
  return GoRouter(
    // Start on /login, not /order: until AuthListenable.ready flips true
    // the redirect below is a no-op, so landing on /order would build
    // OrderPage and fire a Firestore read before we know whether anyone is
    // signed in.
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
        path: AppRoutes.order(),
        builder: (context, state) => BlocProvider<OrderBloc>(
          create: (_) => getIt<OrderBloc>()..add(const WatchMenuStarted()),
          child: const OrderPage(),
        ),
      ),
    ],
  );
}
