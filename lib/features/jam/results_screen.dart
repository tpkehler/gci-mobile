import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../auth/auth_controller.dart';
import '../../widgets/common.dart';
import 'jam_detail_screen.dart';

final bbnSummaryProvider =
    FutureProvider.autoDispose.family<BbnSummary, String>((ref, jamId) {
  return ref.watch(repositoryProvider).fetchBbnSummary(jamId);
});

/// Jam results: overview charts, collective voice Q&A, and BBN belief map.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.jamId});

  final String jamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Results'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Ask Collective'),
              Tab(text: 'Belief Map'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(jamId: jamId),
            _CollectiveVoiceTab(jamId: jamId),
            _BeliefMapTab(jamId: jamId),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.jamId});

  final String jamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(jamSummaryProvider(jamId));

    return summary.when(
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
    );
  }
}

class _CollectiveVoiceTab extends ConsumerStatefulWidget {
  const _CollectiveVoiceTab({required this.jamId});

  final String jamId;

  @override
  ConsumerState<_CollectiveVoiceTab> createState() =>
      _CollectiveVoiceTabState();
}

class _CollectiveVoiceTabState extends ConsumerState<_CollectiveVoiceTab> {
  final _controller = TextEditingController();
  CollectiveVoiceResponse? _response;
  var _loading = false;
  String? _error;

  static const _starters = [
    'What are the main themes emerging from this collaboration?',
    'Where does the group disagree most?',
    'What are the strongest reasons supporting the collective view?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit([String? question]) async {
    final q = (question ?? _controller.text).trim();
    if (q.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _response = null;
    });
    try {
      final resp = await ref.read(repositoryProvider).queryCollectiveVoice(
            jamId: widget.jamId,
            question: q,
          );
      if (!mounted) return;
      setState(() => _response = resp);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Query the collective voice',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Ask about the cumulative conversation. Answers cite propositions from the Jam.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'What did the group conclude about…?',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : () => _submit(),
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.psychology_outlined),
          label: Text(_loading ? 'Querying…' : 'Ask'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _starters
              .map(
                (q) => ActionChip(
                  label: Text(q, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onPressed: _loading ? null : () => _submit(q),
                ),
              )
              .toList(),
        ),
        if (_response != null) ...[
          const SizedBox(height: 24),
          Text('Answer', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_response!.answer),
            ),
          ),
          if (_response!.sources.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Sources (${_response!.sources.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ..._response!.sources.map(
              (s) => Card(
                child: ExpansionTile(
                  title: Text(
                    s.contributorName,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    '${(s.similarityScore * 100).toStringAsFixed(0)}% match',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(s.text),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _BeliefMapTab extends ConsumerWidget {
  const _BeliefMapTab({required this.jamId});

  final String jamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bbn = ref.watch(bbnSummaryProvider(jamId));

    return bbn.when(
      loading: () => const LoadingView(message: 'Building belief map...'),
      error: (e, _) => ErrorView(
        message: apiErrorMessage(e),
        onRetry: () => ref.invalidate(bbnSummaryProvider(jamId)),
      ),
      data: (data) {
        if (!data.success) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(data.error ?? 'Belief map not available yet.'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(bbnSummaryProvider(jamId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data.finalCscore != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Collective Score'
                          '${data.method != null ? ' · ${data.method}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(data.finalCscore! * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: data.finalCscore!.clamp(0.0, 1.0),
                          minHeight: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (data.themes.isNotEmpty) ...[
                Text('BBN Themes', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...data.themes.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(t.label)),
                            Text('${(t.probability! * 100).toStringAsFixed(0)}%'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: t.probability!.clamp(0.0, 1.0),
                          minHeight: 8,
                        ),
                        Text(
                          '${t.reasonCount} reasons',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (data.topReasons.isNotEmpty) ...[
                Text('Top propositions',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...data.topReasons.map(
                  (r) => Card(
                    child: ListTile(
                      title: Text(r.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                      trailing: Text('${(r.probability * 100).toStringAsFixed(0)}%'),
                    ),
                  ),
                ),
              ],
              if (data.finalCscore == null &&
                  data.themes.isEmpty &&
                  data.topReasons.isEmpty)
                const Text('Not enough data to build a belief map yet.'),
            ],
          ),
        );
      },
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
