import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers/app_bootstrap.dart';

/// Entry point.
///
/// Local storage and the repository graph are opened before the first frame so
/// the UI only ever renders against a fully wired, offline-capable app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppBootstrap bootstrap = await AppBootstrap.create();
  runApp(
    UncontrolledProviderScope(
      container: bootstrap.container,
      child: const SlNewsApp(),
    ),
  );
}
