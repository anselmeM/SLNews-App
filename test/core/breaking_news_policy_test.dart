import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/breaking_news_policy.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 11, 22, 12);

  BreakingAssessment assess({
    required String title,
    String summary = '',
    String categoryId = 'top',
    bool isWire = false,
    bool editorFlagged = false,
    DateTime? publishedAt,
  }) {
    return BreakingNewsPolicy.assess(
      title: title,
      summary: summary,
      categoryId: categoryId,
      publishedAt: publishedAt ?? now.subtract(const Duration(minutes: 20)),
      isWire: isWire,
      editorFlagged: editorFlagged,
      now: now,
    );
  }

  test('promotes a fresh explosion report', () {
    final BreakingAssessment result = assess(
      title: 'Breaking: explosion at Freetown market',
      categoryId: 'top',
    );
    expect(result.isBreaking, isTrue);
    expect(result.reasons, contains('urgency'));
  });

  test('promotes a state-of-emergency declaration', () {
    final BreakingAssessment result = assess(
      title: 'President declares state of emergency',
      categoryId: 'politics',
    );
    expect(result.isBreaking, isTrue);
  });

  test('does not promote routine government reviews', () {
    final BreakingAssessment result = assess(
      title: 'Government orders legal review of steel plant',
      categoryId: 'politics',
    );
    expect(result.isBreaking, isFalse);
  });

  test('does not promote routine sports results', () {
    final BreakingAssessment result = assess(
      title: 'Leone Stars level with Guinea in AFCON qualifier',
      categoryId: 'sports',
      isWire: true,
    );
    expect(result.isBreaking, isFalse);
  });

  test('does not promote stale disasters', () {
    final BreakingAssessment result = assess(
      title: 'Explosion at market',
      categoryId: 'top',
      publishedAt: now.subtract(const Duration(days: 2)),
    );
    expect(result.isBreaking, isFalse);
  });

  test('ignores an unsupported editor flag without impact', () {
    final BreakingAssessment result = assess(
      title: 'Budget passes',
      categoryId: 'business',
      editorFlagged: true,
      isWire: true,
    );
    // The policy still requires an impact/urgency signal; a bare flag is not
    // enough to put a routine budget story in the breaking banner.
    expect(result.isBreaking, isFalse);
  });

  test('promotes a curated urgent wire story', () {
    final BreakingAssessment result = assess(
      title: 'Breaking: casualties reported in ferry accident',
      categoryId: 'top',
      isWire: true,
      editorFlagged: true,
    );
    expect(result.isBreaking, isTrue);
    expect(result.score, greaterThanOrEqualTo(BreakingNewsPolicy.threshold));
  });

  test('normalizes a stale cached flag without mutating the article', () {
    const Publisher publisher = Publisher(
      id: 'awoko',
      name: 'Awoko',
      wordmark: 'AWOKO',
    );
    final Article routine = Article(
      id: 'a',
      title: 'Government orders legal review',
      summary: 'A review of a plant.',
      bodyHtml: '<p>Review.</p>',
      publisher: publisher,
      categoryId: 'politics',
      publishedAt: now.subtract(const Duration(minutes: 10)),
      isBreaking: true,
    );
    final Article fixed = BreakingNewsPolicy.normalize(routine, now: now);
    expect(routine.isBreaking, isTrue);
    expect(fixed.isBreaking, isFalse);
  });
}
