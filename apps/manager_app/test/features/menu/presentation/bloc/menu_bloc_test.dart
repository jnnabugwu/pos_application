import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:manager_app/features/menu/presentation/bloc/menu_bloc.dart';
import 'package:manager_app/features/menu/presentation/bloc/menu_event.dart';
import 'package:manager_app/features/menu/presentation/bloc/menu_state.dart';

import '../../../../support/fake_menu_repository.dart';

void main() {
  late MockMenuRepository menuRepository;

  final now = DateTime(2026, 1, 1);
  final item = MenuItem(
    id: 'item1',
    name: 'Coffee',
    priceCents: 350,
    category: 'Drinks',
    available: true,
    stockCount: 20,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() {
    menuRepository = MockMenuRepository();
  });

  group('MenuBloc', () {
    blocTest<MenuBloc, MenuState>(
      'emits loading then success with items from watchMenu()',
      setUp: () {
        when(
          () => menuRepository.watchMenu(),
        ).thenAnswer((_) => Stream.value([item]));
      },
      build: () => MenuBloc(menuRepository),
      act: (bloc) => bloc.add(const WatchMenuStarted()),
      expect: () => [
        const MenuState(status: MenuStatus.loading),
        MenuState(status: MenuStatus.success, items: [item]),
      ],
    );

    blocTest<MenuBloc, MenuState>(
      'ToggleAvailability optimistically flips the item and calls '
      'setAvailability with the flipped value',
      setUp: () {
        when(
          () => menuRepository.setAvailability(any(), any()),
        ).thenAnswer((_) async => const Right(unit));
      },
      build: () => MenuBloc(menuRepository),
      seed: () => MenuState(status: MenuStatus.success, items: [item]),
      act: (bloc) => bloc.add(const ToggleAvailability('item1')),
      expect: () => [
        MenuState(
          status: MenuStatus.success,
          items: [item.copyWith(available: false)],
        ),
      ],
      verify: (_) {
        verify(() => menuRepository.setAvailability('item1', false)).called(1);
      },
    );

    blocTest<MenuBloc, MenuState>(
      'ToggleAvailability is a no-op for an unknown item id',
      build: () => MenuBloc(menuRepository),
      seed: () => MenuState(status: MenuStatus.success, items: [item]),
      act: (bloc) => bloc.add(const ToggleAvailability('does-not-exist')),
      expect: () => <MenuState>[],
      verify: (_) {
        verifyNever(() => menuRepository.setAvailability(any(), any()));
      },
    );

    blocTest<MenuBloc, MenuState>(
      'rolls back the optimistic update and surfaces a failure when '
      'setAvailability fails',
      setUp: () {
        when(
          () => menuRepository.setAvailability(any(), any()),
        ).thenAnswer((_) async => const Left(PermissionFailure()));
      },
      build: () => MenuBloc(menuRepository),
      seed: () => MenuState(status: MenuStatus.success, items: [item]),
      act: (bloc) => bloc.add(const ToggleAvailability('item1')),
      expect: () => [
        MenuState(
          status: MenuStatus.success,
          items: [item.copyWith(available: false)],
        ),
        MenuState(
          status: MenuStatus.success,
          items: [item],
          failure: const PermissionFailure(),
        ),
      ],
    );

    blocTest<MenuBloc, MenuState>(
      'a second rapid tap flips from the pending optimistic value, not '
      'the stale confirmed one',
      setUp: () {
        when(
          () => menuRepository.setAvailability(any(), any()),
        ).thenAnswer((_) async => const Right(unit));
      },
      build: () => MenuBloc(menuRepository),
      seed: () => MenuState(status: MenuStatus.success, items: [item]),
      act: (bloc) {
        bloc.add(const ToggleAvailability('item1'));
        bloc.add(const ToggleAvailability('item1'));
      },
      expect: () => [
        MenuState(
          status: MenuStatus.success,
          items: [item.copyWith(available: false)],
        ),
        MenuState(
          status: MenuStatus.success,
          items: [item.copyWith(available: true)],
        ),
      ],
      verify: (_) {
        verify(() => menuRepository.setAvailability('item1', false)).called(1);
        verify(() => menuRepository.setAvailability('item1', true)).called(1);
      },
    );
  });
}
