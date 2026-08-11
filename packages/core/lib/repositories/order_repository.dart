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
  /// [requestId] identifies this checkout attempt, not this order: the
  /// caller generates it once and reuses the same value across retries of
  /// the same attempt (e.g. after an ambiguous network failure), so
  /// retrying can't create a second order or double-decrement stock. A
  /// genuinely new checkout (a different cart) must pass a fresh id.
  Future<Either<Failure, Order>> createOrder({
    required String requestId,
    required List<OrderLineItem> lineItems,
    required String createdByUid,
    required String createdByEmail,
  });
}
