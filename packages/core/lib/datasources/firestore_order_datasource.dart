import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:dartz/dartz.dart' hide Order;

import '../entities/order.dart';
import '../entities/order_line_item.dart';
import '../failures/failure.dart';
import '../failures/firebase_failure_mapper.dart';
import '../repositories/order_repository.dart';

/// Firestore-backed implementation of [OrderRepository].
///
/// Writes the order doc and decrements each ordered item's `stockCount` in
/// one transaction, so two staff checking out concurrently against the same
/// item can't race each other into an inconsistent stock count. Stock is
/// clamped at 0 rather than the checkout failing outright on an oversell —
/// checkout here represents a sale that's already happened (no payment
/// gate, no reservation step), so refusing to record it because inventory
/// bookkeeping is behind reality would be worse than just letting it
/// through and showing 0 remaining.
class FirestoreOrderDataSource implements OrderRepository {
  FirestoreOrderDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');
  CollectionReference<Map<String, dynamic>> get _menuItems =>
      _firestore.collection('menuItems');

  @override
  Future<Either<Failure, Order>> createOrder({
    required List<OrderLineItem> lineItems,
    required String createdByUid,
    required String createdByEmail,
  }) async {
    if (lineItems.isEmpty) {
      return const Left(
        UnknownFailure('Cannot create an order with no items.'),
      );
    }
    try {
      final orderRef = _orders.doc();
      final now = DateTime.now();
      final totalCents = lineItems.fold<int>(
        0,
        (total, line) => total + line.lineTotalCents,
      );
      final order = Order(
        id: orderRef.id,
        lineItems: lineItems,
        totalCents: totalCents,
        createdByUid: createdByUid,
        createdByEmail: createdByEmail,
        createdAt: now,
      );

      // Coalesce by menuItemId so each distinct item's stock is decremented
      // exactly once, even if the caller ever passed duplicate lines for
      // the same item (the cart is expected to already be deduplicated —
      // this is a safety net, since reading+writing the same
      // DocumentReference twice in one transaction would double-count it).
      final quantityByItemId = <String, int>{};
      for (final line in lineItems) {
        quantityByItemId.update(
          line.menuItemId,
          (quantity) => quantity + line.quantity,
          ifAbsent: () => line.quantity,
        );
      }
      final itemIds = quantityByItemId.keys.toList();
      final menuRefs = [for (final id in itemIds) _menuItems.doc(id)];

      await _firestore.runTransaction<void>((transaction) async {
        // All reads before any writes — a hard transaction requirement.
        final snapshots = [
          for (final ref in menuRefs) await transaction.get(ref),
        ];

        for (var i = 0; i < menuRefs.length; i++) {
          final snapshot = snapshots[i];
          if (!snapshot.exists) continue; // item deleted since being added
          final currentStock = snapshot.data()?['stockCount'] as int? ?? 0;
          final requested = quantityByItemId[itemIds[i]]!;
          final newStock = currentStock - requested < 0
              ? 0
              : currentStock - requested;
          transaction.update(menuRefs[i], {
            'stockCount': newStock,
            'updatedAt': now,
          });
        }

        transaction.set(orderRef, order.toMap());
      });

      return Right(order);
    } on FirebaseException catch (e) {
      return Left(mapFirebaseException(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
