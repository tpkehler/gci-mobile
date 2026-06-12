import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../api/api_client.dart';
import '../../api/gci_repository.dart';
import '../../core/session_store.dart';

/// App-wide auth state. `null` session means signed out.
class AuthState {
  const AuthState({this.session, this.initialized = false});

  final StoredSession? session;

  /// True once the keychain has been checked on startup.
  final bool initialized;

  bool get isSignedIn => session != null;
  bool get isGuest => session?.isGuest ?? false;

  AuthState copyWith({StoredSession? session, bool? initialized, bool clearSession = false}) =>
      AuthState(
        session: clearSession ? null : (session ?? this.session),
        initialized: initialized ?? this.initialized,
      );
}

class AuthController extends Notifier<AuthState> {
  late final SessionStore _store;

  @override
  AuthState build() {
    _store = ref.read(sessionStoreProvider);
    Future.microtask(_restore);
    return const AuthState();
  }

  Future<void> _restore() async {
    final session = await _store.read();
    state = AuthState(session: session, initialized: true);
  }

  GciRepository get _repo => ref.read(repositoryProvider);

  Future<String?> login(String email, String password) async {
    try {
      final result = await _repo.login(email, password);
      if (!result.success || result.userId == null) {
        return result.error ?? 'Login failed';
      }
      final session = StoredSession(
        userId: result.userId!,
        name: result.name ?? 'User',
        email: result.email ?? email,
        isGuest: false,
        jwtToken: result.jwtToken,
      );
      await _store.write(session);
      state = state.copyWith(session: session);
      return null;
    } catch (e) {
      return apiErrorMessage(e);
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String? jamId,
  }) async {
    try {
      final result = await _repo.register(
          name: name, email: email, password: password, jamId: jamId);
      if (!result.success) return result.error ?? 'Registration failed';
      // Registration may require email verification before login succeeds;
      // callers route back to the login screen with a notice.
      return null;
    } catch (e) {
      return apiErrorMessage(e);
    }
  }

  /// Guest entry for invite links: a stable client-generated UUID, the same
  /// model the web app uses. The API auto-enrolls it on first submit.
  Future<void> continueAsGuest() async {
    final existing = state.session;
    if (existing != null && existing.isGuest) return;
    final session = StoredSession(
      userId: const Uuid().v4(),
      name: 'Guest',
      email: '',
      isGuest: true,
    );
    await _store.write(session);
    state = state.copyWith(session: session);
  }

  Future<void> signOut() async {
    await _store.clear();
    state = const AuthState(initialized: true);
  }
}

// -----------------------------------------------------------------
// Providers
// -----------------------------------------------------------------

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenProvider: () =>
        ref.read(authControllerProvider).session?.jwtToken,
  );
});

final repositoryProvider =
    Provider<GciRepository>((ref) => GciRepository(ref.watch(apiClientProvider)));
