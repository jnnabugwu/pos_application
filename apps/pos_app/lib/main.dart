import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  configureDependencies();
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: getIt<AuthBloc>(),
      child: ShadcnApp.router(
        title: 'POS',
        routerConfig: getIt<GoRouter>(),
        theme: appLightTheme,
        darkTheme: appDarkTheme,
        themeMode: ThemeMode.system,
      ),
    );
  }
}
