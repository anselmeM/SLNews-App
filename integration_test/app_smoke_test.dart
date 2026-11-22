import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:slnews_mobile/app.dart';
import 'package:slnews_mobile/core/providers/app_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches on a real device', (WidgetTester tester) async {
    final AppBootstrap bootstrap = await AppBootstrap.create(
      allowPersistence: false,
    );
    addTearDown(bootstrap.container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: bootstrap.container,
        child: const SlNewsApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(SlNewsApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
