import 'package:core/core.dart' as core;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide MenuItem;

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../bloc/menu_bloc.dart';
import '../bloc/menu_event.dart';
import '../bloc/menu_state.dart';
import '../widgets/menu_item_tile.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  Map<String, List<core.MenuItem>> _groupByCategory(List<core.MenuItem> items) {
    final grouped = <String, List<core.MenuItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Expanded(child: Text('Menu')),
              GhostButton(
                onPressed: () =>
                    context.read<AuthBloc>().add(const SignOutRequested()),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ],
      child: BlocBuilder<MenuBloc, MenuState>(
        builder: (context, state) {
          if (state.status == MenuStatus.loading ||
              state.status == MenuStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == MenuStatus.failure) {
            return Center(
              child: Text(state.failure?.message ?? 'Failed to load menu.'),
            );
          }

          final grouped = _groupByCategory(state.items);
          final categories = grouped.keys.toList();
          final isAdmin =
              context.watch<AuthBloc>().state.user?.role == core.AppRole.admin;

          return Column(
            children: [
              if (state.failure != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    state.failure!.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.destructive,
                    ),
                  ).textSmall,
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final items = grouped[category]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category).h4,
                        const Gap(8),
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: MenuItemTile(
                              item: item,
                              enabled: isAdmin,
                              onToggle: () => context.read<MenuBloc>().add(
                                ToggleAvailability(item.id),
                              ),
                            ),
                          ),
                        ),
                        const Gap(16),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
