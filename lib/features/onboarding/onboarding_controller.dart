import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the first-run intro has been shown. Persisted in
/// shared_preferences so the carousel only auto-appears once.
class OnboardingState {
  const OnboardingState({this.initialized = false, this.seenIntro = false});

  /// True once the persisted flag has been loaded (startup gate).
  final bool initialized;

  /// True once the user has completed or skipped the first-run intro.
  final bool seenIntro;

  OnboardingState copyWith({bool? initialized, bool? seenIntro}) =>
      OnboardingState(
        initialized: initialized ?? this.initialized,
        seenIntro: seenIntro ?? this.seenIntro,
      );
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController() : super(const OnboardingState()) {
    _load();
  }

  static const _key = 'seen_intro_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = OnboardingState(
        initialized: true,
        seenIntro: prefs.getBool(_key) ?? false,
      );
    } catch (_) {
      // If prefs are unavailable, don't trap the user on the splash.
      state = const OnboardingState(initialized: true, seenIntro: true);
    }
  }

  Future<void> markSeen() async {
    state = state.copyWith(seenIntro: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // Best effort; the in-memory flag still suppresses re-showing this run.
    }
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>(
  (ref) => OnboardingController(),
);
