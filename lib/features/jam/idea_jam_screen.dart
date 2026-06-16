import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../core/config.dart';
import '../../widgets/common.dart';
import '../auth/auth_controller.dart';
import 'jam_detail_screen.dart' show jamSummaryProvider;

/// All ideas in a jam's warm-up discussion.
final jamIdeasProvider =
    FutureProvider.autoDispose.family<List<Idea>, String>((ref, jamId) {
  return ref.watch(repositoryProvider).fetchIdeas(jamId);
});

/// Replies/questions on a single idea (loaded lazily when a card is expanded).
final ideaRepliesProvider =
    FutureProvider.autoDispose.family<List<IdeaReply>, String>((ref, ideaId) {
  return ref.watch(repositoryProvider).fetchReplies(ideaId);
});

/// The warm-up "IdeaJam": a Slack-like threaded discussion that is the front
/// door of a jam. People browse seed + peer ideas, ask questions, and build on
/// them, then tap into the structured prediction → response → reasoning flow.
class IdeaJamScreen extends ConsumerWidget {
  const IdeaJamScreen({super.key, required this.jamId});

  final String jamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideas = ref.watch(jamIdeasProvider(jamId));
    final summary = ref.watch(jamSummaryProvider(jamId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion'),
        actions: [
          IconButton(
            tooltip: 'About this jam',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push('/jam/$jamId/about'),
          ),
          IconButton(
            tooltip: 'Results',
            icon: const Icon(Icons.insights),
            onPressed: () => context.push('/jam/$jamId/results'),
          ),
          IconButton(
            tooltip: 'Share invite link',
            icon: const Icon(Icons.ios_share),
            onPressed: () => Share.shareUri(
              Uri.parse('${AppConfig.webOrigin}/jam/$jamId/participate'),
            ),
          ),
        ],
      ),
      body: ideas.when(
        loading: () => const LoadingView(message: 'Loading discussion...'),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(jamIdeasProvider(jamId)),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(jamIdeasProvider(jamId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _HeaderCard(
                title: summary.valueOrNull?.title,
                description: summary.valueOrNull?.description,
                status: summary.valueOrNull?.status,
                ideaCount: list.length,
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: EmptyView(
                    icon: Icons.forum_outlined,
                    title: 'No ideas yet',
                    subtitle:
                        'Be the first — enter the prediction experience below '
                        'to add your reasoning.',
                  ),
                )
              else
                ...list.map((idea) => _IdeaCard(jamId: jamId, idea: idea)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _EngageBar(jamId: jamId),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.description,
    required this.status,
    required this.ideaCount,
  });

  final String? title;
  final String? description;
  final String? status;
  final int ideaCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title ?? 'Jam discussion',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(width: 8),
                  JamStatusChip(status: status!),
                ],
              ],
            ),
            if ((description ?? '').isNotEmpty && description != title) ...[
              const SizedBox(height: 8),
              Text(description!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.forum_outlined,
                    size: 16, color: theme.hintColor),
                const SizedBox(width: 6),
                Text(
                  ideaCount == 1 ? '1 idea in play' : '$ideaCount ideas in play',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Warm up here — read, ask questions, and build on ideas. '
              'When you\'re ready, enter the prediction experience.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdeaCard extends ConsumerStatefulWidget {
  const _IdeaCard({required this.jamId, required this.idea});

  final String jamId;
  final Idea idea;

  @override
  ConsumerState<_IdeaCard> createState() => _IdeaCardState();
}

class _IdeaCardState extends ConsumerState<_IdeaCard> {
  bool _expanded = false;
  bool _busy = false;

  Idea get idea => widget.idea;

  Future<void> _ask() async {
    final text = await _composeSheet(
      title: 'Ask a question',
      hint: idea.isAi
          ? 'Ask this AI contributor about their idea…'
          : 'Ask a question about this idea…',
      submitLabel: 'Send question',
      minChars: 1,
    );
    if (text == null) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    await _run(() async {
      await ref.read(repositoryProvider).postReply(
            ideaId: idea.id,
            questionerId: session.userId,
            questionerName: session.name,
            promptText: text,
          );
      ref.invalidate(ideaRepliesProvider(idea.id));
      if (mounted) setState(() => _expanded = true);
    }, success: idea.isAi ? 'Question sent — answer on its way' : 'Question posted');
  }

  Future<void> _buildOn() async {
    final text = await _composeSheet(
      title: 'Build on this idea',
      hint: 'Add a new idea that builds on this one…',
      submitLabel: 'Add idea',
      minChars: 10,
    );
    if (text == null) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    await _run(() async {
      await ref.read(repositoryProvider).buildOnIdea(
            ideaId: idea.id,
            jamId: widget.jamId,
            builderId: session.userId,
            builderName: session.name,
            newIdeaText: text,
          );
      ref.invalidate(jamIdeasProvider(widget.jamId));
    }, success: 'New idea added');
  }

  Future<void> _flag() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Flag this idea')),
            for (final f in const [
              ('inappropriate', 'Inappropriate'),
              ('misinformation', 'Misinformation'),
              ('suspicious', 'Suspicious'),
            ])
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(f.$2),
                onTap: () => Navigator.pop(ctx, f.$1),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await _run(() async {
      await ref.read(repositoryProvider).flagIdea(
            ideaId: idea.id,
            flagName: choice,
            whoFlagged: session.userId,
          );
    }, success: 'Idea flagged');
  }

  Future<void> _run(Future<void> Function() action,
      {required String success}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Bottom-sheet composer; returns trimmed text, or null if cancelled/too short.
  /// The sheet body owns its own [TextEditingController] (see [_ComposeSheet]) so
  /// the controller is disposed with the widget tree after the close animation —
  /// disposing it here synchronously races the dismissal and crashes.
  Future<String?> _composeSheet({
    required String title,
    required String hint,
    required String submitLabel,
    required int minChars,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ComposeSheet(
        title: title,
        hint: hint,
        submitLabel: submitLabel,
        minChars: minChars,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: idea.isAi
                      ? theme.colorScheme.tertiaryContainer
                      : theme.colorScheme.primaryContainer,
                  child: Icon(
                    idea.isAi ? Icons.smart_toy_outlined : Icons.person_outline,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(idea.contributorName,
                                style: theme.textTheme.labelLarge,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (idea.isAi) ...[
                            const SizedBox(width: 6),
                            _Tag(label: 'AI', color: theme.colorScheme.tertiary),
                          ],
                        ],
                      ),
                      Text(_relativeTime(idea.createdAt),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(idea.text, style: theme.textTheme.bodyMedium),
            ),
            if ((idea.contributorReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border(
                      left: BorderSide(
                          color: theme.dividerColor, width: 3)),
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                ),
                child: Text(idea.contributorReason!,
                    style: theme.textTheme.bodySmall),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _ask,
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('Query'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _buildOn,
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('Build on'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Hide replies' : 'Replies'),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (v) {
                    if (v == 'flag') _flag();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'flag', child: Text('Flag idea')),
                  ],
                ),
              ],
            ),
            if (_expanded) _RepliesSection(ideaId: idea.id),
          ],
        ),
      ),
    );
  }
}

