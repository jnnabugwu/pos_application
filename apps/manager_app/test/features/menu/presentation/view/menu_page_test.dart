import 'package:core/core.dart' as core;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:manager_app/features/menu/presentation/bloc/menu_bloc.dart';
import 'package:manager_app/features/menu/presentation/bloc/menu_event.dart';
import 'package:manager_app/features/menu/presentation/view/menu_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide MenuItem;

import '../../../../support/fake_auth_repository.dart';
import '../../../../support/fake_menu_repository.dart';

void main() {
  testWidgets('MenuPage shows a loading indicator before the menu loads', (
    tester,
  ) async {
    final authRepository = MockAuthRepository();
    when(
      () => authRepository.authStateChanges(),
    ).thenAnswer((_) => const Stream.empty());
    final authBloc = core.AuthBloc(authRepository);
    addTearDown(authBloc.close);
    final menuBloc = MenuBloc(MockMenuRepository());
    addTearDown(menuBloc.close);

    await tester.pumpWidget(
      ShadcnApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<core.AuthBloc>.value(value: authBloc),
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

  testWidgets('MenuPage renders the loaded menu items once watchMenu() '
      'emits', (tester) async {
    final now = DateTime(2026, 1, 1);
    final coffee = core.MenuItem(
      id: 'item1',
      name: 'Coffee',
      priceCents: 350,
      category: 'Drinks',
      available: true,
      createdAt: now,
      updatedAt: now,
      stockCount: 20,
    );
    final bagel = core.MenuItem(
      id: 'item2',
      name: 'Bagel',
      priceCents: 275,
      category: 'Food',
      available: false,
      createdAt: now,
      updatedAt: now,
      stockCount: 10,
    );

    final menuRepository = MockMenuRepository();
    when(
      () => menuRepository.watchMenu(),
    ).thenAnswer((_) => Stream.value([coffee, bagel]));

    final authRepository = MockAuthRepository();
    when(
      () => authRepository.authStateChanges(),
    ).thenAnswer((_) => const Stream.empty());
    final authBloc = core.AuthBloc(authRepository);
    addTearDown(authBloc.close);
    final menuBloc = MenuBloc(menuRepository);
    addTearDown(menuBloc.close);

    await tester.pumpWidget(
      ShadcnApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<core.AuthBloc>.value(value: authBloc),
            BlocProvider<MenuBloc>.value(value: menuBloc),
          ],
          child: const MenuPage(),
        ),
      ),
    );

    menuBloc.add(const WatchMenuStarted());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('\$3.50'), findsOneWidget);
    expect(find.text('Bagel'), findsOneWidget);
    expect(find.text('\$2.75'), findsOneWidget);
    expect(find.text('Drinks'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
  });
}
