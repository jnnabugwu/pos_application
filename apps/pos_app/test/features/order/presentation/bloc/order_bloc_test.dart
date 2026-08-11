import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart' as core;
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_app/features/order/domain/cart_line.dart';
import 'package:pos_app/features/order/presentation/bloc/order_bloc.dart';
import 'package:pos_app/features/order/presentation/bloc/order_event.dart';
import 'package:pos_app/features/order/presentation/bloc/order_state.dart';

import '../../../../support/fake_menu_repository.dart';
import '../../../../support/fake_order_repository.dart';

void main() {
  late MockMenuRepository menuRepository;
  late MockOrderRepository orderRepository;

  final now = DateTime(2026, 1, 1);
  final coffee = core.MenuItem(
    id: 'item1',
    name: 'Coffee',
    priceCents: 350,
    category: 'Drinks',
    available: true,
    stockCount: 2,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() {
    menuRepository = MockMenuRepository();
    orderRepository = MockOrderRepository();
  });

  group('AddToCart', () {
    blocTest<OrderBloc, OrderState>(
      'adds a new line for an item not yet in the cart',
      build: () => OrderBloc(menuRepository, orderRepository),
      seed: () => OrderState(status: OrderStatus.success, menuItems: [coffee]),
      act: (bloc) => bloc.add(const AddToCart('item1')),
      expect: () => [
        OrderState(
          status: OrderStatus.success,
          menuItems: [coffee],
          cart: const [
            CartLine(
              menuItemId: 'item1',
              name: 'Coffee',
              priceCents: 350,
              quantity: 1,
            ),
          ],
        ),
      ],
    );

    blocTest<OrderBloc, OrderState>(
      'stops incrementing once the cart already holds all remaining stock',
      build: () => OrderBloc(menuRepository, orderRepository),
      seed: () => OrderState(
        status: OrderStatus.success,
        menuItems: [coffee],
        cart: const [
          CartLine(
            menuItemId: 'item1',
            name: 'Coffee',
            priceCents: 350,
            quantity: 2,
          ),
        ],
      ),
      act: (bloc) => bloc.add(const AddToCart('item1')),
      expect: () => <OrderState>[],
    );

    blocTest<OrderBloc, OrderState>(
      'is a no-op while checkout is in flight',
      build: () => OrderBloc(menuRepository, orderRepository),
      seed: () => OrderState(
        status: OrderStatus.success,
        menuItems: [coffee],
        isCheckingOut: true,
      ),
      act: (bloc) => bloc.add(const AddToCart('item1')),
      expect: () => <OrderState>[],
    );
  });

  group('DecrementCartLine / RemoveCartLine', () {
    const cart = [
      CartLine(
        menuItemId: 'item1',
        name: 'Coffee',
        priceCents: 350,
        quantity: 1,
      ),
    ];

    blocTest<OrderBloc, OrderState>(
      'DecrementCartLine is a no-op while checkout is in flight',
      build: () => OrderBloc(menuRepository, orderRepository),
      seed: () => const OrderState(cart: cart, isCheckingOut: true),
      act: (bloc) => bloc.add(const DecrementCartLine('item1')),
      expect: () => <OrderState>[],
    );

    blocTest<OrderBloc, OrderState>(
      'RemoveCartLine is a no-op while checkout is in flight',
      build: () => OrderBloc(menuRepository, orderRepository),
      seed: () => const OrderState(cart: cart, isCheckingOut: true),
      act: (bloc) => bloc.add(const RemoveCartLine('item1')),
      expect: () => <OrderState>[],
    );
  });

  group('CheckoutRequested', () {
    const cart = [
      CartLine(
        menuItemId: 'item1',
        name: 'Coffee',
        priceCents: 350,
        quantity: 2,
      ),
    ];
    final order = core.Order(
      id: 'order1',
      lineItems: const [
        core.OrderLineItem(
          menuItemId: 'item1',
          name: 'Coffee',
          priceCents: 350,
          quantity: 2,
        ),
      ],
      totalCents: 700,
      createdByUid: 'uid1',
      createdByEmail: 'staff@pos.test',
      createdAt: now,
    );

    blocTest<OrderBloc, OrderState>(
      'clears the cart and drops the request id on success',
      setUp: () {
        when(
          () => orderRepository.createOrder(
            requestId: any(named: 'requestId'),
            lineItems: any(named: 'lineItems'),
            createdByUid: any(named: 'createdByUid'),
            createdByEmail: any(named: 'createdByEmail'),
          ),
        ).thenAnswer((_) async => Right(order));
      },
      build: () => OrderBloc(menuRepository, orderRepository),
      seed: () => const OrderState(cart: cart),
      act: (bloc) => bloc.add(
        const CheckoutRequested(
          createdByUid: 'uid1',
          createdByEmail: 'staff@pos.test',
        ),
      ),
      expect: () => [
        const OrderState(cart: cart, isCheckingOut: true),
        const OrderState(),
      ],
    );

    blocTest<OrderBloc, OrderState>(
      'preserves the cart and reuses the same request id on a retry after '
      'failure',
      setUp: () {
        when(
          () => orderRepository.createOrder(
            requestId: any(named: 'requestId'),
            lineItems: any(named: 'lineItems'),
            createdByUid: any(named: 'createdByUid'),
            createdByEmail: any(named: 'createdByEmail'),
          ),
        ).thenAnswer((_) async => const Left(core.NetworkFailure()));
      },
      build: () => OrderBloc(menuRepository, orderRepository),
      seed: () => const OrderState(cart: cart),
      act: (bloc) {
        bloc.add(
          const CheckoutRequested(
            createdByUid: 'uid1',
            createdByEmail: 'staff@pos.test',
          ),
        );
        bloc.add(
          const CheckoutRequested(
            createdByUid: 'uid1',
            createdByEmail: 'staff@pos.test',
          ),
        );
      },
      expect: () => [
        const OrderState(cart: cart, isCheckingOut: true),
        const OrderState(cart: cart, failure: core.NetworkFailure()),
        const OrderState(cart: cart, isCheckingOut: true),
        const OrderState(cart: cart, failure: core.NetworkFailure()),
      ],
      verify: (_) {
        final captured = verify(
          () => orderRepository.createOrder(
            requestId: captureAny(named: 'requestId'),
            lineItems: any(named: 'lineItems'),
            createdByUid: any(named: 'createdByUid'),
            createdByEmail: any(named: 'createdByEmail'),
          ),
        ).captured;
        expect(captured, hasLength(2));
        expect(captured[0], captured[1]);
      },
    );
  });
}
