import 'dart:async';
import 'dart:convert';

import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';

import '../core/config.dart';
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
      'reviewer_id': reviewerId,
      'prompt_text': promptText,
      'user_reasoning': userReasoning ?? '',
      'probability_estimate': probabilityEstimate ?? 0.5,
      'sample_size': sampleSize,
      'mode': 'exploration',
    });
    if (resp.statusCode != 200) {
      final detail = _detailOf(resp.data)?.toLowerCase() ?? '';
      if (detail.contains('no propositions') ||
          detail.contains('no_propositions')) {
        return const [];
      }
      throw GciApiException(
          _detailOf(resp.data) ?? 'Failed to load ideas to review');
    }
    final data = resp.data;
    final list = data is Map
        ? (data['samples'] ?? data['propositions'] ?? data['ideas'] ?? [])
        : data;
    return ((list as List?) ?? const [])
        .whereType<Map>()
        .map((p) => PeerIdea.fromJson(p.cast<String, dynamic>()))
        .where((p) => p.id.isNotEmpty)
        .toList();
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
  // Live updates (SSE)
  // ---------------------------------------------------------------

  /// Subscribe to the jam's live event channel. Emits whenever proposition or
  /// review counts change server-side.
  Stream<JamUpdateEvent> jamEvents(String jamId) {
    return SSEClient.subscribeToSSE(
      method: SSERequestType.GET,
      url: '${AppConfig.apiBaseUrl}/api/jams/$jamId/events',
      header: {'Accept': 'text/event-stream'},
    ).where((event) => (event.data ?? '').trim().isNotEmpty).map((event) {
      try {
        final json = jsonDecode(event.data!.trim()) as Map<String, dynamic>;
        return JamUpdateEvent.fromJson(json);
      } catch (_) {
        return const JamUpdateEvent(propositions: -1, reviews: -1);
      }
    }).where((e) => e.propositions >= 0);
  }

  void closeJamEvents() => SSEClient.unsubscribeFromSSE();

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
