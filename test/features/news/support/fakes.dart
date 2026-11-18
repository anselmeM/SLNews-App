import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';

export '../../../support/fakes.dart';

/// Publisher used by every News fixture story.
const Publisher kFakePublisher = Publisher(
  id: 'slnews',
  name: 'SLNews Desk',
  wordmark: 'SLNEWS',
  country: 'Sierra Leone',
);

/// A fixed clock so relative-age labels stay deterministic.
final DateTime kFakeNow = DateTime(2026, 10, 15, 12);

/// Builds a fixture story in [categoryId], [minutesAgo] minutes before
/// [kFakeNow].
Article fakeArticle({
  required String id,
  required String title,
  String categoryId = 'top',
  int minutesAgo = 0,
  bool isBreaking = false,
  bool isLive = false,
  String summary = '',
  String? imageUrl,
}) {
  return Article(
    id: id,
    title: title,
    summary: summary,
    publisher: kFakePublisher,
    publishedAt: kFakeNow.subtract(Duration(minutes: minutesAgo)),
    categoryId: categoryId,
    isBreaking: isBreaking,
    isLive: isLive,
  );
}

/// A Sierra Leonean headline comfortably over 60 characters, used to prove the
/// cards ellipsize instead of clipping.
const String kLongHeadline =
    'Freetown City Council unveils a new drainage master plan for the central business district';

/// The fixture feed: `top` has a hero, a grid and enough rows for the inline ad
/// slot; `politics` has its own hero; every other category is empty so the empty
/// state is reachable from the pill strip.
Map<String, List<Article>> defaultNewsFixtures() => <String, List<Article>>{
  'top': <Article>[
    fakeArticle(
      id: 'top-hero',
      title:
          'Bo government hospital receives new dialysis machines from partners',
      summary:
          'The donation covers two years of consumables for the renal unit.',
    ),
    for (int index = 2; index <= 11; index++)
      fakeArticle(
        id: 'top-$index',
        title:
            'Sierra Leone news desk story number $index from the overnight wire',
        minutesAgo: index * 20,
      ),
  ],
  'politics': <Article>[
    fakeArticle(
      id: 'politics-hero',
      title: 'Parliament passes the 2026 budget after a marathon overnight sitting',
      categoryId: 'politics',
    ),
    for (int index = 2; index <= 8; index++)
      fakeArticle(
        id: 'politics-$index',
        title:
            'Politics desk follow-up $index on the budget debate in Freetown',
        categoryId: 'politics',
        minutesAgo: index * 15,
      ),
  ],
};
