import 'api_client.dart';
import 'models.dart';

/// Typed access to the gcibmn REST API.
class GciRepository {
  GciRepository(this._client);

  final ApiClient _client;

  // ---------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------

  Future<AuthResult> login(String email, String password) async {
    final resp = await _client.dio.post('/api/human-auth/login',
        data: {'email': email, 'password': password});
    final data = resp.data;
    if (resp.statusCode == 200 && data is Map && data['success'] == true) {
      return AuthResult(
        success: true,
        userId: data['user_id'] as String?,
        name: data['name'] as String? ?? 'User',
        email: data['email'] as String? ?? email,
        jwtToken: data['jwt_token'] as String?,
      );
    }
    final detail = data is Map ? (data['detail'] ?? data['error']) : null;
    return AuthResult(
        success: false, error: detail?.toString() ?? 'Login failed');
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String? jamId,
  }) async {
    final resp = await _client.dio.post('/api/human-auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      if (jamId != null) 'jam_id': jamId,
    });
    final data = resp.data;
    if ((resp.statusCode == 200 || resp.statusCode == 201) &&
        data is Map &&
        data['success'] == true) {
      return AuthResult(success: true, userId: data['user_id'] as String?);
    }
    final detail = data is Map ? (data['detail'] ?? data['error']) : null;
    return AuthResult(
        success: false, error: detail?.toString() ?? 'Registration failed');
  }

  Future<String?> forgotPassword(String email) async {
    final resp = await _client.dio
        .post('/api/human-auth/forgot-password', data: {'email': email});
    if (resp.statusCode == 200) return null;
    final data = resp.data;
    return data is Map
        ? (data['detail']?.toString() ?? 'Request failed')
        : 'Request failed';
  }

  // ---------------------------------------------------------------
  // Jams: discovery, detail, summary
  // ---------------------------------------------------------------

  Future<DashboardData> fetchDashboard(String userId) async {
    final resp = await _client.dio.get('/api/dashboard/$userId');
    _ensureOk(resp.statusCode, 'load dashboard');
    return DashboardData.fromJson(_asMap(resp.data));
  }

  Future<List<Jam>> fetchActiveJams(
      {String? userId, String? communityId}) async {
    final resp =
        await _client.dio.get('/api/collaborations/active', queryParameters: {
      if (userId != null) 'user_id': userId,
      if (communityId != null) 'community_id': communityId,
    });
    _ensureOk(resp.statusCode, 'load jams');
    final data = resp.data;
    final list = data is Map
        ? (data['collaborations'] ?? data['jams'] ?? data['sessions'] ?? [])
        : data;
    return ((list as List?) ?? const [])
        .whereType<Map>()
        .map((j) => Jam.fromJson(j.cast<String, dynamic>()))
        .toList();
  }

  Future<Jam> fetchJam(String jamId) async {
    final resp = await _client.dio.get('/api/jams/$jamId');
    _ensureOk(resp.statusCode, 'load jam');
    return Jam.fromJson(_asMap(resp.data));
  }

  Future<JamSummary> fetchJamSummary(String jamId) async {
    final resp = await _client.dio.get('/api/jams/$jamId/summary');
    _ensureOk(resp.statusCode, 'load jam summary');
    return JamSummary.fromJson(_asMap(resp.data));
  }

  // ---------------------------------------------------------------
  // Participation loop
  // ---------------------------------------------------------------

  Future<List<JamPrompt>> fetchPrompts(String jamId) async {
    final resp = await _client.dio.get('/api/jams/$jamId/questions');
    _ensureOk(resp.statusCode, 'load prompts');
    final data = resp.data;
    final list = data is Map
        ? (data['questions'] ?? data['prompts'] ?? [])
        : data;
    final prompts = ((list as List?) ?? const [])
        .whereType<Map>()
        .map((p) => JamPrompt.fromJson(p.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return prompts;
  }

  Future<ParticipationStatus> fetchParticipationStatus({
    required String jamId,
    required String userId,
    String? email,
  }) async {
    final resp = await _client.dio.get(
      '/api/user-responses/status/$jamId/$userId',
      queryParameters: {if (email != null && email.isNotEmpty) 'email': email},
    );
    if (resp.statusCode == 404) {
      return const ParticipationStatus(
          respondedOrders: {}, reviewedOrders: {});
    }
    _ensureOk(resp.statusCode, 'load progress');
    return ParticipationStatus.fromJson(_asMap(resp.data));
  }

  /// Submit a response. Mirrors the web `PromptTab` payload; auto-enrolls the
  /// user in the jam on first submit.
  Future<void> submitResponse({
    required String jamId,
    required String userId,
    required String userName,
    required String userEmail,
    required String reasoningText,
    required JamPrompt prompt,
    double? probabilityEstimate,
  }) async {
    final resp = await _client.dio.post('/api/user-responses/submit', data: {
      'jam_id': jamId,
      'template_id': jamId,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'reasoning_text': reasoningText,
      'question_order': prompt.orderIndex,
      'question_id': prompt.id,
      'question_text': prompt.text,
      'is_qualitative_only': !prompt.requireProbability,
      if (prompt.requireProbability && probabilityEstimate != null)
        'probability_estimate': probabilityEstimate,
    });
    _ensureOk(resp.statusCode, 'submit response',
        detail: _detailOf(resp.data));
  }

  /// Load peer ideas to review. Returns an empty list when no peer
  /// propositions exist yet (the "waiting for others" state).
  Future<List<PeerIdea>> fetchPeerIdeas({
    required String jamId,
    required String reviewerId,
    required String promptText,
    String? userReasoning,
    double? probabilityEstimate,
    int sampleSize = 7,
  }) async {
    final resp = await _client.dio.post('/api/beta-sampling/generate', data: {
      'jam_id': jamId,
      'template_id': jamId,
      'reviewer_id': reviewerId,
      'prompt_text': promptText,
      'user_reasoning': userReasoning ?? '',
      'probability_estimate': probabilityEstimate ?? 0.5,
      // Pure exploration. This keeps the backend on its robust weighted-random
      // selection path (matching the web client). Omitting it defaults to 0.5
      // server-side, which routes into the exploitation branch and returns an
      // empty set whenever relevance scoring is unavailable — the app then
      // mistakes that for "no peers yet" and waits forever.
      'lambda_value': 0.0,
      'sample_size': sampleSize,
      'mode': 'exploration',
    });

    // Non-2xx: a genuinely empty proposition pool means "wait for peers";
    // anything else is a real error the reviewer should see.
    if (resp.statusCode != 200) {
      if (_isNoPropositions(_detailOf(resp.data))) return const [];
      throw GciApiException(
          _detailOf(resp.data) ?? 'Failed to load ideas to review');
    }

    final data = resp.data;
    final list = data is Map
        ? (data['samples'] ?? data['propositions'] ?? data['ideas'] ?? [])
        : data;
    final ideas = ((list as List?) ?? const [])
        .whereType<Map>()
        .map((p) => PeerIdea.fromJson(p.cast<String, dynamic>()))
        .where((p) => p.id.isNotEmpty)
        .toList();
    if (ideas.isNotEmpty) return ideas;

    // Empty sample set on a 200. The backend returns `samples: []` for several
    // distinct reasons, recorded in `sampling_metadata.error_type`. Only the
    // "no propositions yet" case should put the reviewer in a waiting state;
    // every other case is a sampler error and must surface (so the UI shows an
    // error with retry) instead of looping in the waiting room.
    final meta = data is Map ? data['sampling_metadata'] : null;
    final errorType = meta is Map ? meta['error_type']?.toString() : null;
    const waitErrorTypes = {'no_propositions_in_session', 'no_propositions'};
    if (errorType == null || waitErrorTypes.contains(errorType)) {
      return const []; // genuinely waiting for peer ideas
    }
    final message = meta is Map ? meta['error']?.toString() : null;
    throw GciApiException(
        message ?? 'Could not load ideas to review ($errorType)');
  }

  bool _isNoPropositions(String? detail) {
    final d = detail?.toLowerCase() ?? '';
    return d.contains('no propositions') || d.contains('no_propositions');
  }

  Future<void> submitReviews({
    required String jamId,
    required String reviewerId,
    required List<PeerReview> reviews,
    required int totalRanked,
  }) async {
    final resp = await _client.dio.post('/api/peer-review/submit-batch', data: {
      'jam_id': jamId,
      'reviewer_id': reviewerId,
      'reviews': reviews.map((r) => r.toJson()).toList(),
      'total_ranked': totalRanked,
    });
    _ensureOk(resp.statusCode, 'submit reviews', detail: _detailOf(resp.data));
  }

  // ---------------------------------------------------------------
  // IdeaJam: warm-up discussion (browse, query, build-on, flag)
  // ---------------------------------------------------------------

  /// All ideas in a jam's discussion, newest first.
  Future<List<Idea>> fetchIdeas(String jamId) async {
    final resp = await _client.dio.get('/api/jams/$jamId/propositions');
    _ensureOk(resp.statusCode, 'load discussion', detail: _detailOf(resp.data));
    final data = resp.data;
    final list = data is Map ? (data['propositions'] ?? data['ideas'] ?? []) : data;
    final ideas = ((list as List?) ?? const [])
        .whereType<Map>()
        .map((p) => Idea.fromJson(p.cast<String, dynamic>()))
        .where((i) => i.id.isNotEmpty)
        .toList()
      ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return ideas;
  }

  /// Replies/questions on a single idea, oldest first.
  Future<List<IdeaReply>> fetchReplies(String ideaId) async {
    final resp = await _client.dio.get('/api/propositions/$ideaId/replies');
    _ensureOk(resp.statusCode, 'load replies', detail: _detailOf(resp.data));
    final data = resp.data;
    final list = data is Map ? (data['replies'] ?? []) : data;
    return ((list as List?) ?? const [])
        .whereType<Map>()
        .map((r) => IdeaReply.fromJson(r.cast<String, dynamic>()))
        .toList();
  }

  /// Ask a question on an idea. When the idea's author is an AI agent, the
  /// backend generates an answer asynchronously (surfaced on the reply).
  Future<void> postReply({
    required String ideaId,
    required String questionerId,
    required String questionerName,
    required String promptText,
  }) async {
    final resp =
        await _client.dio.post('/api/propositions/$ideaId/replies', data: {
      'prompt_text': promptText,
      'questioner_id': questionerId,
      'questioner_name': questionerName,
      'questioner_type': 'human',
    });
    _ensureOk(resp.statusCode, 'post question', detail: _detailOf(resp.data));
  }

  /// Create a new idea that builds on an existing one.
  Future<void> buildOnIdea({
    required String ideaId,
    required String jamId,
    required String builderId,
    required String builderName,
    required String newIdeaText,
  }) async {
    final resp =
        await _client.dio.post('/api/propositions/$ideaId/build-on', data: {
      'new_idea_text': newIdeaText,
      'builder_id': builderId,
      'builder_name': builderName,
      'builder_type': 'human',
      'jam_id': jamId,
    });
    _ensureOk(resp.statusCode, 'build on idea', detail: _detailOf(resp.data));
  }

  /// Flag an idea (misinformation | suspicious | inappropriate).
  Future<void> flagIdea({
    required String ideaId,
    required String flagName,
    required String whoFlagged,
    String? reason,
  }) async {
    final resp = await _client.dio.post('/api/propositions/$ideaId/flag', data: {
      'flag_name': flagName,
      'who_flagged': whoFlagged,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    _ensureOk(resp.statusCode, 'flag idea', detail: _detailOf(resp.data));
  }

  // ---------------------------------------------------------------
  // Light creator
  // ---------------------------------------------------------------

  Future<String> createJam({
    required String title,
    required String description,
    required String creatorId,
    required List<Map<String, dynamic>> prompts,
    bool isPublic = false,
  }) async {
    final resp = await _client.dio.post('/api/jams', data: {
      'title': title,
      'description': description,
      'creator_id': creatorId,
      'is_public': isPublic,
      'prompts': prompts,
    });
    _ensureOk(resp.statusCode, 'create jam', detail: _detailOf(resp.data));
    final data = _asMap(resp.data);
    final id = (data['jam_id'] ?? data['id'])?.toString();
    if (id == null || id.isEmpty) {
      throw const GciApiException('Jam created but no id was returned');
    }
    return id;
  }

  Future<void> updateJam(String jamId, Map<String, dynamic> updates) async {
    final resp = await _client.dio.put('/api/jams/$jamId', data: updates);
    _ensureOk(resp.statusCode, 'update jam', detail: _detailOf(resp.data));
  }

  Future<void> launchJam(String jamId, {String? userId}) async {
    final resp = await _client.dio.post('/api/jams/$jamId/launch',
        data: {if (userId != null) 'user_id': userId});
    _ensureOk(resp.statusCode, 'launch jam', detail: _detailOf(resp.data));
  }

  Future<void> archiveJam(String jamId, String userId) async {
    final resp = await _client.dio.post(
        '/api/collaborations/$jamId/archive',
        queryParameters: {'user_id': userId});
    _ensureOk(resp.statusCode, 'archive jam', detail: _detailOf(resp.data));
  }

  Future<void> restoreJam(String jamId, String userId) async {
    final resp = await _client.dio.put('/api/jams/$jamId/restore',
        queryParameters: {'user_id': userId});
    _ensureOk(resp.statusCode, 'restore jam', detail: _detailOf(resp.data));
  }

  /// Email invitations (requires JWT — interceptor adds it).
  Future<void> sendInvitations({
    required String jamId,
    required List<String> emails,
  }) async {
    final resp = await _client.dio.post('/api/human-auth/send-invitations',
        data: {'jam_id': jamId, 'emails': emails});
    _ensureOk(resp.statusCode, 'send invitations',
        detail: _detailOf(resp.data));
  }

  // ---------------------------------------------------------------
  // Collective Voice, BBN, Personal Wiki
  // ---------------------------------------------------------------

  Future<CollectiveVoiceResponse> queryCollectiveVoice({
    required String jamId,
    required String question,
    int maxSources = 5,
  }) async {
    final resp = await _client.dio.post('/api/collective-voice/query', data: {
      'jam_id': jamId,
      'question': question,
      'max_sources': maxSources,
    });
    _ensureOk(resp.statusCode, 'query collective voice',
        detail: _detailOf(resp.data));
    return CollectiveVoiceResponse.fromJson(_asMap(resp.data));
  }

  Future<BbnSummary> fetchBbnSummary(String jamId) async {
    final calc = await _client.dio.get('/api/bbn/calculate/$jamId');
    if (calc.statusCode == 200) {
      final parsed = BbnSummary.fromJson(_asMap(calc.data));
      if (parsed.success) return parsed;
    }
    final viz = await _client.dio.get('/api/bbn/visualization/$jamId');
    _ensureOk(viz.statusCode, 'load belief map', detail: _detailOf(viz.data));
    final fallback = BbnSummary.fromVisualizationJson(_asMap(viz.data));
    if (fallback.success) return fallback;
    if (calc.statusCode == 200) {
      return BbnSummary.fromJson(_asMap(calc.data));
    }
    _ensureOk(calc.statusCode, 'load belief map', detail: _detailOf(calc.data));
    return fallback;
  }

  Future<Map<String, dynamic>> fetchCollectiveVoiceStatus(String jamId) async {
    final resp =
        await _client.dio.get('/api/collective-voice/status/$jamId');
    _ensureOk(resp.statusCode, 'load collective voice status',
        detail: _detailOf(resp.data));
    return _asMap(resp.data);
  }

  Future<WikiSummary> fetchWiki(String userId) async {
    final resp = await _client.dio.get('/api/personal-agent/$userId/wiki');
    _ensureOk(resp.statusCode, 'load wiki', detail: _detailOf(resp.data));
    return WikiSummary.fromJson(_asMap(resp.data));
  }

  Future<WikiPageContent> fetchWikiPage(String userId, String slug) async {
    final resp =
        await _client.dio.get('/api/personal-agent/$userId/wiki/pages/$slug');
    _ensureOk(resp.statusCode, 'load wiki page', detail: _detailOf(resp.data));
    return WikiPageContent.fromJson(_asMap(resp.data), slug);
  }

  Future<WikiQueryResponse> queryWiki({
    required String userId,
    required String question,
  }) async {
    final resp = await _client.dio.post('/api/personal-agent/$userId/query',
        data: {'question': question});
    _ensureOk(resp.statusCode, 'query wiki', detail: _detailOf(resp.data));
    return WikiQueryResponse.fromJson(_asMap(resp.data));
  }

  Future<void> ingestJamToWiki({
    required String userId,
    required String jamId,
  }) async {
    final resp = await _client.dio.post(
      '/api/personal-agent/$userId/ingest-jam',
      data: {'jam_id': jamId},
    );
    _ensureOk(resp.statusCode, 'update wiki from jam',
        detail: _detailOf(resp.data));
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};

  String? _detailOf(dynamic data) =>
      data is Map ? (data['detail'] ?? data['error'])?.toString() : null;

  void _ensureOk(int? statusCode, String action, {String? detail}) {
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw GciApiException(
          detail ?? 'Failed to $action (HTTP ${statusCode ?? '?'})');
    }
  }
}

class GciApiException implements Exception {
  const GciApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
