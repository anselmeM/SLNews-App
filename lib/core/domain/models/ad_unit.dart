import 'package:flutter/foundation.dart';

/// A native-style inline ad unit rendered inside the content stream.
///
/// SLNews renders house/partner units locally: nothing is fetched from the ad
/// network before the reader opts in, and the unit always carries an `Ad`
/// label plus its disclosure line so it can never be mistaken for editorial.
@immutable
class AdUnit {
  const AdUnit({
    required this.id,
    required this.headline,
    required this.body,
    required this.ctaLabel,
    required this.advertiser,
    this.brandHex = '#0B6FD1',
    this.brandAccentHex = '#2E9BF5',
    this.assetLabel,
    this.disclosure,
    this.targetUrl,
  });

  final String id;

  /// Large call to action drawn over the brand panel, e.g. "CLAIM YOUR REWARD".
  final String headline;

  /// Supporting line under the panel.
  final String body;

  /// Button label, e.g. "View more".
  final String ctaLabel;

  /// Advertiser name shown in the disclosure row.
  final String advertiser;

  final String brandHex;
  final String brandAccentHex;

  /// Value rendered inside the simulated offer card, e.g. "$20".
  final String? assetLabel;

  /// Legal / disclosure copy under the creative.
  final String? disclosure;

  final String? targetUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'headline': headline,
    'body': body,
    'ctaLabel': ctaLabel,
    'advertiser': advertiser,
    'brandHex': brandHex,
    'brandAccentHex': brandAccentHex,
    'assetLabel': assetLabel,
    'disclosure': disclosure,
    'targetUrl': targetUrl,
  };

  factory AdUnit.fromJson(Map<String, dynamic> json) => AdUnit(
    id: json['id'] as String,
    headline: json['headline'] as String,
    body: json['body'] as String? ?? '',
    ctaLabel: json['ctaLabel'] as String? ?? 'View more',
    advertiser: json['advertiser'] as String? ?? 'Sponsored',
    brandHex: json['brandHex'] as String? ?? '#0B6FD1',
    brandAccentHex: json['brandAccentHex'] as String? ?? '#2E9BF5',
    assetLabel: json['assetLabel'] as String?,
    disclosure: json['disclosure'] as String?,
    targetUrl: json['targetUrl'] as String?,
  );

  @override
  bool operator ==(Object other) => other is AdUnit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
