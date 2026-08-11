import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../domain/cart_line.dart';

class CartLineTile extends StatelessWidget {
  const CartLineTile({
    super.key,
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartLine line;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final lineTotal = (line.lineTotalCents / 100).toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name).medium,
                Text('\$$lineTotal').muted.textSmall,
              ],
            ),
          ),
          GhostButton(onPressed: onDecrement, child: const Text('−')),
          Text('${line.quantity}'),
          GhostButton(onPressed: onIncrement, child: const Text('+')),
          GhostButton(onPressed: onRemove, child: const Text('Remove')),
        ],
      ),
    );
  }
}
