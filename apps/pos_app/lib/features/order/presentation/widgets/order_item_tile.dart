import 'package:core/core.dart' as core;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide MenuItem;

class OrderItemTile extends StatelessWidget {
  const OrderItemTile({
    super.key,
    required this.item,
    required this.cartQuantity,
    required this.onAdd,
  });

  final core.MenuItem item;
  final int cartQuantity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final remainingStock = item.stockCount - cartQuantity;
    final isOrderable = item.available && remainingStock > 0;
    final price = (item.priceCents / 100).toStringAsFixed(2);

    final card = Opacity(
      opacity: isOrderable ? 1.0 : 0.4,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name).medium,
              Text('\$$price').muted.textSmall,
              if (!item.available)
                const Text('Unavailable').muted.textSmall
              else if (item.stockCount <= 0)
                const Text('Sold out').muted.textSmall
              else if (cartQuantity > 0)
                Text('$cartQuantity in cart').muted.textSmall,
            ],
          ),
        ),
      ),
    );

    return Clickable(
      enabled: isOrderable,
      onPressed: isOrderable ? onAdd : null,
      child: card,
    );
  }
}
