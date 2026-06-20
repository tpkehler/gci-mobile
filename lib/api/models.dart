/// Typed models for the gcibmn REST API.
///
/// The API returns loosely-shaped JSON in places (jam config lives in a JSONB
/// column), so parsing is defensive: missing fields fall back to sane
/// defaults instead of throwing.
library;

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _toInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

class JamSummaryFunnel {
  const JamSummaryFunnel({
    required this.invited,
    required this.participants,
    required this.humans,
    required this.agents,
    required this.responded,
    required this.responses,
    required this.reviewers,
    required this.reviews,
  });

  final int invited;
  final int participants;
  final int humans;
  final int agents;
  final int responded;
  final int responses;
  final int reviewers;
  final int reviews;

  factory JamSummaryFunnel.fromJson(Map<String, dynamic> json) =>
      JamSummaryFunnel(
        invited: _toInt(json['invited']),
        participants: _toInt(json['participants']),
        humans: _toInt(json['humans']),
        agents: _toInt(json['agents']),
        responded: _toInt(json['responded']),
        responses: _toInt(json['responses']),
        reviewers: _toInt(json['reviewers']),
        reviews: _toInt(json['reviews']),
      );
}

class JamPromptStat {
  const JamPromptStat({
    required this.order,
    required this.text,
    required this.type,
    required this.responseCount,
    this.meanProbability,
  });

  final int order;
  final String text;
  final String type;
  final int responseCount;
  final double? meanProbability;

  factory JamPromptStat.fromJson(Map<String, dynamic> json) => JamPromptStat(
        order: _toInt(json['order']),
        text: json['text'] as String? ?? '',
        type: json['type'] as String? ?? 'prediction',
        responseCount: _toInt(json['responses'] ?? json['response_count']),
        meanProbability: _toDouble(json['mean_probability']),
      );
}

class TopIdea {
  const TopIdea({
    required this.text,
    required this.contributorName,
    this.relevance,
  });

  final String text;
  final String contributorName;
  final double? relevance;

  factory TopIdea.fromJson(Map<String, dynamic> json) => TopIdea(
        text: json['text'] as String? ?? '',
        contributorName: json['contributor_name'] as String? ?? 'Unknown',
        relevance: _toDouble(json['relevance'] ?? json['reason_relevancy']),
      );
}

class JamSummary {
  const JamSummary({
    required this.jamId,
    required this.title,
    required this.description,
    required this.status,
    required this.funnel,
    required this.prompts,
    required this.topIdeas,
    this.creatorName,
    this.createdAt,
  });

  final String jamId;
  final String title;
  final String description;
  final String status;
  final JamSummaryFunnel funnel;
  final List<JamPromptStat> prompts;
  final List<TopIdea> topIdeas;
  final String? creatorName;
  final String? createdAt;

  factory JamSummary.fromJson(Map<String, dynamic> json) => JamSummary(
        jamId: json['jam_id'] as String? ?? json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled Jam',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'unknown',
        creatorName: json['creator_name'] as String?,
        createdAt: json['created_at'] as String?,
        funnel: JamSummaryFunnel.fromJson(
            (json['funnel'] as Map?)?.cast<String, dynamic>() ?? const {}),
        prompts: ((json['prompts'] as List?) ?? const [])
            .whereType<Map>()
            .map((p) => JamPromptStat.fromJson(p.cast<String, dynamic>()))
            .toList(),
        topIdeas: ((json['top_ideas'] as List?) ?? const [])
            .whereType<Map>()
            .map((p) => TopIdea.fromJson(p.cast<String, dynamic>()))
            .toList(),
      );
}

/// A jam as returned by list endpoints (dashboard, active collaborations)
/// and `GET /api/jams/{id}`.
class Jam {
  const Jam({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.creatorId,
    this.creatorName,
    this.createdAt,
    this.isPublic = false,
    this.participantCount,
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final String? creatorId;
  final String? creatorName;
  final String? createdAt;
  final bool isPublic;
  final int? participantCount;

  bool get isArchived => status == 'archived';

  factory Jam.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['jam_id'] ?? '') as String;
    var title = json['title'] as String? ?? '';
    final description = json['description'] as String? ?? '';
    // Some legacy rows store a UUID in title; mirror the web fallback.
    final uuidRe = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    if (title.isEmpty || uuidRe.hasMatch(title.trim())) {
      title = description.isNotEmpty ? description : 'Untitled Jam';
    }
    return Jam(
      id: id,
      title: title,
      description: description,
      status: json['status'] as String? ?? 'unknown',
      creatorId: json['creator_id'] as String?,
      creatorName: json['creator_name'] as String?,
      createdAt: json['created_at'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      participantCount: json['participant_count'] == null
          ? null
          : _toInt(json['participant_count']),
    );
  }
}

/// A participation prompt from `GET /api/jams/{id}/questions`.
class JamPrompt {
  const JamPrompt({
    required this.id,
    required this.text,
    required this.orderIndex,
    required this.promptType,
    this.requireProbability = true,
    this.requireReasoning = true,
    this.minReasoningLength,
    this.maxReasoningLength,
  });

