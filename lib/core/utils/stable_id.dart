import 'dart:convert';

import 'url_normalizer.dart';

/// Deterministic identifiers for content that ships without a usable id.
///
/// RSS items often have no id, and `String.hashCode` is not stable across runs
/// or platforms, so ids are derived here from FNV-1a over UTF-8 bytes. The same
/// URL therefore always produces the same id, which is what lets the cache and
/// the bookmark store agree on what a story is.
abstract final class StableId {
  /// FNV-1a 64-bit offset basis (`0xcbf29ce484222325`) as a signed 64-bit int.
  static const int _offsetBasis = -3750763034362895579;

  /// FNV-1a 64-bit prime (`0x100000001b3`).
  static const int _prime = 1099511628211;

  /// Unit separator (U+001F) cannot appear in a title or a URL, so joined parts
  /// stay unambiguous.
  static const String _separator = '\u001f';

  static final BigInt _twoPow64 = BigInt.one << 64;

  /// Stable id for [url], hashed in its canonical form.
  static String fromUrl(String url) =>
      _hex(_fnv1a(utf8.encode(UrlNormalizer.canonical(url))));

  /// Stable id for ordered [parts], e.g. `['awoko', title, pubDate]`.
  static String fromParts(List<String> parts) =>
      _hex(_fnv1a(utf8.encode(parts.join(_separator))));

  /// FNV-1a over [bytes]; Dart's 64-bit int arithmetic wraps on overflow, which
  /// is exactly the modulo-2^64 the algorithm specifies.
  static int _fnv1a(List<int> bytes) {
    int hash = _offsetBasis;
    for (final int byte in bytes) {
      hash ^= byte;
      hash *= _prime;
    }
    return hash;
  }

  /// Lowercase, zero-padded 16-character hex of the unsigned hash value.
  static String _hex(int value) {
    final BigInt unsigned = value < 0
        ? BigInt.from(value) + _twoPow64
        : BigInt.from(value);
    return unsigned.toRadixString(16).padLeft(16, '0');
  }
}
