import 'package:core/entities/menu_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime(2026, 1, 1, 9);
  final updatedAt = DateTime(2026, 1, 2, 10);
  final map = {
    'name': 'Latte',
    'priceCents': 450,
    'category': 'Drinks',
    'available': true,
    'stockCount': 12,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
  final item = MenuItem(
    id: 'item-1',
    name: 'Latte',
    priceCents: 450,
    category: 'Drinks',
    available: true,
    stockCount: 12,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  test('fromMap builds a MenuItem from a Firestore-shaped map', () {
    expect(MenuItem.fromMap('item-1', map), item);
  });

  test('fromMap defaults stockCount to 0 when absent from the map', () {
    final legacyMap = {...map}..remove('stockCount');
    expect(MenuItem.fromMap('item-1', legacyMap).stockCount, 0);
  });

  test('toMap round-trips back to the original map', () {
    expect(item.toMap(), map);
  });

  group('copyWith', () {
    test(
      'with no arguments returns an equal item (id/createdAt always kept)',
      () {
        final copy = item.copyWith();
        expect(copy, item);
        expect(copy.id, item.id);
        expect(copy.createdAt, item.createdAt);
      },
    );

    test('with arguments overrides only the given fields', () {
      final copy = item.copyWith(
        name: 'Mocha',
        priceCents: 500,
        category: 'Hot Drinks',
        available: false,
        stockCount: 5,
        updatedAt: updatedAt.add(const Duration(minutes: 1)),
      );
      expect(copy.id, item.id);
      expect(copy.name, 'Mocha');
      expect(copy.priceCents, 500);
      expect(copy.category, 'Hot Drinks');
      expect(copy.available, false);
      expect(copy.stockCount, 5);
      expect(copy.createdAt, item.createdAt);
      expect(copy.updatedAt, updatedAt.add(const Duration(minutes: 1)));
    });
  });

  test('two items with the same fields are equal', () {
    expect(
      MenuItem(
        id: 'item-1',
        name: 'Latte',
        priceCents: 450,
        category: 'Drinks',
        available: true,
        stockCount: 12,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      item,
    );
  });

  test('items differing by availability are not equal', () {
    expect(item.copyWith(available: false), isNot(item));
  });

  test('items differing by stockCount are not equal', () {
    expect(item.copyWith(stockCount: 0), isNot(item));
  });
}
