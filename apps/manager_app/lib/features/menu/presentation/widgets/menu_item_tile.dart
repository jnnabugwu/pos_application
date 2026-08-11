import 'package:core/core.dart' as core;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide MenuItem;

class MenuItemTile extends StatelessWidget {
  const MenuItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    this.onTap,
    this.enabled = true,
  });

  final core.MenuItem item;
  final VoidCallback onToggle;

  /// Opens the edit form. Null (and the tile stays inert to taps) for
  /// non-admins — only the availability [Switch] stays interactive for them.
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final price = (item.priceCents / 100).toStringAsFixed(2);
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name).medium,
                  Text('\$$price').muted.textSmall,
                  Text('${item.stockCount} in stock').muted.textSmall,
                ],
              ),
            ),
            Switch(
              value: item.available,
              onChanged: enabled ? (_) => onToggle() : null,
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return Clickable(onPressed: onTap, child: card);
  }
}
