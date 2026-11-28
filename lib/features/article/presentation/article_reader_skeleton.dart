part of 'article_page.dart';

class _ReaderSkeleton extends StatelessWidget {
  const _ReaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

/// The `article_end` sold placement, rendered after the story body and before
/// related stories. The provider is allowed to fail or stay empty: an ad must
/// never break reading.
