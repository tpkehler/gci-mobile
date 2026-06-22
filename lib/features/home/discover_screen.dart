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

/// Jams open for participation (excludes jams the user created).
final participateJamsProvider = FutureProvider.autoDispose<List<Jam>>((ref) {
  final session = ref.watch(authControllerProvider).session;
  final userId = session?.isGuest == false ? session?.userId : null;
  return ref.watch(activeJamsProvider.future).then((jams) {
    if (userId == null) return jams.where((j) => !j.isArchived).toList();
    return jams
        .where((j) => !j.isArchived && j.creatorId != userId)
        .toList();
  });
});

/// Jams the user can join and participate in.
class ParticipateScreen extends ConsumerWidget {
  const ParticipateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jams = ref.watch(participateJamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Contribute')),
      body: jams.when(
        loading: () => const LoadingView(message: 'Finding jams...'),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(participateJamsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.how_to_reg_outlined,
              title: 'Nothing to join yet',
              subtitle:
                  'Invited jams and public jams you can contribute to appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeJamsProvider);
              ref.invalidate(participateJamsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Text(
                  'Join a jam, discuss ideas, and share your predictions.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ...list.map((jam) => JamCard(jam: jam)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// @deprecated use [ParticipateScreen]
typedef DiscoverScreen = ParticipateScreen;
