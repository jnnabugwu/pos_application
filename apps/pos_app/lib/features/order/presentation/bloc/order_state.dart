import 'package:core/core.dart' as core;
import 'package:equatable/equatable.dart';

import '../../domain/cart_line.dart';

enum OrderStatus { initial, loading, success, failure }

class OrderState extends Equatable {
  const OrderState({
    this.status = OrderStatus.initial,
    this.menuItems = const [],
    this.cart = const [],
    this.isCheckingOut = false,
    this.failure,
  });

  final OrderStatus status;
  final List<core.MenuItem> menuItems;
  final List<CartLine> cart;
  final bool isCheckingOut;
  final core.Failure? failure;

  int get totalCents =>
      cart.fold(0, (total, line) => total + line.lineTotalCents);

  OrderState copyWith({
    OrderStatus? status,
    List<core.MenuItem>? menuItems,
    List<CartLine>? cart,
    bool? isCheckingOut,
    core.Failure? failure,
  }) {
    return OrderState(
      status: status ?? this.status,
      menuItems: menuItems ?? this.menuItems,
      cart: cart ?? this.cart,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      // Deliberately not `failure ?? this.failure` — a fresh attempt must be
      // able to clear a stale error from a previous one.
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    menuItems,
    cart,
    isCheckingOut,
    failure,
  ];
}
