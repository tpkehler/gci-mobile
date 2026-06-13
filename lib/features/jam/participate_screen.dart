import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/common.dart';
import '../auth/auth_controller.dart';
import 'predict_step.dart';
import 'review_step.dart';

/// Everything the participation pager needs, loaded together.
class _ParticipationBundle {
  const _ParticipationBundle({
    required this.jam,
    required this.prompts,
    required this.status,
  });

  final Jam jam;
  final List<JamPrompt> prompts;
  final ParticipationStatus status;

  /// Prompts the user pages through: prediction + standalone qualitative.
  /// Reasoning prompts pair with the preceding prediction prompt (web parity).
  List<JamPrompt> get participationPrompts => prompts
      .where((p) =>
          p.promptType == 'prediction' ||
          (p.promptType == 'qualitative' && !_isPairedFollowUp(p)))
      .toList();

  bool _isPairedFollowUp(JamPrompt p) => prompts.any((other) =>
      other.promptType == 'prediction' &&
      other.orderIndex == p.orderIndex - 1);

  JamPrompt? pairedReasoningFor(JamPrompt prediction) {
    if (prediction.promptType != 'prediction') return null;
    for (final p in prompts) {
      if ((p.promptType == 'reasoning' || p.promptType == 'qualitative') &&
          p.orderIndex == prediction.orderIndex + 1) {
        return p;
      }
    }
    return null;
  }
}

final _bundleProvider = FutureProvider.autoDispose
    .family<_ParticipationBundle, String>((ref, jamId) async {
  final repo = ref.watch(repositoryProvider);
  final session = ref.watch(authControllerProvider).session;
  final results = await Future.wait([
    repo.fetchJam(jamId),
    repo.fetchPrompts(jamId),
    if (session != null)
      repo.fetchParticipationStatus(
          jamId: jamId, userId: session.userId, email: session.email)
    else
      Future.value(
          const ParticipationStatus(respondedOrders: {}, reviewedOrders: {})),
  ]);
  return _ParticipationBundle(
    jam: results[0] as Jam,
    prompts: results[1] as List<JamPrompt>,
    status: results[2] as ParticipationStatus,
  );
});

/// The participation loop: one page per prompt, each going
/// respond -> peer review -> next prompt.
class ParticipateScreen extends ConsumerStatefulWidget {
  const ParticipateScreen({super.key, required this.jamId});

  final String jamId;

  @override
  ConsumerState<ParticipateScreen> createState() => _ParticipateScreenState();
}

class _ParticipateScreenState extends ConsumerState<ParticipateScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index, int pageCount) {
    if (index >= pageCount) {
      _showCompletionDialog();
      return;
    }
    setState(() => _pageIndex = index);
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _showCompletionDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('All done!'),
        content: const Text(
            'You have completed every prompt in this jam. '
            'Check the results to see how the group is thinking.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Stay Here'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.pushReplacement('/jam/${widget.jamId}/results');
            },
            child: const Text('View Results'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ref.watch(_bundleProvider(widget.jamId));
    final session = ref.watch(authControllerProvider).session;

    return Scaffold(
      appBar: AppBar(
        title: bundle.valueOrNull == null
            ? const Text('Jam')
            : Text(bundle.value!.jam.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: session == null
          ? const ErrorView(message: 'Sign in to participate.')
          : bundle.when(
              loading: () => const LoadingView(message: 'Loading jam...'),
              error: (e, _) => ErrorView(
                message: apiErrorMessage(e),
                onRetry: () =>
                    ref.invalidate(_bundleProvider(widget.jamId)),
              ),
              data: (data) {
                final prompts = data.participationPrompts;
                if (prompts.isEmpty) {
                  return const EmptyView(
                    icon: Icons.hourglass_empty,
                    title: 'No prompts yet',
                    subtitle:
                        'The facilitator has not added prompts to this jam.',
                  );
                }
                return Column(
                  children: [
                    _PromptStepper(
                      prompts: prompts,
                      currentIndex: _pageIndex,
                      status: data.status,
                      onSelect: (i) => _goToPage(i, prompts.length),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: prompts.length,
                        onPageChanged: (i) => setState(() => _pageIndex = i),
                        itemBuilder: (context, i) {
                          final prompt = prompts[i];
                          return PromptFlow(
                            key: ValueKey(prompt.id),
                            jamId: widget.jamId,
                            prompt: prompt,
                            reasoningPrompt: data.pairedReasoningFor(prompt),
                            alreadyReviewed: data.status.reviewedOrders
                                .contains(prompt.orderIndex),
                            onCompleted: () =>
                                _goToPage(i + 1, prompts.length),
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

class _PromptStepper extends StatelessWidget {
  const _PromptStepper({
    required this.prompts,
    required this.currentIndex,
    required this.status,
    required this.onSelect,
  });

  final List<JamPrompt> prompts;
  final int currentIndex;
  final ParticipationStatus status;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final prompt = prompts[i];
          final responded = status.respondedOrders.contains(prompt.orderIndex);
          final reviewed = status.reviewedOrders.contains(prompt.orderIndex);
          final selected = i == currentIndex;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelect(i),
            avatar: reviewed && responded
                ? Icon(Icons.check_circle, size: 18, color: scheme.primary)
                : responded
                    ? Icon(Icons.timelapse, size: 18, color: scheme.primary)
                    : null,
            label: Text('Prompt ${i + 1}'),
          );
        },
      ),
    );
  }
}

/// Single prompt flow: respond, then peer review.
class PromptFlow extends ConsumerStatefulWidget {
  const PromptFlow({
    super.key,
    required this.jamId,
    required this.prompt,
    required this.onCompleted,
    this.reasoningPrompt,
    this.alreadyReviewed = false,
  });

  final String jamId;
  final JamPrompt prompt;
  final JamPrompt? reasoningPrompt;
  final bool alreadyReviewed;
  final VoidCallback onCompleted;

  @override
  ConsumerState<PromptFlow> createState() => _PromptFlowState();
}

class _PromptFlowState extends ConsumerState<PromptFlow> {
  // Always begin at the predict → reason step. This mirrors the web PromptTab,
  // which opens in 'predict' mode for every prompt regardless of whether the
  // user has responded before. Collective reasoning is ALWAYS predict (quant)
  // → reason (qual) → peer review; prior-response state drives the stepper's
  // progress indicators, never a skip past the prediction.
  bool _responded = false;
  String? _submittedReasoning;
  double? _submittedProbability;

  @override
  Widget build(BuildContext context) {
    if (!_responded) {
      return PredictStep(
        jamId: widget.jamId,
        prompt: widget.prompt,
        reasoningPrompt: widget.reasoningPrompt,
        onSubmitted: (reasoning, probability) {
          setState(() {
            _responded = true;
            _submittedReasoning = reasoning;
            _submittedProbability = probability;
          });
        },
      );
    }
    return ReviewStep(
      jamId: widget.jamId,
      prompt: widget.prompt,
      userReasoning: _submittedReasoning,
      probabilityEstimate: _submittedProbability,
      alreadyReviewed: widget.alreadyReviewed,
      onCompleted: widget.onCompleted,
    );
  }
}