  final String id;
  final String text;
  final int orderIndex;

  /// prediction | reasoning | qualitative
  final String promptType;
  final bool requireProbability;
  final bool requireReasoning;
  final int? minReasoningLength;
  final int? maxReasoningLength;

  bool get isPrediction => promptType == 'prediction';
  bool get isQualitative => promptType == 'qualitative';

  factory JamPrompt.fromJson(Map<String, dynamic> json) => JamPrompt(
        id: json['id'] as String? ?? '${json['order'] ?? json['order_index']}',
        text: json['text'] as String? ?? json['prompt_text'] as String? ?? '',
        orderIndex: _toInt(json['order_index'] ?? json['order']),
        promptType: json['prompt_type'] as String? ??
            json['type'] as String? ??
            'prediction',
        requireProbability: json['require_probability'] as bool? ?? true,
        requireReasoning: json['require_reasoning'] as bool? ?? true,
        minReasoningLength: json['min_reasoning_length'] == null
            ? null
            : _toInt(json['min_reasoning_length']),
        maxReasoningLength: json['max_reasoning_length'] == null
            ? null
            : _toInt(json['max_reasoning_length']),
      );
}

/// Per-user progress from `GET /api/user-responses/status/{jam}/{user}`.
class ParticipationStatus {
  const ParticipationStatus({
    required this.respondedOrders,
    required this.reviewedOrders,
  });

  final Set<int> respondedOrders;
  final Set<int> reviewedOrders;

  factory ParticipationStatus.fromJson(Map<String, dynamic> json) =>
      ParticipationStatus(
        respondedOrders: ((json['responded_orders'] as List?) ?? const [])
            .map((e) => _toInt(e))
            .toSet(),
        reviewedOrders: ((json['reviewed_orders'] as List?) ?? const [])
            .map((e) => _toInt(e))
            .toSet(),
      );
}

/// A peer idea to review, from `POST /api/beta-sampling/generate`.
class PeerIdea {
  const PeerIdea({
    required this.id,
    required this.text,
    this.contributorName,
    this.contributorId,
    this.probabilityEstimate,
  });

  final String id;
  final String text;
  final String? contributorName;
  final String? contributorId;
  final double? probabilityEstimate;

  factory PeerIdea.fromJson(Map<String, dynamic> json) => PeerIdea(
        id: (json['id'] ?? json['proposition_id'] ?? '') as String,
        text: json['text'] as String? ?? json['reasoning'] as String? ?? '',
        contributorName: json['contributor_name'] as String?,
        contributorId: json['contributor_id'] as String?,
        probabilityEstimate: _toDouble(json['probability_estimate']),
      );
}

/// An idea in the warm-up discussion (IdeaJam), from
/// `GET /api/jams/{id}/propositions`. This is a proposition surfaced as a
/// Slack-like discussion item that can be queried, built-on, or flagged.
class Idea {
  const Idea({
    required this.id,
    required this.text,
    required this.contributorName,
    required this.participantType,
    this.contributorId,
    this.contributorReason,
    this.contributorRating,
    this.promptOrder,
    this.createdAt,
  });

  final String id;
  final String text;
  final String contributorName;

  /// 'human' | 'ai_agent'
  final String participantType;
  final String? contributorId;
  final String? contributorReason;
  final int? contributorRating;
  final int? promptOrder;
  final String? createdAt;

  bool get isAi => participantType == 'ai_agent';

  factory Idea.fromJson(Map<String, dynamic> json) => Idea(
        id: (json['proposition_id'] ?? json['id'] ?? '') as String,
        text: json['text'] as String? ?? '',
        contributorName: json['contributor_name'] as String? ?? 'Unknown',
        participantType: json['participant_type'] as String? ?? 'human',
        contributorId: json['contributor_id'] as String?,
        contributorReason: json['contributor_reason'] as String?,
        contributorRating: json['contributor_rating'] == null
            ? null
            : _toInt(json['contributor_rating']),
        promptOrder:
            json['prompt_order'] == null ? null : _toInt(json['prompt_order']),
        createdAt: json['created_at'] as String?,
      );
}

/// A reply/question on an idea, from
/// `GET /api/propositions/{id}/replies`. When the idea's author is an AI agent,
/// `agentResponse` carries the answer.
class IdeaReply {
  const IdeaReply({
    required this.id,
    required this.promptText,
    required this.questionerName,
    required this.questionerType,
    required this.status,
    this.agentResponse,
    this.responseTimestamp,
    this.createdAt,
  });

