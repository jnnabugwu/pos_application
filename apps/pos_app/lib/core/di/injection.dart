import 'package:core/core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/menu/presentation/bloc/menu_bloc.dart';
import '../router/app_router.dart';
import '../router/auth_listenable.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  registerCoreDependencies(getIt);

  getIt.registerLazySingleton<AuthListenable>(
    () => AuthListenable(getIt<AuthRepository>()),
    dispose: (listenable) => listenable.dispose(),
  );
  getIt.registerLazySingleton<GoRouter>(
    () => buildRouter(getIt<AuthListenable>()),
  );

  // App-level singleton: shared by LoginPage (sign-in) and MenuPage's
  // sign-out action, so it outlives any single screen.
  getIt.registerLazySingleton<AuthBloc>(() => AuthBloc(getIt<AuthRepository>()));

  // Factory: fresh instance (and fresh watchMenu() subscription) each time
  // /menu is entered; disposed by BlocProvider when the route is left.
  getIt.registerFactory<MenuBloc>(() => MenuBloc(getIt<MenuRepository>()));
}
