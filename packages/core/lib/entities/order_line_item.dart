import 'package:equatable/equatable.dart';

/// A single line on an [Order]. `name`/`priceCents` are snapshots of the
/// [MenuItem] at the time it was added to the cart — deliberately not a live
/// reference, so a historical order doesn't shift if the menu item is later
/// edited or deleted.
class OrderLineItem extends Equatable {
  final String menuItemId;
  final String name;
  final int priceCents;
  final int quantity;

  const OrderLineItem({
    required this.menuItemId,
    required this.name,
    required this.priceCents,
    required this.quantity,
  });

  int get lineTotalCents => priceCents * quantity;

  factory OrderLineItem.fromMap(Map<String, dynamic> map) {
    return OrderLineItem(
      menuItemId: map['menuItemId'] as String,
      name: map['name'] as String,
      priceCents: map['priceCents'] as int,
      quantity: map['quantity'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'priceCents': priceCents,
      'quantity': quantity,
    };
  }

  @override
  List<Object?> get props => [menuItemId, name, priceCents, quantity];
}