  final String id;
  final String promptText;
  final String questionerName;

  /// 'human' | 'ai_agent'
  final String questionerType;
  final String status;
  final String? agentResponse;
  final String? responseTimestamp;
  final String? createdAt;

  bool get hasAnswer => (agentResponse ?? '').isNotEmpty;

  factory IdeaReply.fromJson(Map<String, dynamic> json) => IdeaReply(
        id: (json['id'] ?? '') as String,
        promptText: json['prompt_text'] as String? ?? '',
        questionerName: json['questioner_name'] as String? ?? 'Unknown',
        questionerType: json['questioner_type'] as String? ?? 'human',
        status: json['status'] as String? ?? 'pending',
        agentResponse: json['agent_response'] as String?,
        responseTimestamp: json['response_timestamp'] as String?,
        createdAt: json['created_at'] as String?,
      );
}

/// Sentiment for a peer review, matching the web payloads.
enum ReviewSentiment {
  agree,
  needInfo,
  disagree;

  String get wireValue => switch (this) {
        ReviewSentiment.agree => 'agree',
        ReviewSentiment.needInfo => 'need_info',
        ReviewSentiment.disagree => 'disagree',
      };

  String get label => switch (this) {
        ReviewSentiment.agree => 'Agree',
        ReviewSentiment.needInfo => 'Need Info',
        ReviewSentiment.disagree => 'Disagree',
      };
}

class PeerReview {
  const PeerReview({
    required this.propositionId,
    required this.sentiment,
    this.priorityPosition,
    this.comment,
    this.responseTimeMs,
  });

  final String propositionId;
  final ReviewSentiment sentiment;
  final int? priorityPosition;
  final String? comment;
  final int? responseTimeMs;

  Map<String, dynamic> toJson() => {
        'proposition_id': propositionId,
        'sentiment': sentiment.wireValue,
        if (priorityPosition != null) 'priority_position': priorityPosition,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
        if (responseTimeMs != null) 'response_time_ms': responseTimeMs,
      };
}

/// Dashboard payload from `GET /api/dashboard/{user_id}`.
class DashboardData {
  const DashboardData({
    required this.createdJams,
    required this.contributingJams,
  });

  final List<Jam> createdJams;
  final List<Jam> contributingJams;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    List<Jam> parse(dynamic list) => ((list as List?) ?? const [])
        .whereType<Map>()
        .map((j) => Jam.fromJson(j.cast<String, dynamic>()))
        .toList();
    return DashboardData(
      createdJams: parse(json['created_collaborations']),
      contributingJams: parse(json['contributing_collaborations']),
    );
  }
}

class AuthResult {
  const AuthResult({
    required this.success,
    this.userId,
    this.name,
    this.email,
    this.jwtToken,
    this.error,
  });

  final bool success;
  final String? userId;
  final String? name;
  final String? email;
  final String? jwtToken;
  final String? error;
}

// ---------------------------------------------------------------
// Collective Voice, BBN, Personal Wiki
// ---------------------------------------------------------------

class CollectiveVoiceSource {
  const CollectiveVoiceSource({
    required this.propositionId,
    required this.text,
    required this.contributorName,
    this.contributorExpertise,
    this.similarityScore = 0,
    this.relevanceScore = 0,
  });

  final String propositionId;
  final String text;
  final String contributorName;
  final String? contributorExpertise;
  final double similarityScore;
  final double relevanceScore;

  factory CollectiveVoiceSource.fromJson(Map<String, dynamic> json) =>
      CollectiveVoiceSource(
        propositionId: json['proposition_id']?.toString() ?? '',
        text: json['text'] as String? ?? '',
        contributorName: json['contributor_name'] as String? ?? 'Anonymous',
        contributorExpertise: json['contributor_expertise'] as String?,
        similarityScore: _toDouble(json['similarity_score']) ?? 0,
        relevanceScore: _toDouble(json['relevance_score']) ?? 0,
      );
}

class CollectiveVoiceResponse {
  const CollectiveVoiceResponse({
    required this.answer,
    required this.sources,
    required this.question,
  });

  final String answer;
  final List<CollectiveVoiceSource> sources;
  final String question;

  factory CollectiveVoiceResponse.fromJson(Map<String, dynamic> json) =>
      CollectiveVoiceResponse(
        answer: json['answer'] as String? ?? '',
        question: json['question'] as String? ?? '',
        sources: ((json['sources'] as List?) ?? const [])
            .whereType<Map>()
            .map((s) =>
                CollectiveVoiceSource.fromJson(s.cast<String, dynamic>()))
            .toList(),
      );
}

class BbnThemeSummary {
  const BbnThemeSummary({
    required this.label,
    required this.probability,
    required this.reasonCount,
  });

  final String label;
  final double? probability;
  final int reasonCount;

