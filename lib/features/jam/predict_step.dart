import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../auth/auth_controller.dart';

/// Respond phase: probability slider (prediction prompts) + reasoning text.
class PredictStep extends ConsumerStatefulWidget {
  const PredictStep({
    super.key,
    required this.jamId,
    required this.prompt,
    required this.onSubmitted,
    this.reasoningPrompt,
  });

  final String jamId;
  final JamPrompt prompt;
  final JamPrompt? reasoningPrompt;

  /// Called with (reasoning, probability 0-1 or null) after a successful save.
  final void Function(String reasoning, double? probability) onSubmitted;

  @override
  ConsumerState<PredictStep> createState() => _PredictStepState();
}

class _PredictStepState extends ConsumerState<PredictStep> {
  final _reasoning = TextEditingController();
  double _probability = 50;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasoning.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _reasoning.text.trim();
    final minLength = widget.prompt.minReasoningLength ?? 0;
    if (text.isEmpty) {
      setState(() => _error = 'Please share your reasoning first.');
      return;
    }
    if (text.length < minLength) {
      setState(() =>
          _error = 'Your response must be at least $minLength characters.');
      return;
    }
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).submitResponse(
            jamId: widget.jamId,
            userId: session.userId,
            userName: session.name,
            userEmail: session.email,
            reasoningText: text,
            prompt: widget.prompt,
            probabilityEstimate:
                widget.prompt.requireProbability ? _probability / 100 : null,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Response saved — now review ideas from others')));
      widget.onSubmitted(
          text, widget.prompt.requireProbability ? _probability / 100 : null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prompt = widget.prompt;
    final reasoningLabel = prompt.requireProbability
        ? (widget.reasoningPrompt?.text ?? 'Your reasoning')
        : 'Your response';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prompt.isQualitative ? 'Prompt' : 'Prediction',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(prompt.text,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ),
          if (prompt.requireProbability) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How likely is this?',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _probability,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: '${_probability.round()}%',
                            onChanged: (v) =>
                                setState(() => _probability = v),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '${_probability.round()}%',
                            textAlign: TextAlign.end,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Very unlikely',
                            style: Theme.of(context).textTheme.bodySmall),
                        Text('Very likely',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reasoningLabel,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasoning,
                    maxLines: 6,
                    minLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: prompt.requireProbability
                          ? 'Share your reasoning and key factors...'
                          : 'Share your response to the prompt...',
                      helperText: prompt.minReasoningLength != null
                          ? 'Minimum ${prompt.minReasoningLength} characters'
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 4),
                  Text('${_reasoning.text.length} characters',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onErrorContainer)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(_submitting ? 'Saving...' : 'Save Response'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
