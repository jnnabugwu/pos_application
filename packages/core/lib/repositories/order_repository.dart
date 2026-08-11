import 'package:dartz/dartz.dart' hide Order;

import '../entities/order.dart';
import '../entities/order_line_item.dart';
import '../failures/failure.dart';

/// Contract for checking out a running tab.
///
/// Deliberately has no `watchOrders()`/`getOrder()` yet — nothing in this
/// app reads orders back (no receipt, no order history screen). Add one
/// when a real reader shows up rather than speculatively now.
abstract class OrderRepository {
  Future<Either<Failure, Order>> createOrder({
    required List<OrderLineItem> lineItems,
    required String createdByUid,
    required String createdByEmail,
  });
}