  factory BbnThemeSummary.fromJson(Map<String, dynamic> json) => BbnThemeSummary(
        label: json['label'] as String? ??
            'Theme ${json['theme_id'] ?? ''}'.trim(),
        probability: _toDouble(json['probability']),
        reasonCount: _toInt(json['n_reasons']),
      );
}

class BbnReasonSummary {
  const BbnReasonSummary({
    required this.text,
    required this.probability,
  });

  final String text;
  final double probability;

  factory BbnReasonSummary.fromJson(Map<String, dynamic> json) => BbnReasonSummary(
        text: json['text'] as String? ?? '',
        probability: _toDouble(json['probability']) ?? 0,
      );
}

class BbnSummary {
  const BbnSummary({
    required this.success,
    this.error,
    this.finalCscore,
    this.method,
    this.themes = const [],
    this.topReasons = const [],
  });

  final bool success;
  final String? error;
  final double? finalCscore;
  final String? method;
  final List<BbnThemeSummary> themes;
  final List<BbnReasonSummary> topReasons;

  factory BbnSummary.fromJson(Map<String, dynamic> json) {
    if (json['success'] == false) {
      return BbnSummary(
        success: false,
        error: json['error']?.toString() ?? 'BBN unavailable',
      );
    }
    final layers = json['layers'];
    final layerMap = layers is Map ? layers.cast<String, dynamic>() : null;
    final layer4 = layerMap?['layer_4_collective'];
    final layer2 = layerMap?['layer_2_themes'];
    final layer1 = layerMap?['layer_1_reasons'];
    final themes = ((layer2 is Map ? layer2['themes'] : null) as List?) ?? const [];
    final reasons = ((layer1 is Map ? layer1['reasons'] : null) as List?) ?? const [];
    final parsedReasons = reasons
        .whereType<Map>()
        .map((r) => BbnReasonSummary.fromJson(r.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => b.probability.compareTo(a.probability));
    return BbnSummary(
      success: true,
      finalCscore: _toDouble(json['final_cscore']) ??
          _toDouble((json['summary'] is Map
              ? (json['summary'] as Map)['final_cscore']
              : null)),
      method: layer4 is Map ? layer4['method']?.toString() : null,
      themes: themes
          .whereType<Map>()
          .map((t) => BbnThemeSummary.fromJson(t.cast<String, dynamic>()))
          .where((t) => t.reasonCount > 0 && t.probability != null)
          .toList(),
      topReasons: parsedReasons.take(8).toList(),
    );
  }

  factory BbnSummary.fromVisualizationJson(Map<String, dynamic> json) {
    if (json['success'] == false) {
      return BbnSummary(
        success: false,
        error: json['error']?.toString() ?? 'BBN unavailable',
      );
    }
    final summary = json['summary'];
    final summaryMap = summary is Map ? summary.cast<String, dynamic>() : null;
    return BbnSummary(
      success: true,
      finalCscore: _toDouble(summaryMap?['final_cscore']),
      method: summaryMap?['collective_score_method']?.toString(),
      themes: const [],
      topReasons: const [],
    );
  }
}

class WikiPageMeta {
  const WikiPageMeta({required this.title, this.updatedAt});

  final String title;
  final String? updatedAt;

  factory WikiPageMeta.fromJson(Map<String, dynamic> json) => WikiPageMeta(
        title: json['title'] as String? ?? 'Untitled',
        updatedAt: json['updated_at'] as String?,
      );
}

class WikiSummary {
  const WikiSummary({
    required this.pageCount,
    this.lastIngestedAt,
    this.pages = const {},
  });

  final int pageCount;
  final String? lastIngestedAt;
  final Map<String, WikiPageMeta> pages;

  factory WikiSummary.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'];
    final pages = <String, WikiPageMeta>{};
    if (rawPages is Map) {
      rawPages.forEach((key, value) {
        if (value is Map) {
          pages[key.toString()] =
              WikiPageMeta.fromJson(value.cast<String, dynamic>());
        }
      });
    }
    return WikiSummary(
      pageCount: _toInt(json['page_count']),
      lastIngestedAt: json['last_ingested_at'] as String?,
      pages: pages,
    );
  }
}

class WikiPageContent {
  const WikiPageContent({required this.slug, required this.content});

  final String slug;
  final String content;

  factory WikiPageContent.fromJson(Map<String, dynamic> json, String slug) =>
      WikiPageContent(
        slug: json['slug'] as String? ?? slug,
        content: json['content'] as String? ?? '',
      );
}

class WikiQueryResponse {
  const WikiQueryResponse({required this.answer});

  final String answer;

  factory WikiQueryResponse.fromJson(Map<String, dynamic> json) =>
      WikiQueryResponse(answer: json['answer'] as String? ?? '');
}
