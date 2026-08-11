import 'package:core/entities/order.dart';
import 'package:core/entities/order_line_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime(2026, 1, 1, 12);
  final lineItems = [
    const OrderLineItem(
      menuItemId: 'item-1',
      name: 'Latte',
      priceCents: 450,
      quantity: 2,
    ),
    const OrderLineItem(
      menuItemId: 'item-2',
      name: 'Bagel',
      priceCents: 275,
      quantity: 1,
    ),
  ];
  final map = {
    'lineItems': [for (final line in lineItems) line.toMap()],
    'totalCents': 1175,
    'createdByUid': 'uid-1',
    'createdByEmail': 'staff@pos.test',
    'createdAt': createdAt,
  };
  final order = Order(
    id: 'order-1',
    lineItems: lineItems,
    totalCents: 1175,
    createdByUid: 'uid-1',
    createdByEmail: 'staff@pos.test',
    createdAt: createdAt,
  );

  test('fromMap builds an Order from a Firestore-shaped map', () {
    expect(Order.fromMap('order-1', map), order);
  });

  test(
    'fromMap decodes nested line-item maps even as Map<Object?, Object?>',
    () {
      final looseMap = {
        ...map,
        'lineItems': [
          for (final line in lineItems) Map<Object?, Object?>.from(line.toMap()),
        ],
      };
      expect(Order.fromMap('order-1', looseMap), order);
    },
  );

  test('toMap round-trips back to the original map', () {
    expect(order.toMap(), map);
  });

  test('two orders with the same fields are equal', () {
    expect(
      Order(
        id: 'order-1',
        lineItems: lineItems,
        totalCents: 1175,
        createdByUid: 'uid-1',
        createdByEmail: 'staff@pos.test',
        createdAt: createdAt,
      ),
      order,
    );
  });

  test('orders differing by totalCents are not equal', () {
    final other = Order(
      id: 'order-1',
      lineItems: lineItems,
      totalCents: 999,
      createdByUid: 'uid-1',
      createdByEmail: 'staff@pos.test',
      createdAt: createdAt,
    );
    expect(other, isNot(order));
  });
}
