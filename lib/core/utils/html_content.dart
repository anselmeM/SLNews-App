import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/sl_network_image.dart';

/// Renders an article body as Flutter widgets.
///
/// SLNews parses feed-supplied markup itself instead of embedding a WebView or
/// a heavyweight HTML package: only the small block/inline subset that news
/// bodies actually use is supported, every element is mapped to design-system
/// typography, and unknown tags degrade to their text content rather than
/// disappearing. Scripts, styles and event attributes are dropped.
class HtmlContent extends StatelessWidget {
  const HtmlContent({super.key, required this.html, this.spacing = AppSpacing.lg});

  final String html;

  /// Vertical gap between top-level blocks.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final List<Widget> blocks = HtmlBlocks.toWidgets(context, html, spacing: spacing);
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}

/// Pure helpers so body rendering can be asserted in unit tests.
abstract final class HtmlBlocks {
  /// Tags whose content is never rendered.
  static const Set<String> _dropped = <String>{'script', 'style', 'noscript', 'iframe', 'form'};

  static List<Widget> toWidgets(BuildContext context, String html, {double spacing = AppSpacing.lg}) {
    final String trimmed = html.trim();
    if (trimmed.isEmpty) return const <Widget>[];

    final dom.DocumentFragment fragment = html_parser.parseFragment(trimmed);
    final List<Widget> widgets = <Widget>[];
    for (final dom.Node node in fragment.nodes) {
      widgets.addAll(_block(context, node, spacing));
    }
    return _stripTrailingSpacing(widgets, spacing);
  }

  /// Inline spans for a fragment, used for summaries and captions.
  static List<InlineSpan> toSpans(BuildContext context, String html, {TextStyle? baseStyle}) {
    final TextStyle base = baseStyle ?? context.typography.body;
    final dom.DocumentFragment fragment = html_parser.parseFragment(html);
    return _inlineSpans(context, fragment.nodes, base);
  }

