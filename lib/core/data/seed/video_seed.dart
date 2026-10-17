import '../../domain/models/video_moment.dart';

/// Offline "Video moments" rotation.
///
/// The rail must render with no network (the app's whole premise), so a bundled
/// set mirrors what the scraper's `/v1/videos` returns for Sierra Leone
/// broadcasters. Live entries replace these whenever the API is configured and
/// returns data.
abstract final class SlVideos {
  static final List<VideoMoment> all = <VideoMoment>[
    VideoMoment(
      id: 'video:leone-stars-training',
      title: 'Leone Stars step up training ahead of AFCON qualifier',
      source: 'SLBC Sports',
      thumbnailUrl: 'https://picsum.photos/seed/slnews-video-leone/720/1280',
      url: 'https://www.youtube.com/results?search_query=leone+stars+training',
      summary: 'The squad trained in Freetown ahead of the away leg.',
      category: 'sports',
      publishedAt: DateTime.utc(2026, 10, 15, 7, 30),
    ),
    VideoMoment(
      id: 'video:freetown-flooding',
      title: 'Freetown residents assess damage after overnight flooding',
      source: 'SLBC News',
      thumbnailUrl: 'https://picsum.photos/seed/slnews-video-flood/720/1280',
      url: 'https://www.youtube.com/results?search_query=freetown+flooding',
      summary: 'Kissy and Lumley were the worst affected wards.',
      category: 'politics',
      publishedAt: DateTime.utc(2026, 10, 15, 5, 10),
    ),
    VideoMoment(
      id: 'video:bo-rangers-celebration',
      title: 'Bo Rangers fans celebrate after the late winner',
      source: 'SLBC Sports',
      thumbnailUrl: 'https://picsum.photos/seed/slnews-video-rangers/720/1280',
      url: 'https://www.youtube.com/results?search_query=bo+rangers+celebrate',
      summary: 'A stoppage-time goal kept the title race alive.',
      category: 'sports',
      publishedAt: DateTime.utc(2026, 10, 15, 2, 45),
    ),
    VideoMoment(
      id: 'video:parliament-budget',
      title: 'Parliament passes the 2027 budget after a long sitting',
      source: 'SLBC News',
      thumbnailUrl:
          'https://picsum.photos/seed/slnews-video-parliament/720/1280',
      url: 'https://www.youtube.com/results?search_query=sierra+leone+budget',
      summary: 'Finance minister says spending targets education and health.',
      category: 'politics',
      publishedAt: DateTime.utc(2026, 10, 14, 20, 0),
    ),
    VideoMoment(
      id: 'video:markets-traders',
      title: 'Market traders on the new levy: "we need clarity"',
      source: 'SLBC News',
      thumbnailUrl: 'https://picsum.photos/seed/slnews-video-market/720/1280',
      url: 'https://www.youtube.com/results?search_query=freetown+market+traders',
      summary: 'Traders in Freetown react to the revised levy.',
      category: 'business',
      publishedAt: DateTime.utc(2026, 10, 14, 16, 20),
    ),
    VideoMoment(
      id: 'video:music-festival',
      title: 'Lumley beach music festival draws a record crowd',
      source: 'SLNews Culture',
      thumbnailUrl: 'https://picsum.photos/seed/slnews-video-music/720/1280',
      url: 'https://www.youtube.com/results?search_query=lumley+beach+festival',
      summary: 'Three days of performances on the peninsula.',
      category: 'entertainment',
      publishedAt: DateTime.utc(2026, 10, 14, 9, 0),
    ),
  ];
}
