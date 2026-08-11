import 'package:core/core.dart' as core;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide MenuItem;

import '../bloc/order_bloc.dart';
import '../bloc/order_event.dart';
import '../bloc/order_state.dart';
import '../widgets/cart_panel.dart';
import '../widgets/order_item_tile.dart';

/// Material's medium/expanded window-size-class boundary — a well-known
/// number rather than an arbitrary pick. Phones (portrait and most
/// landscape) stay under it; tablets clear it.
const double _wideBreakpoint = 840;

class OrderPage extends StatelessWidget {
  const OrderPage({super.key});

  Map<String, List<core.MenuItem>> _groupByCategory(List<core.MenuItem> items) {
    final grouped = <String, List<core.MenuItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  void _openCartSheet(BuildContext context) {
    final orderBloc = context.read<OrderBloc>();
    openSheetOverlay(
      context: context,
      position: OverlayPosition.bottom,
      builder: (sheetContext) => BlocProvider<OrderBloc>.value(
        value: orderBloc,
        child: const SizedBox(height: 480, child: CartPanel(isSheet: true)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Order'),
          trailing: [
            GhostButton(
              onPressed: () => context.read<core.AuthBloc>().add(
                const core.SignOutRequested(),
              ),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ],
      child: BlocBuilder<OrderBloc, OrderState>(
        builder: (context, state) {
          final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
          final browser = _ItemBrowser(
            state: state,
            groupByCategory: _groupByCategory,
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: browser),
                const VerticalDivider(width: 1),
                const SizedBox(width: 360, child: CartPanel(isSheet: false)),
              ],
            );
          }

          return Stack(
            children: [
              browser,
              Positioned(
                right: 16,
                bottom: 16,
                child: PrimaryButton(
                  onPressed: () => _openCartSheet(context),
                  child: Text(
                    'Cart (${state.cart.length}) · '
                    '\$${(state.totalCents / 100).toStringAsFixed(2)}',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ItemBrowser extends StatelessWidget {
  const _ItemBrowser({required this.state, required this.groupByCategory});

  final OrderState state;
  final Map<String, List<core.MenuItem>> Function(List<core.MenuItem>)
  groupByCategory;

  @override
  Widget build(BuildContext context) {
    if (state.status == OrderStatus.loading ||
        state.status == OrderStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == OrderStatus.failure) {
      // WatchMenuStarted's emit.forEach subscription ends once it emits an
      // error, so redispatching the event (rather than anything implicit)
      // is what re-subscribes to watchMenu() and gives this a way back.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.failure?.message ?? 'Failed to load menu.'),
            const Gap(12),
            PrimaryButton(
              onPressed: () =>
                  context.read<OrderBloc>().add(const WatchMenuStarted()),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final grouped = groupByCategory(state.menuItems);
    final categories = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final items = grouped[category]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category).h4,
            const Gap(8),
            ...items.map((item) {
              final cartQuantity = state.cart
                  .where((line) => line.menuItemId == item.id)
                  .fold<int>(0, (total, line) => total + line.quantity);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OrderItemTile(
                  item: item,
                  cartQuantity: cartQuantity,
                  onAdd: () =>
                      context.read<OrderBloc>().add(AddToCart(item.id)),
                ),
              );
            }),
            const Gap(16),
          ],
        );
      },
    );
  }
}
