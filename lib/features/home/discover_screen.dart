import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/common.dart';
import '../auth/auth_controller.dart';

final activeJamsProvider = FutureProvider.autoDispose<List<Jam>>((ref) {
  final session = ref.watch(authControllerProvider).session;
  return ref
      .watch(repositoryProvider)
      .fetchActiveJams(userId: session?.isGuest == false ? session?.userId : null);
});

/// Public/active jam discovery.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jams = ref.watch(activeJamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Discover Jams')),
      body: jams.when(
        loading: () => const LoadingView(message: 'Finding active jams...'),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(activeJamsProvider),
        ),
        data: (list) {
          final visible = list.where((j) => !j.isArchived).toList();
          if (visible.isEmpty) {
            return const EmptyView(
              icon: Icons.explore_outlined,
              title: 'No active jams',
              subtitle: 'Jams shared with you or your community appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(activeJamsProvider),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: visible.map((jam) => JamCard(jam: jam)).toList(),
            ),
          );
        },
      ),
    );
  }
}
