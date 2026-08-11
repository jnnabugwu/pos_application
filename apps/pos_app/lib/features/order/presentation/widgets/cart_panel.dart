import 'package:core/core.dart' as core;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../bloc/order_bloc.dart';
import '../bloc/order_event.dart';
import '../bloc/order_state.dart';
import 'cart_line_tile.dart';

/// Shared between the wide two-pane layout (embedded, [isSheet]: false) and
/// the narrow layout's bottom sheet (isSheet: true).
class CartPanel extends StatelessWidget {
  const CartPanel({super.key, required this.isSheet});

  final bool isSheet;

  void _checkout(BuildContext context) {
    final user = context.read<core.AuthBloc>().state.user;
    if (user == null) return; // routing already gates unauthenticated users
    context.read<OrderBloc>().add(
      CheckoutRequested(createdByUid: user.uid, createdByEmail: user.email),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrderBloc, OrderState>(
      listenWhen: (previous, current) =>
          previous.isCheckingOut &&
          !current.isCheckingOut &&
          current.failure == null,
      listener: (context, state) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: const Text('Order placed'),
            ),
          ),
        );
        if (isSheet) closeSheet(context);
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('Current order').h4,
                  const Spacer(),
                  if (isSheet)
                    GhostButton(
                      onPressed: () => closeSheet(context),
                      child: const Text('Close'),
                    ),
                ],
              ),
              const Gap(12),
              Expanded(
                child: state.cart.isEmpty
                    ? const Center(child: Text('No items yet'))
                    : ListView(
                        children: [
                          for (final line in state.cart)
                            CartLineTile(
                              line: line,
                              onIncrement: state.isCheckingOut
                                  ? null
                                  : () => context.read<OrderBloc>().add(
                                      AddToCart(line.menuItemId),
                                    ),
                              onDecrement: state.isCheckingOut
                                  ? null
                                  : () => context.read<OrderBloc>().add(
                                      DecrementCartLine(line.menuItemId),
                                    ),
                              onRemove: state.isCheckingOut
                                  ? null
                                  : () => context.read<OrderBloc>().add(
                                      RemoveCartLine(line.menuItemId),
                                    ),
                            ),
                        ],
                      ),
              ),
              const Divider(),
              Row(
                children: [
                  const Text('Total').h4,
                  const Spacer(),
                  Text('\$${(state.totalCents / 100).toStringAsFixed(2)}').h4,
                ],
              ),
              if (state.failure != null) ...[
                const Gap(8),
                Text(
                  state.failure!.message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.destructive,
                  ),
                ).textSmall,
              ],
              const Gap(12),
              PrimaryButton(
                onPressed: (state.cart.isEmpty || state.isCheckingOut)
                    ? null
                    : () => _checkout(context),
                child: Text(
                  state.isCheckingOut ? 'Placing order…' : 'Checkout',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
