import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../auth/auth_controller.dart';
import '../../widgets/common.dart';

final wikiProvider =
    FutureProvider.autoDispose.family<WikiSummary, String>((ref, userId) {
  return ref.watch(repositoryProvider).fetchWiki(userId);
});

/// Personal knowledge base built from jam participation.
class MyWikiScreen extends ConsumerWidget {
  const MyWikiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    if (session == null || session.userId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view your wiki')),
      );
    }

    final wiki = ref.watch(wikiProvider(session.userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wiki'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(wikiProvider(session.userId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: wiki.when(
        loading: () => const LoadingView(message: 'Loading your wiki...'),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(wikiProvider(session.userId)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(wikiProvider(session.userId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Your knowledge from Jams',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Pages are compiled automatically when you participate.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatChip(
                    label: 'Pages',
                    value: '${data.pageCount}',
                  ),
                  const SizedBox(width: 12),
                  if (data.lastIngestedAt != null)
                    Expanded(
                      child: Text(
                        'Updated ${_formatDate(data.lastIngestedAt!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openWikiChat(context, ref, session.userId),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Ask My Wiki'),
              ),
              const SizedBox(height: 20),
              if (data.pages.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No pages yet. Participate in a Jam to start building '
                      'your personal knowledge base.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else ...[
                Text('Pages', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...data.pages.entries.map(
                  (entry) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.article_outlined),
                      title: Text(entry.value.title),
                      subtitle: entry.value.updatedAt != null
                          ? Text(_formatDate(entry.value.updatedAt!))
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WikiPageScreen(
                            userId: session.userId,
                            slug: entry.key,
                            title: entry.value.title,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  void _openWikiChat(BuildContext context, WidgetRef ref, String userId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _WikiChatSheet(userId: userId),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        child: Text(value, style: const TextStyle(fontSize: 12)),
      ),
      label: Text(label),
    );
  }
}

class WikiPageScreen extends ConsumerWidget {
  const WikiPageScreen({
    super.key,
    required this.userId,
    required this.slug,
    required this.title,
  });

  final String userId;
  final String slug;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageFuture = ref.watch(_wikiPageProvider((userId, slug)));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: pageFuture.when(
        loading: () => const LoadingView(message: 'Loading page...'),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(_wikiPageProvider((userId, slug))),
        ),
        data: (page) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(page.content),
        ),
      ),
    );
  }
}

final _wikiPageProvider = FutureProvider.autoDispose
    .family<WikiPageContent, (String, String)>((ref, args) {
  final (userId, slug) = args;
  return ref.watch(repositoryProvider).fetchWikiPage(userId, slug);
});

class _WikiChatSheet extends ConsumerStatefulWidget {
  const _WikiChatSheet({required this.userId});

  final String userId;

  @override
  ConsumerState<_WikiChatSheet> createState() => _WikiChatSheetState();
}

class _WikiChatSheetState extends ConsumerState<_WikiChatSheet> {
  final _controller = TextEditingController();
  final _messages = <({bool isUser, String text})>[];
  var _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _loading) return;
    setState(() {
      _messages.add((isUser: true, text: question));
      _controller.clear();
      _loading = true;
    });
    try {
      final resp = await ref.read(repositoryProvider).queryWiki(
            userId: widget.userId,
            question: question,
          );
      if (!mounted) return;
      setState(() {
        _messages.add((isUser: false, text: resp.answer));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add((
          isUser: false,
          text: apiErrorMessage(e),
        ));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            AppBar(
              title: const Text('Ask My Wiki'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Align(
                    alignment: msg.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.85,
                      ),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg.text),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'What did I learn about…?',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _loading ? null : _send,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
