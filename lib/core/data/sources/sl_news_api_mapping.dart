part of 'sl_news_api_source.dart';

Publisher _publisherFor(String sourceName, Publisher unknown) {
  final String name = _collapse(sourceName);
  if (name.isEmpty) return unknown;

  final bool isWire = _isWire(name);
  final bool shortEnough = name.length <= 18;
  return Publisher(
    id: 'publisher:${_slug(name)}',
    name: name,
    wordmark: shortEnough ? name.toUpperCase() : _initials(name),
    isWire: isWire,
  );
}

String _categoryIdFor(List<String> categories) {
  for (final String raw in categories) {
    for (final String part in _splitCategories(raw)) {
      final String? id = _categoryIdForToken(part);
      if (id != null) return id;
    }
  }
  return 'top';
}

FeedSourceConfig _configFor(SlNewsApiConfig config, String versionedPath) =>
    FeedSourceConfig(
      id: 'slnews-api',
      outlet: 'SLNews',
      publisherId: 'publisher:slnews',
      wordmark: 'SLNEWS',
      url: '${_normalizeBase(config.baseUrl)}$versionedPath',
      kind: FeedSourceKind.restJson,
      categoryId: 'top',
      websiteUrl: 'https://slnews.net',
    );

bool _isNumeric(String value) =>
    value.isNotEmpty && int.tryParse(value) != null;

bool _present(String? value) => value != null && value.trim().isNotEmpty;

String _normalizeBase(String baseUrl) {
  String working = baseUrl.trim();
  while (working.endsWith('/')) {
    working = working.substring(0, working.length - 1);
  }
  return working;
}

int _clampPageSize(int value) => value < SlNewsApiConfig.minPageSize
    ? SlNewsApiConfig.minPageSize
    : (value > SlNewsApiConfig.maxPageSize
          ? SlNewsApiConfig.maxPageSize
          : value);

String _idOf(Object? value) {
  if (value is num) {
    final int asInt = value.toInt();
    return value == asInt ? '$asInt' : value.toString();
  }
  return _text(value);
}

Map<String, dynamic> _stringKeyed(Map<dynamic, dynamic> raw) {
  final Map<String, dynamic> json = <String, dynamic>{};
  raw.forEach((Object? key, Object? value) {
    if (key is String) json[key] = value;
  });
  return json;
}

/// Picks the raw row out of either a bare object or a `{data: {...}}` wrapper.
Object? _rowOf(Object? payload) {
  if (payload is Map) {
    final Object? nested = payload['data'];
    return nested is Map ? nested : payload;
  }
  if (payload is List) return payload.isEmpty ? null : payload.first;
  return null;
}