class _RepliesSection extends ConsumerWidget {
  const _RepliesSection({required this.ideaId});

  final String ideaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replies = ref.watch(ideaRepliesProvider(ideaId));
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 8),
      child: replies.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(12),
          child: Center(
            child: SizedBox(
                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
        error: (e, _) => Text('Could not load replies',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error)),
        data: (list) {
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No questions yet — be the first to ask.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              for (final r in list) _ReplyTile(reply: r),
            ],
          );
        },
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply});

  final IdeaReply reply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 14, color: theme.hintColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text('${reply.questionerName} asked',
                    style: theme.textTheme.labelSmall),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(reply.promptText, style: theme.textTheme.bodySmall),
          if (reply.hasAnswer) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.smart_toy_outlined,
                      size: 14, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(reply.agentResponse!,
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Awaiting response…',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.hintColor)),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _EngageBar extends StatelessWidget {
  const _EngageBar({required this.jamId});

  final String jamId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: () => context.push('/jam/$jamId/participate'),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Enter the prediction experience'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet body that owns its [TextEditingController] for its lifetime,
/// disposing it in [State.dispose] after the sheet is fully gone.
class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({
    required this.title,
    required this.hint,
    required this.submitLabel,
    required this.minChars,
  });

  final String title;
  final String hint;
  final String submitLabel;
  final int minChars;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: widget.hint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final t = _controller.text.trim();
              if (t.length < widget.minChars) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(widget.minChars > 1
                      ? 'Please enter at least ${widget.minChars} characters'
                      : 'Please enter a question'),
                ));
                return;
              }
              Navigator.pop(context, t);
            },
            child: Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final d = DateTime.now().toUtc().difference(t.toUtc());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
