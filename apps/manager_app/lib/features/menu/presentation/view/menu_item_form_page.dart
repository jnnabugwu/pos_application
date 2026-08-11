import 'package:core/core.dart' as core;
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide MenuItem;

import '../../../../core/di/injection.dart';

/// Add/edit form for a menu item. Talks to [core.MenuRepository] directly
/// (rather than dispatching a MenuBloc event) so submit can await the
/// Either result synchronously — Bloc's `add()` is fire-and-forget, and
/// this page needs to know success (pop) vs. failure (show inline error).
class MenuItemFormPage extends StatefulWidget {
  const MenuItemFormPage({super.key, this.item});

  /// Null for "add a new item"; non-null for "edit this item".
  final core.MenuItem? item;

  @override
  State<MenuItemFormPage> createState() => _MenuItemFormPageState();
}

class _MenuItemFormPageState extends State<MenuItemFormPage> {
  late final _nameController = TextEditingController(text: widget.item?.name);
  late final _categoryController = TextEditingController(
    text: widget.item?.category,
  );
  late final _priceController = TextEditingController(
    text: widget.item == null
        ? null
        : (widget.item!.priceCents / 100).toStringAsFixed(2),
  );
  late final _stockController = TextEditingController(
    text: widget.item?.stockCount.toString(),
  );

  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.item != null;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final priceCents = ((double.tryParse(_priceController.text.trim()) ?? 0) * 100)
        .round();
    final stockCount = int.tryParse(_stockController.text.trim()) ?? 0;

    if (name.isEmpty || category.isEmpty) {
      setState(() => _error = 'Enter both a name and a category.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final repository = getIt<core.MenuRepository>();
    final result = _isEditing
        ? await repository.updateItem(
            widget.item!.copyWith(
              name: name,
              category: category,
              priceCents: priceCents,
              stockCount: stockCount,
            ),
          )
        : await repository.createItem(
            name: name,
            category: category,
            priceCents: priceCents,
            stockCount: stockCount,
          );

    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _submitting = false;
        _error = failure.message;
      }),
      (_) => context.pop(),
    );
  }

  Future<void> _delete() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await getIt<core.MenuRepository>().deleteItem(
      widget.item!.id,
    );

    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _submitting = false;
        _error = failure.message;
      }),
      (_) => context.pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: Text(_isEditing ? 'Edit item' : 'Add item'),
          leading: [
            GhostButton(
              onPressed: _submitting ? null : () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Name').textSmall.medium,
                const Gap(4),
                TextField(controller: _nameController, enabled: !_submitting),
                const Gap(16),
                const Text('Category').textSmall.medium,
                const Gap(4),
                TextField(
                  controller: _categoryController,
                  enabled: !_submitting,
                ),
                const Gap(16),
                const Text('Price (USD)').textSmall.medium,
                const Gap(4),
                TextField(
                  controller: _priceController,
                  enabled: !_submitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const Gap(16),
                const Text('Stock amount').textSmall.medium,
                const Gap(4),
                TextField(
                  controller: _stockController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                ),
                if (_error != null) ...[
                  const Gap(12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.destructive,
                    ),
                  ).textSmall,
                ],
                const Gap(24),
                PrimaryButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(
                    _submitting
                        ? 'Saving…'
                        : (_isEditing ? 'Save changes' : 'Add item'),
                  ),
                ),
                if (_isEditing) ...[
                  const Gap(12),
                  DestructiveButton(
                    onPressed: _submitting ? null : _delete,
                    child: const Text('Delete item'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