String _firstText(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final String value = _text(json[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// Strips markup, decodes entities and collapses whitespace.
///
/// Tags are removed before entities are decoded so a summary containing
/// `&lt;script&gt;` can never become live markup downstream.
String _text(Object? value) {
  if (value is num || value is bool) return value.toString();
  if (value is! String) return '';
  final String withoutTags = value.replaceAll(RegExp(r'<[^>]*>'), ' ');
  return _collapse(_decodeEntities(withoutTags));
}

/// Same normalisation, but `null` for an empty result.
String? _nullable(Object? value) {
  final String text = _text(value);
  return text.isEmpty ? null : text;
}

String _collapse(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

String _truncate(String text) {
  if (text.length <= 240) return text;
  final int cut = text.lastIndexOf(' ', 240);
  return '${text.substring(0, cut <= 0 ? 240 : cut).trimRight()}…';
}

final RegExp _numericEntity = RegExp(r'&#(x?)([0-9a-fA-F]+);');

const Map<String, String> _namedEntities = <String, String>{
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'rsquo': '’',
  'lsquo': '‘',
  'rdquo': '”',
  'ldquo': '“',
};

String _decodeEntities(String value) {
  if (!value.contains('&')) return value;
  String decoded = value.replaceAllMapped(_numericEntity, (Match match) {
    final bool hex = match.group(1) == 'x';
    final int? code = int.tryParse(match.group(2)!, radix: hex ? 16 : 10);
    if (code == null || code < 0 || code > 0x10FFFF) return match.group(0)!;
    return String.fromCharCode(code);
  });
  for (final MapEntry<String, String> entry in _namedEntities.entries) {
    decoded = decoded.replaceAll('&${entry.key};', entry.value);
  }
  return decoded;
}

/// Whether [name] belongs to a wire service.
///
/// Checked as a whole word (so `Apex News` is not `AP`) as well as a plain
/// containment (so `The Associated Press` is), because wires are abbreviated
/// inconsistently in scraped source labels.
bool _isWire(String name) {
  final String needle = name.toLowerCase();
  for (final String wire in _wireNames) {
    if (needle.contains(wire)) return true;
  }
  // Abbreviations such as `AP` also appear as standalone tokens.
  return RegExp(r'\bAP\b').hasMatch(name);
}

const List<String> _wireNames = <String>[
  'reuters',
  'associated press',
  'afp',
  'bbc',
];

const Set<String> _stopWords = <String>{'the', 'a', 'an', 'of', 'and', 'for'};

String _slug(String name) {
  final String lower = name.toLowerCase();
  final StringBuffer buffer = StringBuffer();
  for (final int unit in lower.runes) {
    final String char = String.fromCharCode(unit);
    if (RegExp(r'[a-z0-9]').hasMatch(char)) {
      buffer.write(char);
    } else if (RegExp(r'\s').hasMatch(char)) {
      buffer.write(' ');
    }
  }
  final String joined = buffer.toString().trim().replaceAll(
    RegExp(r'\s+'),
    '-',
  );
  return joined;
}

/// Initials of the significant words, e.g. `The Sierra Leone Telegraph` →
/// `TSLT`.
///
/// A leading article is kept — it is the first letter a reader scans for —
/// while articles elsewhere are dropped, so `News of the World` → `NW`.
String _initials(String name) {
  final List<String> words = <String>[];
  for (final String word in name.split(RegExp(r'\s+'))) {
    final String cleaned = word.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleaned.isEmpty) continue;
    if (words.isNotEmpty && _stopWords.contains(cleaned.toLowerCase())) {
      continue;
    }
    words.add(cleaned);
  }
  if (words.isEmpty) return name.toUpperCase();
  final StringBuffer initials = StringBuffer();
  for (final String word in words) {
    initials.write(word[0].toUpperCase());
  }
  return initials.toString();
}

/// Splits a raw label on the separators outlets use to pack two categories.
List<String> _splitCategories(String raw) {
  final List<String> parts = <String>[];
  for (final String chunk in raw.split(RegExp(r'[&,;]| / |/|\|'))) {
    final String part = _collapse(chunk).replaceAll(RegExp(r'\s+'), ' ');
    if (part.isNotEmpty && !parts.contains(part)) parts.add(part);
  }
  return parts;
}

/// Labels seen in the wild that do not match a curated label verbatim.
const Map<String, String> _categoryAliases = <String, String>{
  'politics': 'politics',
  'politics & law': 'politics',
  'politics and law': 'politics',
  'political': 'politics',
  'government': 'politics',
  'governance': 'politics',
  'business': 'business',
  'economy': 'business',
  'economic': 'business',
  'finance': 'business',
  'sports': 'sports',
  'sport': 'sports',
  'football': 'sports',
  'health': 'health',
  'healthcare': 'health',
  'medicine': 'health',
  'tech': 'tech',
  'technology': 'tech',
  'ict': 'tech',
  'education': 'education',
  'school': 'education',
  'mining': 'mining',
  'minerals': 'mining',
  'world': 'world',
  'international': 'world',
  'global': 'world',
  'culture': 'culture',
  'arts': 'culture',
  'entertainment': 'culture',
  'music': 'music',
  'cars': 'cars',
  'cars and vehicles': 'cars',
  'vehicles': 'cars',
  'automotive': 'cars',
  'top': 'top',
  'top stories': 'top',
  'news': 'top',
  'general': 'top',
  'breaking news': 'top',
  'local news': 'top',
  'national news': 'top',
};

String? _categoryIdForToken(String token) {
  final String needle = token.toLowerCase().trim();
  if (needle.isEmpty) return null;

  final String? alias = _categoryAliases[needle];
  if (alias != null) return alias;

  for (final NewsCategory category in NewsCategories.all) {
    if (category.id.toLowerCase() == needle) return category.id;
    if (category.label.toLowerCase() == needle) return category.id;
  }
  // Fuzzy: `World News` and `Business & Finance` still belong to a curated
  // category when a whole word of the label is present.
  for (final NewsCategory category in NewsCategories.all) {
    final Set<String> words = _words(category.label);
    for (final String word in _words(token)) {
      if (words.contains(word)) return category.id;
    }
  }
  return null;
}

Set<String> _words(String value) => value
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((String word) => word.length > 2)
    .toSet();

List<String> _stringList(Object? value) {
  final List<String> values = <String>[];
  if (value is List) {
    for (final Object? entry in value) {
      final String text = _text(entry);
      if (text.isNotEmpty && !values.contains(text)) values.add(text);
    }
  } else {
    final String text = _text(value);
    if (text.isNotEmpty) values.add(text);
  }
  return values;
}

int? _integer(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool? _boolean(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    final String text = value.trim().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
  }
  return null;
}

/// Parses ISO-8601, RFC-822 and epoch seconds/millis through [WireDate].
DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  if (value is num) return WireDate.fromEpoch(value);
  if (value is String) return WireDate.parse(value);
  return null;
}
