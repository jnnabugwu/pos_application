import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pos_app/features/menu/presentation/bloc/menu_bloc.dart';
import 'package:pos_app/features/menu/presentation/view/menu_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide MenuItem;

import '../../../../support/fake_auth_repository.dart';
import '../../../../support/fake_menu_repository.dart';

void main() {
  testWidgets('MenuPage shows a loading indicator before the menu loads', (
    tester,
  ) async {
    final authBloc = AuthBloc(MockAuthRepository());
    addTearDown(authBloc.close);
    final menuBloc = MenuBloc(MockMenuRepository());
    addTearDown(menuBloc.close);

    await tester.pumpWidget(
      ShadcnApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<MenuBloc>.value(value: menuBloc),
          ],
          child: const MenuPage(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
