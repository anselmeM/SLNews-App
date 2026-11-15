part of 'rss_feed_source.dart';

String _escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// Direct children matching a qualified name (`content:encoded`) or, for
/// unprefixed names, a local name (`description`).
///
/// Prefix-aware matching matters: `media:content` is a thumbnail element, not
/// the Atom `<content>` body.
bool _matches(XmlElement element, String name) {
  final String qualified = element.name.qualified.toLowerCase();
  if (name.contains(':')) return qualified == name;
  final String prefix = element.name.prefix ?? '';
  return prefix.isEmpty && element.name.local.toLowerCase() == name;
}

XmlElement? _first(XmlElement parent, List<String> names) {
  // Name order is priority order: `pubDate` outranks `updated`, whatever the
  // order the feed happens to serialise them in.
  for (final String name in names) {
    for (final XmlElement child in parent.childElements) {
      if (_matches(child, name)) return child;
    }
  }
  return null;
}

String? _firstText(XmlElement parent, List<String> names) {
  final XmlElement? element = _first(parent, names);
  if (element == null) return null;
  final String text = element.innerText.trim();
  return text.isEmpty ? null : text;
}

/// Resolves the story link: RSS `<link>` text, Atom `<link rel="alternate">`,
/// then a permalink `<guid>`/`<id>`.
String? _linkOf(XmlElement item) {
  String? alternate;
  String? plain;
  for (final XmlElement child in item.childElements) {
    if (child.name.local.toLowerCase() != 'link') continue;
    final String href = child.getAttribute('href')?.trim() ?? '';
    if (href.isEmpty) {
      final String text = child.innerText.trim();
      if (text.isNotEmpty) plain ??= text;
      continue;
    }
    final String rel = (child.getAttribute('rel') ?? '').trim().toLowerCase();
    // Only rel="alternate" (or an unlabelled link) points at the story;
    // rel="self", "edit" and "enclosure" point at the feed or a media asset.
    if (rel.isEmpty || rel == 'alternate') alternate ??= href;
  }
  if (alternate != null) return alternate;
  if (plain != null) return plain;

  final String guid = _firstText(item, const <String>['guid', 'id']) ?? '';
  return guid.toLowerCase().startsWith('http') ? guid : null;
}

/// Thumbnail from `media:content` / `media:thumbnail`, falling back to an
/// image enclosure. Video and audio enclosures are ignored.
String? _mediaImage(XmlElement item, String base) {
  String? enclosure;
  for (final XmlElement child in item.childElements) {
    final String prefix = (child.name.prefix ?? '').toLowerCase();
    final String local = child.name.local.toLowerCase();
    final String url = child.getAttribute('url')?.trim() ?? '';
    if (url.isEmpty) continue;

    final String type = (child.getAttribute('type') ?? '').toLowerCase();
    final String medium = (child.getAttribute('medium') ?? '').toLowerCase();

    if (prefix == 'media' && (local == 'content' || local == 'thumbnail')) {
      if (type.startsWith('video') ||
          type.startsWith('audio') ||
          medium == 'video') {
        continue;
      }
      if (local == 'thumbnail' ||
          type.startsWith('image') ||
          medium == 'image' ||
          (type.isEmpty && medium.isEmpty)) {
        return UrlNormalizer.absolute(url, base: base) ?? url;
      }
      continue;
    }

    if (local == 'enclosure' && enclosure == null) {
      if (type.startsWith('image') ||
          medium == 'image' ||
          _looksLikeImage(url)) {
        enclosure = UrlNormalizer.absolute(url, base: base) ?? url;
      }
    }
  }
  return enclosure;
}

bool _looksLikeImage(String url) => RegExp(
  r'\.(jpe?g|png|gif|webp|avif|bmp)(\?|#|$)',
  caseSensitive: false,
).hasMatch(url);

/// Strips scripts, styles and comments, and resolves relative `href`/`src`
/// values against [base] so the reader never requests a broken path.
String _cleanBody(String raw, String base) {
  if (raw.trim().isEmpty) return '';
  String body = raw.replaceAll(_scriptOrStyle, '');
  body = body.replaceAll(_htmlComment, '');
  body = body.replaceAllMapped(_quotedUrlAttribute, (Match match) {
    final String attribute = match.group(1)!;
    final String value = _decodeEntities(match.group(2)!);
    if (value.isEmpty || value.startsWith('data:') || value.startsWith('#')) {
      return match.group(0)!;
    }
    final String? resolved = UrlNormalizer.absolute(value, base: base);
    if (resolved == null) return match.group(0)!;
    return '$attribute="${resolved.replaceAll('&', '&amp;')}"';
  });
  return body.trim();
}

