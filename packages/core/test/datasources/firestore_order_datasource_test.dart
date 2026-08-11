import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:core/datasources/firestore_order_datasource.dart';
import 'package:core/entities/order.dart';
import 'package:core/entities/order_line_item.dart';
import 'package:core/failures/failure.dart';
import 'package:dartz/dartz.dart' hide Order;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/mock_firestore.dart';

Order _asOrder(Either<Failure, Order> result) => (result as Right).value;

void main() {
  setUpAll(registerFirestoreFallbackValues);

  group('happy paths (fake_cloud_firestore)', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreOrderDataSource datasource;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      datasource = FirestoreOrderDataSource(firestore);
    });

    Future<void> seedMenuItem(String id, {required int stockCount}) {
      final now = Timestamp.fromDate(DateTime(2026, 1, 1));
      return firestore.collection('menuItems').doc(id).set({
        'name': 'Item $id',
        'priceCents': 100,
        'category': 'Drinks',
        'available': true,
        'stockCount': stockCount,
        'createdAt': now,
        'updatedAt': now,
      });
    }

    test(
      'writes an order doc and decrements stock for each line item',
      () async {
        await seedMenuItem('item-1', stockCount: 10);
        await seedMenuItem('item-2', stockCount: 5);

        final result = await datasource.createOrder(
          lineItems: const [
            OrderLineItem(
              menuItemId: 'item-1',
              name: 'Latte',
              priceCents: 450,
              quantity: 2,
            ),
            OrderLineItem(
              menuItemId: 'item-2',
              name: 'Bagel',
              priceCents: 275,
              quantity: 1,
            ),
          ],
          createdByUid: 'uid-1',
          createdByEmail: 'staff@pos.test',
        );

        final order = _asOrder(result);
        expect(order.id, isNotEmpty);
        expect(order.totalCents, 1175);
        expect(order.lineItems, hasLength(2));

        final storedOrder = await firestore
            .collection('orders')
            .doc(order.id)
            .get();
        expect(storedOrder.exists, true);
        expect(storedOrder.data()!['totalCents'], 1175);

        final item1 = await firestore.collection('menuItems').doc('item-1').get();
        expect(item1.data()!['stockCount'], 8);
        final item2 = await firestore.collection('menuItems').doc('item-2').get();
        expect(item2.data()!['stockCount'], 4);
      },
    );

    test('clamps stock at 0 rather than going negative', () async {
      await seedMenuItem('item-1', stockCount: 1);

      await datasource.createOrder(
        lineItems: const [
          OrderLineItem(
            menuItemId: 'item-1',
            name: 'Latte',
            priceCents: 450,
            quantity: 5,
          ),
        ],
        createdByUid: 'uid-1',
        createdByEmail: 'staff@pos.test',
      );

      final item1 = await firestore.collection('menuItems').doc('item-1').get();
      expect(item1.data()!['stockCount'], 0);
    });

    test(
      'coalesces duplicate line items for the same menu item id',
      () async {
        await seedMenuItem('item-1', stockCount: 10);

        await datasource.createOrder(
          lineItems: const [
            OrderLineItem(
              menuItemId: 'item-1',
              name: 'Latte',
              priceCents: 450,
              quantity: 1,
            ),
            OrderLineItem(
              menuItemId: 'item-1',
              name: 'Latte',
              priceCents: 450,
              quantity: 2,
            ),
          ],
          createdByUid: 'uid-1',
          createdByEmail: 'staff@pos.test',
        );

        final item1 = await firestore.collection('menuItems').doc('item-1').get();
        expect(item1.data()!['stockCount'], 7);
      },
    );

    test('rejects an empty cart without touching Firestore', () async {
      final result = await datasource.createOrder(
        lineItems: const [],
        createdByUid: 'uid-1',
        createdByEmail: 'staff@pos.test',
      );

      expect(result, isA<Left>());
      expect((result as Left).value, isA<UnknownFailure>());
      expect((await firestore.collection('orders').get()).docs, isEmpty);
    });
  });

  group('failure paths (mocktail)', () {
    late MockFirebaseFirestore firestore;
    late MockCollectionReference menuItemsCollection;
    late MockCollectionReference ordersCollection;
    late MockDocumentReference menuDocRef;
    late MockDocumentReference orderDocRef;
    late FirestoreOrderDataSource datasource;

    setUp(() {
      firestore = MockFirebaseFirestore();
      menuItemsCollection = MockCollectionReference();
      ordersCollection = MockCollectionReference();
      menuDocRef = MockDocumentReference();
      orderDocRef = MockDocumentReference();
      datasource = FirestoreOrderDataSource(firestore);

      when(
        () => firestore.collection('menuItems'),
      ).thenReturn(menuItemsCollection);
      when(() => firestore.collection('orders')).thenReturn(ordersCollection);
      when(() => menuItemsCollection.doc(any())).thenReturn(menuDocRef);
      when(() => ordersCollection.doc()).thenReturn(orderDocRef);
      when(() => orderDocRef.id).thenReturn('mock-order-id');
    });

    test(
      'maps a FirebaseException thrown mid-transaction to a typed Failure',
      () async {
        when(() => firestore.runTransaction<void>(any())).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );

        final result = await datasource.createOrder(
          lineItems: const [
            OrderLineItem(
              menuItemId: 'item-1',
              name: 'Latte',
              priceCents: 450,
              quantity: 1,
            ),
          ],
          createdByUid: 'uid-1',
          createdByEmail: 'staff@pos.test',
        );

        expect(result, const Left(PermissionFailure()));
      },
    );

    test('maps a non-Firebase error to UnknownFailure', () async {
      when(
        () => firestore.runTransaction<void>(any()),
      ).thenThrow(StateError('boom'));

      final result = await datasource.createOrder(
        lineItems: const [
          OrderLineItem(
            menuItemId: 'item-1',
            name: 'Latte',
            priceCents: 450,
            quantity: 1,
          ),
        ],
        createdByUid: 'uid-1',
        createdByEmail: 'staff@pos.test',
      );

      expect(result, isA<Left>());
      expect((result as Left).value, isA<UnknownFailure>());
    });
  });
}
