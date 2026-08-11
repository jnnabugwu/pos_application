import 'package:core/core.dart' as core;
import 'package:equatable/equatable.dart';

/// A line on the local running tab. `name`/`priceCents` are snapshots taken
/// when the item was added — deliberately distinct from `core.OrderLineItem`
/// (that's the persisted domain shape; this is transient UI state, and
/// coupling the two would ripple app-local cart mechanics into core, or
/// core persistence concerns into the cart, for no shared reason).
class CartLine extends Equatable {
  const CartLine({
    required this.menuItemId,
    required this.name,
    required this.priceCents,
    required this.quantity,
  });

  final String menuItemId;
  final String name;
  final int priceCents;
  final int quantity;

  int get lineTotalCents => priceCents * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(
      menuItemId: menuItemId,
      name: name,
      priceCents: priceCents,
      quantity: quantity ?? this.quantity,
    );
  }

  core.OrderLineItem toOrderLineItem() {
    return core.OrderLineItem(
      menuItemId: menuItemId,
      name: name,
      priceCents: priceCents,
      quantity: quantity,
    );
  }

  @override
  List<Object?> get props => [menuItemId, name, priceCents, quantity];
}
