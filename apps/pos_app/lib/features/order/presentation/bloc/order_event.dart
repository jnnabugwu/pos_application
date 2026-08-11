import 'package:equatable/equatable.dart';

sealed class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object?> get props => [];
}

class WatchMenuStarted extends OrderEvent {
  const WatchMenuStarted();
}

class AddToCart extends OrderEvent {
  const AddToCart(this.menuItemId);

  final String menuItemId;

  @override
  List<Object?> get props => [menuItemId];
}

class DecrementCartLine extends OrderEvent {
  const DecrementCartLine(this.menuItemId);

  final String menuItemId;

  @override
  List<Object?> get props => [menuItemId];
}

class RemoveCartLine extends OrderEvent {
  const RemoveCartLine(this.menuItemId);

  final String menuItemId;

  @override
  List<Object?> get props => [menuItemId];
}

class CheckoutRequested extends OrderEvent {
  const CheckoutRequested({
    required this.createdByUid,
    required this.createdByEmail,
  });

  final String createdByUid;
  final String createdByEmail;

  @override
  List<Object?> get props => [createdByUid, createdByEmail];
}
