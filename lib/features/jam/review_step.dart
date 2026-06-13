import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/common.dart';
import '../auth/auth_controller.dart';

/// Peer review phase: rate ideas (Agree / Need Info / Disagree), rank rated
/// ideas with tap-to-rank arrows, submit the batch.
///
/// While no peer ideas exist yet, listens on the jam's SSE channel and
/// reloads when new activity arrives (12s polling fallback).
class ReviewStep extends ConsumerStatefulWidget {
  const ReviewStep({
    super.key,
    required this.jamId,
    required this.prompt,
    required this.onCompleted,
    this.userReasoning,
    this.probabilityEstimate,
    this.alreadyReviewed = false,
  });

  final String jamId;
  final JamPrompt prompt;
  final String? userReasoning;
  final double? probabilityEstimate;
  final bool alreadyReviewed;
  final VoidCallback onCompleted;

  @override
  ConsumerState<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewState {
  ReviewSentiment? sentiment;
  String comment = '';
  DateTime? firstInteraction;
}

class _ReviewStepState extends ConsumerState<ReviewStep> {
  List<PeerIdea> _ideas = [];
  final Map<String, _ReviewState> _reviews = {};
  final List<String> _priorityOrder = [];
  final Set<String> _excluded = {};

  bool _loading = true;
  bool _waitingForPeers = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  Timer? _pollTimer;
  late final DateTime _loadedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stopWaiting();
    super.dispose();
  }

  Future<void> _load() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ideas = await ref.read(repositoryProvider).fetchPeerIdeas(
            jamId: widget.jamId,
            reviewerId: session.userId,
            promptText: widget.prompt.text,
            userReasoning: widget.userReasoning,
            probabilityEstimate: widget.probabilityEstimate,
          );
      if (!mounted) return;
      setState(() {
        _ideas = ideas;
        _loading = false;
        _waitingForPeers = ideas.isEmpty;
      });
      if (ideas.isEmpty) {
        _startWaiting();
      } else {
        _stopWaiting();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  void _startWaiting() {
    if (!mounted) return;
    // Poll every 12s while no peer ideas are available yet.
    _pollTimer ??= Timer.periodic(const Duration(seconds: 12), (_) => _load());
  }

  void _stopWaiting() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _setSentiment(String ideaId, ReviewSentiment sentiment) {
    setState(() {
      final review = _reviews.putIfAbsent(ideaId, _ReviewState.new);
      review.firstInteraction ??= DateTime.now();
      if (review.sentiment == sentiment) {
        review.sentiment = null;
        _priorityOrder.remove(ideaId);
      } else {
        review.sentiment = sentiment;
        _excluded.remove(ideaId);
        if (!_priorityOrder.contains(ideaId)) _priorityOrder.add(ideaId);
      }
    });
  }

  void _move(String ideaId, int delta) {
    setState(() {
      final index = _priorityOrder.indexOf(ideaId);
      final target = index + delta;
      if (index < 0 || target < 0 || target >= _priorityOrder.length) return;
      _priorityOrder.removeAt(index);
      _priorityOrder.insert(target, ideaId);
    });
  }

  void _removeFromPriority(String ideaId) {
    setState(() {
      _excluded.add(ideaId);
      _priorityOrder.remove(ideaId);
    });
  }

  int get _ratedCount =>
      _reviews.values.where((r) => r.sentiment != null).length;

  List<PeerIdea> get _rankedIdeas => _priorityOrder
      .where((id) => !_excluded.contains(id))
      .map((id) => _ideas.where((i) => i.id == id).firstOrNull)
      .whereType<PeerIdea>()
      .toList();

  Future<void> _submit() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || _ratedCount == 0) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final reviews = <PeerReview>[];
      _reviews.forEach((ideaId, state) {
        if (state.sentiment == null) return;
        final rank = _priorityOrder.indexOf(ideaId);
        reviews.add(PeerReview(
          propositionId: ideaId,
          sentiment: state.sentiment!,
          priorityPosition: rank >= 0 ? rank + 1 : null,
          comment: state.comment,
          responseTimeMs: state.firstInteraction
              ?.difference(_loadedAt)
              .inMilliseconds
              .abs(),
        ));
      });
      await ref.read(repositoryProvider).submitReviews(
            jamId: widget.jamId,
            reviewerId: session.userId,
            reviews: reviews,
            totalRanked: _rankedIdeas.length,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _DonePanel(onContinue: widget.onCompleted);
    }
    if (_loading && _ideas.isEmpty) {
      return const LoadingView(message: 'Loading ideas to review...');
    }
    if (_error != null && _ideas.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_waitingForPeers) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Waiting for other participants',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Ideas to review will appear here as soon as others respond. '
                'This screen updates automatically.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: widget.onCompleted,
                  child: const Text('Skip for now')),
            ],
          ),
        ),
      );
    }

    final ranked = _rankedIdeas;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Rate ideas from others',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'For each idea, indicate whether you agree, need more info, or '
          'disagree. Rated ideas join your priority ranking below.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ..._ideas.map(_buildIdeaCard),
        if (ranked.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Your priority ranking (${ranked.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Use the arrows to order ideas by priority.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          ...ranked.asMap().entries.map((entry) =>
              _buildRankTile(entry.value, entry.key + 1, ranked.length)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _ratedCount == 0 || _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
          label: Text(_submitting
              ? 'Submitting...'
              : 'Submit Reviews ($_ratedCount rated)'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildIdeaCard(PeerIdea idea) {
    final review = _reviews[idea.id];
    final sentiment = review?.sentiment;
    final scheme = Theme.of(context).colorScheme;
    final borderColor = switch (sentiment) {
      ReviewSentiment.agree => Colors.green,
      ReviewSentiment.needInfo => Colors.orange,
      ReviewSentiment.disagree => scheme.error,
      null => null,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: borderColor != null
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'By ${idea.contributorName ?? 'a participant'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (idea.probabilityEstimate != null)
                  Chip(
                    label: Text(
                        '${(idea.probabilityEstimate! * 100).round()}% confident'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(idea.text),
            const SizedBox(height: 12),
            Row(
              children: ReviewSentiment.values.map((s) {
                final selected = sentiment == s;
                final color = switch (s) {
                  ReviewSentiment.agree => Colors.green,
                  ReviewSentiment.needInfo => Colors.orange,
                  ReviewSentiment.disagree => scheme.error,
                };
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: s != ReviewSentiment.disagree ? 8 : 0),
                    child: selected
                        ? FilledButton(
                            onPressed: () => _setSentiment(idea.id, s),
                            style: FilledButton.styleFrom(
                                backgroundColor: color,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4)),
                            child: Text(s.label,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          )
                        : OutlinedButton(
                            onPressed: () => _setSentiment(idea.id, s),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: color,
                                side: BorderSide(color: color),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4)),
                            child: Text(s.label,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                  ),
                );
              }).toList(),
            ),
            if (sentiment != null) ...[
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Add a comment (optional)...',
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 3,
                onChanged: (v) => _reviews[idea.id]?.comment = v,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRankTile(PeerIdea idea, int position, int total) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up),
                  visualDensity: VisualDensity.compact,
                  onPressed: position == 1 ? null : () => _move(idea.id, -1),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      position == total ? null : () => _move(idea.id, 1),
                ),
              ],
            ),
            CircleAvatar(
              radius: 14,
              child: Text('$position', style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  Text(idea.text, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove from ranking',
              onPressed: () => _removeFromPriority(idea.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonePanel extends StatelessWidget {
  const _DonePanel({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 56),
            const SizedBox(height: 16),
            Text('Reviews submitted!',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Thanks — your input updates the collective model.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
