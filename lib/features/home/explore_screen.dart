import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../widgets/common.dart';
import 'discover_screen.dart' show activeJamsProvider;

/// Browse jam results without entering the participation flow.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jams = ref.watch(activeJamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Explore Results')),
      body: jams.when(
        loading: () => const LoadingView(message: 'Loading jams...'),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(activeJamsProvider),
        ),
        data: (list) {
          final visible = list.where((j) => !j.isArchived).toList();
          if (visible.isEmpty) {
            return const EmptyView(
              icon: Icons.explore_outlined,
              title: 'No jams to explore',
              subtitle: 'Jam results appear here when jams are shared with you.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(activeJamsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Text(
                  'Tap a jam to view collective voice, belief maps, and group insights.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ...visible.map(
                  (jam) => JamCard(
                    jam: jam,
                    onTap: () => context.push('/jam/${jam.id}/results'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Results',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.insights_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
