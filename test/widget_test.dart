import 'package:flutter_test/flutter_test.dart';
import 'package:gci_mobile/api/models.dart';

void main() {
  test('JamSummary parses funnel and prompts', () {
    final summary = JamSummary.fromJson({
      'jam_id': 'abc',
      'title': 'Test Jam',
      'status': 'active',
      'funnel': {'invited': 5, 'participants': 3, 'responses': 4},
      'prompts': [
        {'order': 0, 'text': 'Will it rain?', 'mean_probability': 0.4}
      ],
      'top_ideas': [
        {'text': 'An idea', 'contributor_name': 'Sam', 'relevance': 0.9}
      ],
    });
    expect(summary.title, 'Test Jam');
    expect(summary.funnel.invited, 5);
    expect(summary.prompts.single.meanProbability, 0.4);
    expect(summary.topIdeas.single.contributorName, 'Sam');
  });

  test('PeerReview serializes wire sentiment values', () {
    const review = PeerReview(
      propositionId: 'p1',
      sentiment: ReviewSentiment.needInfo,
      priorityPosition: 2,
      comment: 'interesting',
    );
    final json = review.toJson();
    expect(json['sentiment'], 'need_info');
    expect(json['priority_position'], 2);
  });
}
