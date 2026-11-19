import '../../domain/models/video_moment.dart';

/// Offline "Video moments" rotation.
///
/// These are **real, playable clips** from the channels the scraper follows,
/// used only until the live `/v1/videos` payload replaces them (or when the
/// build has no API key, which is the case for signed-out readers today).
/// Every entry carries a `youtubeId`, so the reel can always rebuild a watch
/// URL even if the stored one rots.
///
/// Earlier revisions used `youtube.com/results?...` search URLs and stock
/// photos; tapping one opened a YouTube search page instead of a clip. Never
/// put a channel, search or playlist URL here: the rail is for videos.
///
/// Refresh this list when the clips age out (they are recent uploads as of
/// 2026-11-19); the live feed is the source of truth.
abstract final class SlVideos {
  static final List<VideoMoment> all = <VideoMoment>[
    VideoMoment(
      id: 'video:slbc-news-bulletin',
      title: 'SLBC News bulletin: Esther Neneh Fpu',
      source: 'SLBC News',
      thumbnailUrl: 'https://i4.ytimg.com/vi/wuE24NT7TcE/hqdefault.jpg',
      url: 'https://www.youtube.com/watch?v=wuE24NT7TcE',
      summary: 'The evening news bulletin from the state broadcaster.',
      category: 'news',
      publishedAt: DateTime.utc(2026, 11, 19, 15, 56),
      youtubeId: 'wuE24NT7TcE',
    ),
    VideoMoment(
      id: 'video:president-youth-summit',
      title: 'President Bio opens the national youth summit',
      source: 'SLBC News',
      thumbnailUrl: 'https://i3.ytimg.com/vi/fRQBa04XGbU/hqdefault.jpg',
      url: 'https://www.youtube.com/watch?v=fRQBa04XGbU',
      summary: 'Opening remarks from the youth gathering in Freetown.',
      category: 'politics',
      publishedAt: DateTime.utc(2026, 11, 19, 15, 56),
      youtubeId: 'fRQBa04XGbU',
    ),
    VideoMoment(
      id: 'video:agriculture-investment-plan',
      title: 'Agriculture minister unveils \$1bn investment plan',
      source: 'Sierraloaded TV',
      thumbnailUrl: 'https://i2.ytimg.com/vi/yB7PoWDXMbg/hqdefault.jpg',
      url: 'https://www.youtube.com/watch?v=yB7PoWDXMbg',
      summary: 'The plan targets 120,000 jobs across the sector.',
      category: 'news',
      publishedAt: DateTime.utc(2026, 11, 19, 16, 18),
      youtubeId: 'yB7PoWDXMbg',
    ),
    VideoMoment(
      id: 'video:water-supply-threat',
      title: 'Illegal mining and cable theft threaten the water supply',
      source: 'Sierraloaded TV',
      thumbnailUrl: 'https://i4.ytimg.com/vi/s_4fN03XahM/hqdefault.jpg',
      url: 'https://www.youtube.com/watch?v=s_4fN03XahM',
      summary: 'SALWACO warns that vandalism is cutting supply to communities.',
      category: 'news',
      publishedAt: DateTime.utc(2026, 11, 19, 15, 52),
      youtubeId: 's_4fN03XahM',
    ),
    VideoMoment(
      id: 'video:apc-veteran-interview',
      title: 'APC veteran defends Samura Kamara meeting with President Bio',
      source: 'Sierraloaded TV',
      thumbnailUrl: 'https://i2.ytimg.com/vi/ey0dnzy71bU/hqdefault.jpg',
      url: 'https://www.youtube.com/watch?v=ey0dnzy71bU',
      summary: 'Reaction after the opposition leader met the president.',
      category: 'politics',
      publishedAt: DateTime.utc(2026, 11, 19, 15, 13),
      youtubeId: 'ey0dnzy71bU',
    ),
    VideoMoment(
      id: 'video:ayv-primetime-news',
      title: 'AYV primetime news at nine',
      source: 'AYV Media Empire',
      thumbnailUrl: 'https://i1.ytimg.com/vi/D_PcfWwCLNs/hqdefault.jpg',
      url: 'https://www.youtube.com/watch?v=D_PcfWwCLNs',
      summary: 'The full primetime bulletin from AYV.',
      category: 'news',
      publishedAt: DateTime.utc(2026, 11, 15, 9, 52),
      youtubeId: 'D_PcfWwCLNs',
    ),
  ];
}
