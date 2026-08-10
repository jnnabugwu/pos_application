import 'package:core/core.dart' as core;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide MenuItem;

class MenuItemTile extends StatelessWidget {
  const MenuItemTile({super.key, required this.item, required this.onToggle});

  final core.MenuItem item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final price = (item.priceCents / 100).toStringAsFixed(2);
    return Card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name).medium,
                Text('\$$price').muted.textSmall,
              ],
            ),
          ),
          Switch(value: item.available, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}
