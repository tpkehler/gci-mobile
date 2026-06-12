import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/common.dart';
import 'jam_detail_screen.dart';

/// Jam results: participation funnel, per-prompt consensus chart, top ideas.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.jamId});

  final String jamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(jamSummaryProvider(jamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: summary.when(
        loading: () => const LoadingView(message: 'Loading results...'),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(jamSummaryProvider(jamId)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(jamSummaryProvider(jamId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(data.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _FunnelChartCard(funnel: data.funnel),
              const SizedBox(height: 12),
              if (data.prompts.any((p) => p.meanProbability != null)) ...[
                _ConsensusCard(prompts: data.prompts),
                const SizedBox(height: 12),
              ],
              if (data.topIdeas.isNotEmpty) _TopIdeasCard(ideas: data.topIdeas),
            ],
          ),
        ),
      ),
    );
  }
}

class _FunnelChartCard extends StatelessWidget {
  const _FunnelChartCard({required this.funnel});

  final JamSummaryFunnel funnel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bars = <(String, int)>[
      ('Invited', funnel.invited),
      ('Joined', funnel.participants),
      ('Responded', funnel.responded),
      ('Reviewed', funnel.reviewers),
    ];
    final maxValue =
        bars.map((b) => b.$2).fold<int>(1, (a, b) => b > a ? b : a);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Participation funnel',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxValue.toDouble() * 1.2,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(bars[value.toInt()].$1,
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                        ),
                      ),
                    ),
                  ),
                  barGroups: bars.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.$2.toDouble(),
                          width: 28,
                          color: scheme.primary,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ],
                      showingTooltipIndicators: const [0],
                    );
                  }).toList(),
                  barTouchData: BarTouchData(
                    enabled: false,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent,
                      tooltipMargin: 4,
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        rod.toY.toInt().toString(),
                        TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${funnel.humans} humans, ${funnel.agents} AI agents — '
              '${funnel.responses} responses, ${funnel.reviews} peer reviews',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsensusCard extends StatelessWidget {
  const _ConsensusCard({required this.prompts});

  final List<JamPromptStat> prompts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final withConsensus =
        prompts.where((p) => p.meanProbability != null).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consensus by prompt',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Mean probability across all responses',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ...withConsensus.map((p) {
              final pct = (p.meanProbability! * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: p.meanProbability!.clamp(0.0, 1.0),
                              minHeight: 10,
                              backgroundColor:
                                  scheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '$pct% (${p.responseCount})',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TopIdeasCard extends StatelessWidget {
  const _TopIdeasCard({required this.ideas});

  final List<TopIdea> ideas;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top ideas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Ranked by relevance to the group',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            ...ideas.asMap().entries.map((entry) {
              final idea = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      child: Text('${entry.key + 1}',
                          style: const TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(idea.text),
                          const SizedBox(height: 2),
                          Text(
                            idea.contributorName +
                                (idea.relevance != null
                                    ? ' — relevance ${(idea.relevance! * 100).round()}%'
                                    : ''),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
