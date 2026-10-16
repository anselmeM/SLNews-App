import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/theme/app_typography.dart';
import 'package:slnews_mobile/core/utils/html_content.dart';

Future<void> _pumpHtml(WidgetTester tester, String html) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(child: HtmlContent(html: html)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The [RichText] the renderer produced for the first block.
RichText _firstRichText(WidgetTester tester) {
  return tester.widget<RichText>(
    find
        .descendant(
          of: find.byType(HtmlContent),
          matching: find.byType(RichText),
        )
        .first,
  );
}

/// Depth-first search for the span carrying exactly [text].
TextSpan? _spanWithText(InlineSpan span, String text) {
  if (span is TextSpan) {
    if (span.text == text) return span;
    for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
      final TextSpan? found = _spanWithText(child, text);
      if (found != null) return found;
    }
  }
  return null;
}

void main() {
  group('HtmlBlocks.toPlainText', () {
    test('strips markup and collapses whitespace', () {
      const String html =
          '<p>Hello   <strong>Salone</strong></p>\n<p>Second line</p>';
      expect(HtmlBlocks.toPlainText(html), 'Hello Salone Second line');
    });

    test('drops script and style content entirely', () {
      const String html =
          '<p>Visible</p><script>alert(1)</script><style>p{color:red}</style>';
      expect(HtmlBlocks.toPlainText(html), 'Visible');
    });

    test('keeps entities as readable text', () {
      expect(
        HtmlBlocks.toPlainText('<p>Freetown &amp; Bo</p>'),
        'Freetown & Bo',
      );
    });

    test('keeps image alt text so figures are searchable', () {
      expect(
        HtmlBlocks.toPlainText(
          '<figure><img src="a.jpg" alt="Stelco plant"/></figure>',
        ),
        'Stelco plant',
      );
    });

    test('detects a body that repeats the standfirst', () {
      const String body =
          '<p>Sierra Leone equalised early.</p><p>More detail follows.</p>';
      expect(
        HtmlBlocks.opensWith(body, 'Sierra Leone equalised early.'),
        isTrue,
      );
      expect(
        HtmlBlocks.opensWith(body, 'SIERRA LEONE EQUALISED EARLY.'),
        isTrue,
      );
      expect(
        HtmlBlocks.opensWith(body, 'A completely different standfirst.'),
        isFalse,
      );
      expect(HtmlBlocks.opensWith(body, ''), isFalse);
      expect(HtmlBlocks.opensWith('', 'anything'), isFalse);
    });
  });

  group('HtmlContent rendering', () {
    testWidgets('renders paragraphs, headings, lists and blockquotes', (
      WidgetTester tester,
    ) async {
      const String html = '''
        <h2>Power crisis</h2>
        <p>The <strong>Bumbuna</strong> line was restored.</p>
        <ul><li>Freetown</li><li>Bo</li></ul>
        <blockquote>Everything is on the table.</blockquote>
      ''';
      await _pumpHtml(tester, html);

      expect(find.textContaining('Power crisis'), findsOneWidget);
      expect(find.textContaining('was restored'), findsOneWidget);
      expect(find.text('•'), findsNWidgets(2));
      expect(
        find.textContaining('Everything is on the table.'),
        findsOneWidget,
      );
    });

    testWidgets('keeps inline emphasis inside a single rich paragraph', (
      WidgetTester tester,
    ) async {
      await _pumpHtml(tester, '<p>Alpha <strong>Beta</strong> Gamma</p>');

      final RichText rich = _firstRichText(tester);
      expect(rich.text.toPlainText(), 'Alpha Beta Gamma');

      final TextSpan? bold = _spanWithText(rich.text, 'Beta');
      expect(
        bold,
        isNotNull,
        reason: 'the emphasised run must survive as its own span',
      );
      expect(bold!.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('never renders script content', (WidgetTester tester) async {
      await _pumpHtml(tester, '<p>Safe</p><script>window.alert("x")</script>');
      expect(find.textContaining('window.alert'), findsNothing);
      expect(find.text('Safe'), findsOneWidget);
    });

    testWidgets('renders a figure image with its caption', (
      WidgetTester tester,
    ) async {
      await _pumpHtml(
        tester,
        '<figure><img src="https://example.com/a.jpg" alt="Plant"/><figcaption>Stelco steel works</figcaption></figure>',
      );
      expect(find.text('Stelco steel works'), findsOneWidget);
    });

    testWidgets('an empty body renders nothing at all', (
      WidgetTester tester,
    ) async {
      await _pumpHtml(tester, '   ');
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('paragraphs use the design-system body style', (
      WidgetTester tester,
    ) async {
      await _pumpHtml(tester, '<p>Body copy</p>');

      final TextSpan? paragraph = _spanWithText(
        _firstRichText(tester).text,
        'Body copy',
      );
      expect(paragraph, isNotNull);
      expect(paragraph!.style!.fontSize, 17);
      expect(paragraph.style!.fontFamily, AppTypography.fontFamily);
    });
  });
}
