import 'package:core/entities/order_line_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final map = {
    'menuItemId': 'item-1',
    'name': 'Latte',
    'priceCents': 450,
    'quantity': 2,
  };
  const lineItem = OrderLineItem(
    menuItemId: 'item-1',
    name: 'Latte',
    priceCents: 450,
    quantity: 2,
  );

  test('fromMap builds an OrderLineItem from a Firestore-shaped map', () {
    expect(OrderLineItem.fromMap(map), lineItem);
  });

  test('toMap round-trips back to the original map', () {
    expect(lineItem.toMap(), map);
  });

  test('lineTotalCents multiplies price by quantity', () {
    expect(lineItem.lineTotalCents, 900);
  });

  test('two line items with the same fields are equal', () {
    expect(
      const OrderLineItem(
        menuItemId: 'item-1',
        name: 'Latte',
        priceCents: 450,
        quantity: 2,
      ),
      lineItem,
    );
  });

  test('line items differing by quantity are not equal', () {
    const other = OrderLineItem(
      menuItemId: 'item-1',
      name: 'Latte',
      priceCents: 450,
      quantity: 3,
    );
    expect(other, isNot(lineItem));
  });
}