  static List<Widget> _block(BuildContext context, dom.Node node, double spacing) {
    if (node is dom.Text) {
      final String text = node.text.trim();
      if (text.isEmpty) return const <Widget>[];
      return <Widget>[
        Text(text, style: context.typography.body),
        SizedBox(height: spacing),
      ];
    }
    if (node is! dom.Element) return const <Widget>[];

    final String tag = node.localName ?? '';
    if (_dropped.contains(tag)) return const <Widget>[];

    switch (tag) {
      case 'p':
        return _paragraph(context, node, spacing);
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return <Widget>[
          Text.rich(
            TextSpan(children: _inlineSpans(context, node.nodes, context.typography.sectionTitle)),
          ),
          SizedBox(height: spacing),
        ];
      case 'blockquote':
        return <Widget>[
          Container(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: context.colors.primary, width: 3)),
            ),
            child: Text.rich(
              TextSpan(
                children: _inlineSpans(
                  context,
                  node.nodes,
                  context.typography.lead.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ),
          SizedBox(height: spacing),
        ];
      case 'ul':
      case 'ol':
        return _list(context, node, spacing, ordered: tag == 'ol');
      case 'figure':
        return _figure(context, node, spacing);
      case 'img':
        return _image(context, node, null, spacing);
      case 'hr':
        return <Widget>[
          Divider(color: context.colors.divider),
          SizedBox(height: spacing),
        ];
      case 'pre':
        return <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.surfaceMuted,
              borderRadius: AppRadius.imageRadius,
            ),
            child: Text(node.text, style: context.typography.caption),
          ),
          SizedBox(height: spacing),
        ];
      case 'div':
      case 'section':
      case 'article':
      case 'main':
        final List<Widget> nested = <Widget>[];
        for (final dom.Node child in node.nodes) {
          nested.addAll(_block(context, child, spacing));
        }
        return nested;
      default:
        return _paragraph(context, node, spacing);
    }
  }

  static List<Widget> _paragraph(BuildContext context, dom.Element node, double spacing) {
    final String plain = node.text.trim();
    final bool hasImage = node.querySelector('img') != null;
    if (plain.isEmpty && !hasImage) return const <Widget>[];

    final List<Widget> widgets = <Widget>[];
    if (hasImage) {
      final dom.Element? image = node.querySelector('img');
      if (image != null) widgets.addAll(_image(context, image, null, AppSpacing.md));
    }
    if (plain.isNotEmpty) {
      widgets.add(
        Text.rich(TextSpan(children: _inlineSpans(context, node.nodes, context.typography.body))),
      );
    }
    widgets.add(SizedBox(height: spacing));
    return widgets;
  }

  static List<Widget> _list(BuildContext context, dom.Element node, double spacing, {required bool ordered}) {
    final List<dom.Element> items = node.children.where((dom.Element e) => e.localName == 'li').toList();
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final String marker = ordered ? '${i + 1}.' : '•';
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 24,
                child: Text(marker, style: context.typography.body),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _inlineSpans(context, items[i].nodes, context.typography.body)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return <Widget>[...rows, SizedBox(height: spacing - AppSpacing.sm)];
  }

  static List<Widget> _figure(BuildContext context, dom.Element node, double spacing) {
    final dom.Element? image = node.querySelector('img');
    final String caption = node.querySelector('figcaption')?.text.trim() ?? '';
    if (image == null) return const <Widget>[];
    return _image(context, image, caption.isEmpty ? null : caption, spacing);
  }

  static List<Widget> _image(BuildContext context, dom.Element image, String? caption, double spacing) {
    final String src = image.attributes['src'] ?? image.attributes['data-src'] ?? '';
    if (src.isEmpty) return const <Widget>[];
    return <Widget>[
      SlNetworkImage(
        url: src,
        height: 220,
        width: double.infinity,
        borderRadius: AppRadius.imageRadius,
      ),
      if (caption != null) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Text(caption, style: context.typography.caption),
      ],
      SizedBox(height: spacing),
    ];
  }

  static List<InlineSpan> _inlineSpans(BuildContext context, List<dom.Node> nodes, TextStyle base) {
    final List<InlineSpan> raw = <InlineSpan>[];
    _collect(context, nodes, base, raw);

    // Collapse the whitespace that markup introduces around inline elements and
    // drop leading/trailing padding so paragraphs never start with a space.
    final List<InlineSpan> cleaned = <InlineSpan>[];
    for (int i = 0; i < raw.length; i++) {
      final InlineSpan span = raw[i];
      String text = (span as TextSpan).text ?? '';
      if (i == 0) text = text.replaceFirst(RegExp(r'^ +'), '');
      if (i == raw.length - 1) text = text.replaceFirst(RegExp(r' +$'), '');
      if (text.isEmpty) continue;
      cleaned.add(TextSpan(text: text, style: span.style));
    }
    return cleaned;
  }

  static void _collect(BuildContext context, List<dom.Node> nodes, TextStyle style, List<InlineSpan> out) {
    for (final dom.Node node in nodes) {
      if (node is dom.Text) {
        final String text = node.text.replaceAll(RegExp(r'\s+'), ' ');
        if (text.isEmpty) continue;
        final bool blank = text.trim().isEmpty;
        if (blank) {
          // Keep a single separating space between two inline siblings.
          if (out.isNotEmpty) out.add(TextSpan(text: ' ', style: style));
          continue;
        }
        out.add(TextSpan(text: text, style: style));
        continue;
      }
      if (node is! dom.Element) continue;

      final String tag = node.localName ?? '';
      if (_dropped.contains(tag)) continue;
      if (tag == 'br') {
        out.add(TextSpan(text: '\n', style: style));
        continue;
      }
      if (tag == 'img') {
        final String alt = node.attributes['alt'] ?? '';
        if (alt.isNotEmpty) {
          out.add(TextSpan(text: ' $alt ', style: style.copyWith(fontStyle: FontStyle.italic)));
        }
        continue;
      }
      _collect(context, node.nodes, _styleFor(context, tag, node, style), out);
    }
  }

  static TextStyle _styleFor(BuildContext context, String tag, dom.Element node, TextStyle base) {
    switch (tag) {
      case 'strong':
      case 'b':
        return base.copyWith(fontWeight: FontWeight.w700);
      case 'em':
      case 'i':
        return base.copyWith(fontStyle: FontStyle.italic);
      case 'u':
        return base.copyWith(decoration: TextDecoration.underline);
      case 's':
      case 'del':
        return base.copyWith(decoration: TextDecoration.lineThrough);
      case 'a':
        return base.copyWith(
          color: context.colors.primary,
          decoration: TextDecoration.underline,
          decorationColor: context.colors.primary,
        );
      case 'code':
        return base.copyWith(fontFamily: 'monospace');
      case 'small':
        return base.copyWith(fontSize: (base.fontSize ?? 17) - 2);
      case 'mark':
        return base.copyWith(backgroundColor: context.colors.skeletonHighlight);
      default:
        return base;
    }
  }

  static List<Widget> _stripTrailingSpacing(List<Widget> widgets, double spacing) {
    if (widgets.isEmpty) return widgets;
    final List<Widget> result = List<Widget>.of(widgets);
    while (result.isNotEmpty && result.last is SizedBox) {
      result.removeLast();
    }
    return result;
  }

  /// True when the body already opens with [candidate].
  ///
  /// Outlets frequently repeat the standfirst as the first paragraph; the reader
  /// uses this to avoid printing the same sentence twice.
  static bool opensWith(String html, String candidate, {int compareChars = 80}) {
    final String body = toPlainText(html).toLowerCase();
    final String lead = candidate.trim().toLowerCase();
    if (body.isEmpty || lead.isEmpty) return false;
    final String needle = lead.length > compareChars ? lead.substring(0, compareChars) : lead;
    return body.startsWith(needle);
  }

  /// Plain-text projection of a body, used by search and by reading-time.
  ///
  /// Script/style/iframe content is skipped rather than flattened into the
  /// result, so a body containing inline code cannot leak into search.
  static String toPlainText(String html) {
    final dom.DocumentFragment fragment = html_parser.parseFragment(html);
    final StringBuffer buffer = StringBuffer();
    _collectText(fragment.nodes, buffer);
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static void _collectText(List<dom.Node> nodes, StringBuffer buffer) {
    for (final dom.Node node in nodes) {
      if (node is dom.Text) {
        buffer.write(node.text);
        continue;
      }
      if (node is! dom.Element) continue;

      final String tag = node.localName ?? '';
      if (_dropped.contains(tag)) continue;
      if (tag == 'br') {
        buffer.write(' ');
        continue;
      }
      if (tag == 'img') {
        final String alt = node.attributes['alt'] ?? '';
        if (alt.isNotEmpty) buffer.write(' $alt ');
        continue;
      }
      _collectText(node.nodes, buffer);
    }
  }
}