/// Removes every inline `<img>` and reports the first one as the hero image.
/// First usable image URL in an `<img>` tag: `src`, the common lazy-loading
/// attributes, then the largest candidate from `srcset`.
String? _inlineImageSource(String tag) {
  for (final String attribute in const <String>[
    'src',
    'data-src',
    'data-lazy-src',
    'data-original',
    'data-url',
  ]) {
    final String? value = _attribute(tag, attribute)?.trim();
    if (value != null && value.isNotEmpty && !value.startsWith('data:')) {
      return value;
    }
  }
  return _largestSrcset(
    _attribute(tag, 'srcset') ?? _attribute(tag, 'data-srcset'),
  );
}

/// Picks the highest-resolution candidate from a `srcset` list.
String? _largestSrcset(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  String? best;
  double bestScore = -1;
  for (final String candidate in value.split(',')) {
    final List<String> parts = candidate.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) continue;
    if (parts.first.startsWith('data:')) continue;
    double score = 1;
    if (parts.length > 1) {
      final String descriptor = parts[1].toLowerCase();
      final double? number = double.tryParse(
        descriptor.replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      if (number != null) {
        score = descriptor.endsWith('x') ? number * 1000 : number;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = parts.first;
    }
  }
  return best;
}

_InlineImage _extractInlineImage(String body, String base) {
  String? src;
  final String stripped = body.replaceAllMapped(_imageTag, (Match match) {
    if (src != null) return '';
    final String tag = match.group(0)!;
    final String? raw = _inlineImageSource(tag);
    if (raw != null) {
      src = UrlNormalizer.absolute(_decodeEntities(raw), base: base);
    }
    return '';
  });
  return _InlineImage(src, stripped.trim());
}

String? _author(XmlElement item) {
  final String? raw = _firstText(item, const <String>[
    'dc:creator',
    'creator',
    'author',
    'itunes:author',
  ]);
  if (raw == null) return null;
  final String text = _plainText(raw);
  if (text.isEmpty) return null;
  // RSS author fields are often "editor@example.com (Full Name)".
  final Match? parenthesised = RegExp(r'\(([^)]+)\)').firstMatch(text);
  return (parenthesised?.group(1) ?? text).trim();
}

List<String> _tags(XmlElement item) {
  final List<String> tags = <String>[];
  for (final XmlElement child in item.childElements) {
    if (!_matches(child, 'category')) continue;
    final String tag = _plainText(child.innerText);
    if (tag.isNotEmpty && !tags.contains(tag)) tags.add(tag);
    if (tags.length >= 6) break;
  }
  return tags;
}

int _readingMinutes(String body) {
  final String text = _plainText(body);
  if (text.isEmpty) return 0;
  final int words = text
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .length;
  if (words <= 0) return 0;
  return (words / 220).ceil().clamp(1, 60);
}

String _summarise(String candidate, {required String fallback}) {
  String source = _stripBoilerplate(candidate);
  if (source.isEmpty) source = _stripBoilerplate(_plainText(fallback));
  if (source.length <= 240) return source;
  final int cut = source.lastIndexOf(' ', 240);
  return '${source.substring(0, cut <= 0 ? 240 : cut).trimRight()}…';
}

/// WordPress feeds append `[Read More]` and "The post … appeared first on …".
String _stripBoilerplate(String value) =>
    value.replaceAll(_readMore, '').replaceAll(_appearedFirst, '').trim();

String _plainText(String? raw) {
  if (raw == null) return '';
  String value = raw.replaceAll(_scriptOrStyle, ' ');
  value = value.replaceAll(_anyTag, ' ');
  value = _decodeEntities(value);
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Named HTML entities feeds emit without declaring them.
const Map<String, String> _namedEntities = <String, String>{
  'nbsp': ' ',
  'ensp': ' ',
  'emsp': ' ',
  'thinsp': ' ',
  'shy': '',
  'amp': '&',
  'quot': '"',
  'apos': "'",
  'lt': '<',
  'gt': '>',
  'mdash': '—',
  'ndash': '–',
  'minus': '−',
  'hellip': '…',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
  'sbquo': '‚',
  'bdquo': '„',
  'laquo': '«',
  'raquo': '»',
  'middot': '·',
  'bull': '•',
  'dagger': '†',
  'deg': '°',
  'plusmn': '±',
  'times': '×',
  'divide': '÷',
  'frac12': '½',
  'pound': '£',
  'euro': '€',
  'cent': '¢',
  'yen': '¥',
  'copy': '©',
  'reg': '®',
  'trade': '™',
  'sect': '§',
  'para': '¶',
  'eacute': 'é',
  'egrave': 'è',
  'agrave': 'à',
  'ccedil': 'ç',
  'uuml': 'ü',
  'ouml': 'ö',
  'auml': 'ä',
  'ntilde': 'ñ',
  'aacute': 'á',
  'iacute': 'í',
  'oacute': 'ó',
  'uacute': 'ú',
  'rsaquo': '›',
  'lsaquo': '‹',
  'prime': '′',
  'Prime': '″',
};

const Set<String> _xmlEntities = <String>{'amp', 'lt', 'gt', 'quot', 'apos'};

String _decodeEntities(String value) {
  if (!value.contains('&')) return value;
  String result = value.replaceAllMapped(_hexEntity, (Match match) {
    final int? code = int.tryParse(match.group(1)!, radix: 16);
    return _codePoint(code) ?? match.group(0)!;
  });
  result = result.replaceAllMapped(_decimalEntity, (Match match) {
    final int? code = int.tryParse(match.group(1)!);
    return _codePoint(code) ?? match.group(0)!;
  });
  for (final MapEntry<String, String> entry in _namedEntities.entries) {
    // `&amp;` is decoded last so `&amp;lt;` does not become `<`.
    if (entry.key == 'amp') continue;
    result = result.replaceAll('&${entry.key};', entry.value);
  }
  return result.replaceAll('&amp;', '&');
}

String? _codePoint(int? code) {
  if (code == null || code < 0 || code > 0x10FFFF) return null;
  if (code >= 0xD800 && code <= 0xDFFF) return null;
  return String.fromCharCode(code);
}

/// Second-chance pass for documents that failed to parse because of an
/// undefined entity: known named entities become their character, unknown
/// ones become literal text.
String _resolveUnknownEntities(String document) =>
    document.replaceAllMapped(_namedEntityReference, (Match match) {
      final String name = match.group(1)!;
      if (_xmlEntities.contains(name)) return match.group(0)!;
      return _namedEntities[name] ?? '&amp;$name;';
    });

String? _attribute(String tag, String name) {
  final Match? doubleQuoted = RegExp(
    '(?:^|[\\s"\'/])$name\\s*=\\s*"([^"]*)"',
    caseSensitive: false,
  ).firstMatch(tag);
  if (doubleQuoted != null) return doubleQuoted.group(1);
  return RegExp(
    "(?:^|[\\s\"'/])$name\\s*=\\s*'([^']*)'",
    caseSensitive: false,
  ).firstMatch(tag)?.group(1);
}

final RegExp _scriptOrStyle = RegExp(
  r'<(script|style)\b[^>]*>[\s\S]*?</\1\s*>',
  caseSensitive: false,
);
final RegExp _anyTag = RegExp(r'<[^>]*>');
final RegExp _htmlComment = RegExp(r'<!--[\s\S]*?-->');
final RegExp _imageTag = RegExp(r'<img\b[^>]*>', caseSensitive: false);
final RegExp _quotedUrlAttribute = RegExp(
  r'\b(href|src)\s*=\s*"([^"]*)"',
  caseSensitive: false,
);
final RegExp _readMore = RegExp(
  r'\[(?:…|\.\.\.)?\s*Read More\s*\]',
  caseSensitive: false,
);
final RegExp _appearedFirst = RegExp(
  r'\s*The post\s+[\s\S]*?\s+appeared first on\s+[\s\S]*?\.\s*$',
  caseSensitive: false,
);
final RegExp _hexEntity = RegExp(r'&#[xX]([0-9a-fA-F]+);');
final RegExp _decimalEntity = RegExp(r'&#0*(\d+);');
final RegExp _namedEntityReference = RegExp(r'&([a-zA-Z][a-zA-Z0-9]{0,30});');

/// Result of pulling the first inline image out of a feed body.
class _InlineImage {
  const _InlineImage(this.src, this.body);

  final String? src;
  final String body;
}
