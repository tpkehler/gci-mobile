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

/// "My Jams": created + contributing, with archive management for creators.
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
          final contributing = data.contributingJams
              .where((j) => !j.isArchived)
              .toList();
          if (created.isEmpty && contributing.isEmpty) {
            return const EmptyView(
              icon: Icons.lightbulb_outline,
              title: 'No jams yet',
              subtitle:
                  'Create a jam or join one from an invitation to get started.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardProvider),
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              children: [
                if (created.isNotEmpty) ...[
                  const _SectionHeader('Created by you'),
                  ...created.map((jam) => JamCard(
                        jam: jam,
                        trailing: IconButton(
                          icon: Icon(jam.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined),
                          tooltip: jam.isArchived ? 'Restore' : 'Archive',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _toggleArchive(jam),
                        ),
                      )),
                ],
                if (contributing.isNotEmpty) ...[
                  const _SectionHeader('Contributing'),
                  ...contributing.map((jam) => JamCard(jam: jam)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).hintColor)),
    );
  }
}
