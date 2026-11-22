import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/news_category_matcher.dart';

void main() {
  test('classifies free-form feed labels', () {
    expect(categoryIdForTerms(const <String>['Politics & Law']), 'politics');
    expect(
      categoryIdForTerms(const <String>['Business & Finance']),
      'business',
    );
    expect(
      categoryIdForTerms(const <String>['Entertainment & Arts']),
      'culture',
    );
    expect(categoryIdForTerms(const <String>['Vehicles']), 'cars');
    expect(categoryIdForTerms(const <String>['Technology']), 'tech');
    expect(categoryIdForTerms(const <String>['Health']), 'health');
  });

  test('classifies headlines when a feed has no category tags', () {
    expect(
      categoryIdForTerms(<String>['Bank of Sierra Leone holds policy rate']),
      'business',
    );
    expect(
      categoryIdForTerms(<String>['Koidu diamond licence review']),
      'mining',
    );
    expect(
      categoryIdForTerms(<String>['Mobile money interoperability cuts delays']),
      'tech',
    );
    expect(
      categoryIdForTerms(<String>['Leone Stars level with Guinea']),
      'sports',
    );
    expect(
      categoryIdForTerms(<String>['Leone Stars football match']),
      'sports',
    );
  });

  test('returns null when nothing matches', () {
    expect(
      categoryIdForTerms(const <String>['A quiet afternoon in Freetown']),
      isNull,
    );
  });
}
