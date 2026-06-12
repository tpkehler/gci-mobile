import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_client.dart';
import '../../core/config.dart';
import '../auth/auth_controller.dart';

/// Light creator flow: a 2-step form (details + prompts), then launch and
/// share the invite link.
class CreateJamScreen extends ConsumerStatefulWidget {
  const CreateJamScreen({super.key});

  @override
  ConsumerState<CreateJamScreen> createState() => _CreateJamScreenState();
}

class _PromptDraft {
  final text = TextEditingController();
  bool requireProbability = true;

  void dispose() => text.dispose();
}

class _CreateJamScreenState extends ConsumerState<CreateJamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final List<_PromptDraft> _prompts = [_PromptDraft()];
  bool _isPublic = false;

  bool _busy = false;
  String? _error;
  String? _createdJamId;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final p in _prompts) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _createAndLaunch() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null || session.isGuest) {
      setState(() => _error = 'Sign in with an account to create jams.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final prompts = <Map<String, dynamic>>[];
      var order = 0;
      for (final draft in _prompts) {
        final text = draft.text.text.trim();
        if (text.isEmpty) continue;
        prompts.add({
          'order': order,
          'text': text,
          'prompt_type':
              draft.requireProbability ? 'prediction' : 'qualitative',
          'require_probability': draft.requireProbability,
          'require_reasoning': true,
        });
        order++;
      }
      final jamId = await repo.createJam(
        title: _title.text.trim(),
        description: _description.text.trim(),
        creatorId: session.userId,
        prompts: prompts,
        isPublic: _isPublic,
      );
      await repo.updateJam(jamId, {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'prompts': prompts,
        'is_public': _isPublic,
        'status': 'active',
      });
      await repo.launchJam(jamId, userId: session.userId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _createdJamId = jamId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_createdJamId != null) {
      return _LaunchedPanel(jamId: _createdJamId!);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Create a Jam')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('1. Details', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What decision or question is this jam about?'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a description'
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Public jam'),
                subtitle:
                    const Text('Anyone with the link can discover and join'),
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
              ),
              const SizedBox(height: 16),
              Text('2. Prompts',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Prediction prompts ask for a probability plus reasoning. '
                'Open prompts collect free-form responses.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ..._prompts.asMap().entries.map((entry) {
                final i = entry.key;
                final draft = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: draft.text,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Prompt ${i + 1}',
                            hintText:
                                'e.g. Will X happen by the end of the year?',
                          ),
                          validator: i == 0
                              ? (v) => (v == null || v.trim().isEmpty)
                                  ? 'Add at least one prompt'
                                  : null
                              : null,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('Ask for a probability'),
                                value: draft.requireProbability,
                                onChanged: (v) => setState(
                                    () => draft.requireProbability = v),
                              ),
                            ),
                            if (_prompts.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remove prompt',
                                onPressed: () => setState(() {
                                  _prompts.removeAt(i).dispose();
                                }),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: () => setState(() => _prompts.add(_PromptDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Add another prompt'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _createAndLaunch,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.rocket_launch),
                label: Text(_busy ? 'Launching...' : 'Create & Launch'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaunchedPanel extends StatelessWidget {
  const _LaunchedPanel({required this.jamId});

  final String jamId;

  String get _inviteUrl => '${AppConfig.webOrigin}/jam/$jamId/participate';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jam Launched')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text('Your jam is live!',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Share the invite link so others can join, or open the jam '
                'to add your own response.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Share.shareUri(Uri.parse(_inviteUrl)),
                icon: const Icon(Icons.ios_share),
                label: const Text('Share Invite Link'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.pushReplacement('/jam/$jamId'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Open Jam'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
