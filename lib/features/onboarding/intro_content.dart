import 'package:flutter/material.dart';

/// A single onboarding / how-it-works step, shared by the first-run intro
/// carousel and the persistent About screen.
class IntroStep {
  const IntroStep({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

/// Jam tagline shown on the welcome card and About header.
const String kJamTagline =
    "The outcome isn't scripted —\nit emerges from the interaction.";

const List<IntroStep> kIntroSteps = [
  IntroStep(
    icon: Icons.hub_outlined,
    title: 'Welcome to Jam',
    body: 'Imagine and predct future possibilities together.',
  ),
  IntroStep(
    icon: Icons.forum_outlined,
    title: 'Warm up for the Jam in a discussion channel',
    body: "Browse the group's ideas in a threaded conversation; "
        'ask questions or build on existing ideas.',
  ),
  IntroStep(
    icon: Icons.insights_outlined,
    title: 'Predict & reason',
    body: 'Share your point of view, then explain your reasoning '
        'supporting your view.',
  ),
  IntroStep(
    icon: Icons.tune,
    title: 'Review & converge',
    body: "Peer review ideas from others; Get inspired by new ideas "
        'Jam blends everyone\'s input into a collective forecast.',
  ),
];
