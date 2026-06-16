import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/jam_brand.dart';
import 'intro_content.dart';

/// Persistent "About / How Jam works" reference, reachable from Profile and
/// the login screen. Same content as the first-run intro, always available.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About Jam')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: GciTheme.brandInk,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const SizedBox(
                    width: 300,
                    height: 150,
                    child: LiveBeliefField(),
                  ),
                  const SizedBox(height: 8),
                  const JamWordmark(onDark: true, fontSize: 38),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Serendipity, the occurrence of finding valuable new '
                      'ideas, is no longer by chance. It is a predictable '
                      'outcome of a Jam.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: GciTheme.brandTealLight.withValues(alpha: 0.8),
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            kJamTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: GciTheme.brandTeal,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          Text('How it works', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'A Jam is a co-creative experience where you explore possible '
            'futures together with colleagues, customers, or partners. In a '
            'Jam, creative thinking turns into possible futures. Like in Jazz, '
            'a good Jam session requires listening and learning as you explore '
            'possibilities. Over time, many Jams build your Collective IQ — the '
            'cumulative intelligence of your group, community, or company.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.textTheme.bodySmall?.color),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < kIntroSteps.length; i++)
            _StepTile(step: kIntroSteps[i], number: i + 1),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.push('/welcome'),
            icon: const Icon(Icons.slideshow_outlined),
            label: const Text('Replay the intro'),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.number});

  final IntroStep step;
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: GciTheme.brandTeal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(step.icon, color: GciTheme.brandTeal),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(step.body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
