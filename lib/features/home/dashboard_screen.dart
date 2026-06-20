import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/common.dart';
import '../auth/auth_controller.dart';

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) {
  final session = ref.watch(authControllerProvider).session;
  if (session == null || session.isGuest) {
    return const DashboardData(createdJams: [], contributingJams: []);
  }
  return ref.watch(repositoryProvider).fetchDashboard(session.userId);
});

/// Jams the user created — track collective results.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showArchived = false;

  Future<void> _toggleArchive(Jam jam) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final repo = ref.read(repositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (jam.isArchived) {
        await repo.restoreJam(jam.id, session.userId);
        messenger.showSnackBar(const SnackBar(content: Text('Jam restored')));
      } else {
        await repo.archiveJam(jam.id, session.userId);
        messenger.showSnackBar(const SnackBar(content: Text('Jam archived')));
      }
      ref.invalidate(dashboardProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Jams'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Hide archived' : 'Show archived',
            icon: Icon(_showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create Jam'),
      ),
      body: dashboard.when(
        loading: () => const LoadingView(message: 'Loading your jams...'),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (data) {
          final created = data.createdJams
              .where((j) => _showArchived || !j.isArchived)
              .toList();
          if (created.isEmpty) {
            return const EmptyView(
              icon: Icons.lightbulb_outline,
              title: 'No jams yet',
              subtitle:
                  'Create a jam to facilitate a group and track collective results.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Text(
                  'Jams you created — tap to track collective intelligence results.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ...created.map(
                  (jam) => JamCard(
                    jam: jam,
                    onTap: () => context.push('/jam/${jam.id}/results'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(jam.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined),
                          tooltip: jam.isArchived ? 'Restore' : 'Archive',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _toggleArchive(jam),
                        ),
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
