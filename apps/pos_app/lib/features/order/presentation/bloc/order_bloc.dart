import 'dart:math';

import 'package:core/core.dart' as core;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/cart_line.dart';
import 'order_event.dart';
import 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  OrderBloc(this._menuRepository, this._orderRepository)
    : super(const OrderState()) {
    on<WatchMenuStarted>(_onWatchMenuStarted);
    on<AddToCart>(_onAddToCart);
    on<DecrementCartLine>(_onDecrementCartLine);
    on<RemoveCartLine>(_onRemoveCartLine);
    on<CheckoutRequested>(_onCheckoutRequested);
  }

  final core.MenuRepository _menuRepository;
  final core.OrderRepository _orderRepository;
  static final Random _random = Random.secure();

  // Stable across retries of the same checkout attempt (cleared once it
  // succeeds), so tapping Checkout again after an ambiguous failure reuses
  // the same request rather than risking a duplicate order.
  String? _checkoutRequestId;

  static String _generateRequestId() => List.generate(
    16,
    (_) => _random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  Future<void> _onWatchMenuStarted(
    WatchMenuStarted event,
    Emitter<OrderState> emit,
  ) async {
    emit(state.copyWith(status: OrderStatus.loading));
    await emit.forEach<List<core.MenuItem>>(
      _menuRepository.watchMenu(),
      onData: (items) =>
          state.copyWith(status: OrderStatus.success, menuItems: items),
      onError: (error, stackTrace) => state.copyWith(
        status: OrderStatus.failure,
        failure: core.UnknownFailure(error.toString()),
      ),
    );
  }

  void _onAddToCart(AddToCart event, Emitter<OrderState> emit) {
    core.MenuItem? item;
    for (final candidate in state.menuItems) {
      if (candidate.id == event.menuItemId) {
        item = candidate;
        break;
      }
    }
    // The cart snapshot mid-checkout is what's already been sent to
    // createOrder(); mutating it now would silently diverge from what's
    // about to be (or already was) written, so ignore edits until it
    // resolves.
    if (item == null || !item.available || state.isCheckingOut) return;

    final existingIndex = state.cart.indexWhere(
      (line) => line.menuItemId == item!.id,
    );
    final currentQuantity = existingIndex == -1
        ? 0
        : state.cart[existingIndex].quantity;
    // Guards a stale tap racing a live update (e.g. another register just
    // sold out the last unit, or an admin just marked it unavailable) and
    // caps additions at the remaining stock, so the cart can't already hold
    // more of an item than is actually available (mirrors the remaining
    // stock check in OrderItemTile).
    if (currentQuantity >= item.stockCount) return;

    final newCart = [...state.cart];
    if (existingIndex == -1) {
      newCart.add(
        CartLine(
          menuItemId: item.id,
          name: item.name,
          priceCents: item.priceCents,
          quantity: 1,
        ),
      );
    } else {
      newCart[existingIndex] = newCart[existingIndex].copyWith(
        quantity: newCart[existingIndex].quantity + 1,
      );
    }
    emit(state.copyWith(cart: newCart));
  }

  void _onDecrementCartLine(DecrementCartLine event, Emitter<OrderState> emit) {
    if (state.isCheckingOut) return;
    final index = state.cart.indexWhere(
      (line) => line.menuItemId == event.menuItemId,
    );
    if (index == -1) return;

    final line = state.cart[index];
    final newCart = [...state.cart];
    if (line.quantity - 1 <= 0) {
      newCart.removeAt(index);
    } else {
      newCart[index] = line.copyWith(quantity: line.quantity - 1);
    }
    emit(state.copyWith(cart: newCart));
  }

  void _onRemoveCartLine(RemoveCartLine event, Emitter<OrderState> emit) {
    if (state.isCheckingOut) return;
    emit(
      state.copyWith(
        cart: [
          for (final line in state.cart)
            if (line.menuItemId != event.menuItemId) line,
        ],
      ),
    );
  }

  Future<void> _onCheckoutRequested(
    CheckoutRequested event,
    Emitter<OrderState> emit,
  ) async {
    if (state.cart.isEmpty || state.isCheckingOut) return;

    final requestId = _checkoutRequestId ??= _generateRequestId();
    emit(state.copyWith(isCheckingOut: true, failure: null));
    final result = await _orderRepository.createOrder(
      requestId: requestId,
      lineItems: [for (final line in state.cart) line.toOrderLineItem()],
      createdByUid: event.createdByUid,
      createdByEmail: event.createdByEmail,
    );
    result.fold(
      (failure) => emit(state.copyWith(isCheckingOut: false, failure: failure)),
      // Cart is preserved on failure, so a network blip doesn't destroy a
      // half-built order; cleared only once checkout actually succeeds.
      (_) {
        _checkoutRequestId = null;
        emit(state.copyWith(isCheckingOut: false, cart: const []));
      },
    );
  }
}
