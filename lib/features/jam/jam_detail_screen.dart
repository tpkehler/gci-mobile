import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../core/config.dart';
import '../../widgets/common.dart';
import '../auth/auth_controller.dart';

final jamSummaryProvider =
    FutureProvider.autoDispose.family<JamSummary, String>((ref, jamId) {
  return ref.watch(repositoryProvider).fetchJamSummary(jamId);
});

/// Jam landing page: overview, funnel stats, participate/results actions.
class JamDetailScreen extends ConsumerWidget {
  const JamDetailScreen({super.key, required this.jamId});

  final String jamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(jamSummaryProvider(jamId));
    final session = ref.watch(authControllerProvider).session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jam'),
        actions: [
          IconButton(
            tooltip: 'Share invite link',
            icon: const Icon(Icons.ios_share),
            onPressed: () => Share.shareUri(
              Uri.parse('${AppConfig.webOrigin}/jam/$jamId/participate'),
            ),
          ),
        ],
      ),
      body: summary.when(
        loading: () => const LoadingView(message: 'Loading jam...'),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(jamSummaryProvider(jamId)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(jamSummaryProvider(jamId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(data.title,
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  const SizedBox(width: 8),
                  JamStatusChip(status: data.status),
                ],
              ),
              if (data.description.isNotEmpty &&
                  data.description != data.title) ...[
                const SizedBox(height: 8),
                Text(data.description,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (data.creatorName != null) ...[
                const SizedBox(height: 8),
                Text('Created by ${data.creatorName}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/jam/$jamId/participate'),
                icon: const Icon(Icons.groups),
                label: const Text('Join the Jam'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push('/jam/$jamId/results'),
                icon: const Icon(Icons.insights),
                label: const Text('View Results'),
              ),
              const SizedBox(height: 16),
              _FunnelCard(funnel: data.funnel),
              if (data.prompts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prompts (${data.prompts.length})',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...data.prompts.map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Chip(
                                    label: Text('${p.order + 1}'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(p.text)),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
              if (session != null && !session.isGuest)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Signed in as ${session.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.funnel});

  final JamSummaryFunnel funnel;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Participation',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                stat('Participants',
                    '${funnel.participants} (${funnel.humans}H/${funnel.agents}AI)'),
                stat('Responded', '${funnel.responded}'),
                stat('Responses', '${funnel.responses}'),
                stat('Reviews', '${funnel.reviews}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
