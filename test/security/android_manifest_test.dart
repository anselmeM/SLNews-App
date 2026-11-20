import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/routing/deep_link_uri.dart';
import 'package:xml/xml.dart';

/// Security invariants of the shipped Android manifest.
///
/// These are the settings a future Flutter template refresh or a plugin
/// installation can silently overwrite, and none of them are visible in a
/// widget test. Reading the real manifest keeps the assertions honest.
void main() {
  late XmlElement manifest;
  late XmlElement application;

  setUpAll(() {
    final File file = File('android/app/src/main/AndroidManifest.xml');
    expect(file.existsSync(), isTrue, reason: 'manifest must be in the repo');
    manifest = XmlDocument.parse(file.readAsStringSync()).rootElement;
    application = manifest.findAllElements('application').single;
  });

  test('backup and cleartext are both switched off', () {
    // Cloud/ADB backup would lift the Hive cache, preferences and any session
    // material the identity SDK stores. Cleartext is already off by default at
    // targetSdk 36; declaring it keeps that true if the sdk is lowered.
    expect(application.getAttribute('android:allowBackup'), 'false');
    expect(application.getAttribute('android:fullBackupContent'), 'false');
    expect(application.getAttribute('android:usesCleartextTraffic'), 'false');
  });

  test('only the launcher activity is exported, and nothing is debuggable', () {
    final Iterable<XmlElement> activities = manifest.findAllElements(
      'activity',
    );
    final Iterable<XmlElement> exported = activities.where(
      (XmlElement activity) =>
          activity.getAttribute('android:exported') == 'true',
    );
    expect(exported, hasLength(1));
    expect(exported.single.getAttribute('android:name'), '.MainActivity');
    expect(
      exported.single
          .findAllElements('action')
          .any(
            (XmlElement action) =>
                action.getAttribute('android:name') ==
                'android.intent.action.MAIN',
          ),
      isTrue,
    );
    expect(manifest.getAttribute('android:debuggable'), isNull);
    expect(application.getAttribute('android:debuggable'), isNull);
  });

  test('requests only the permissions the app uses', () {
    final Set<String> permissions = manifest
        .findAllElements('uses-permission')
        .map((XmlElement node) => node.getAttribute('android:name') ?? '')
        .where((String name) => name.isNotEmpty)
        .toSet();
    expect(permissions, <String>{
      'android.permission.INTERNET',
      'android.permission.ACCESS_NETWORK_STATE',
      'android.permission.POST_NOTIFICATIONS',
    });
  });

  test('deep links claim the custom scheme and one verified HTTPS host', () {
    // `https://slnews.sl/article/<id>` is an App Link: autoVerify must be on and
    // the host comes from the Gradle placeholder, so the manifest cannot drift
    // from the assetlinks route. `<queries>` also carries an https scheme for
    // url_launcher, so only the intent filters are in scope here.
    final Iterable<XmlElement> filters = manifest.findAllElements(
      'intent-filter',
    );
    final List<XmlElement> linkFilters = filters
        .where(
          (XmlElement filter) => filter
              .findAllElements('data')
              .any(
                (XmlElement data) =>
                    data.getAttribute('android:scheme') == 'slnews' ||
                    data.getAttribute('android:scheme') == 'https',
              ),
        )
        .toList(growable: false);

    final Set<String> customHosts = <String>{
      for (final XmlElement filter in linkFilters)
        for (final XmlElement data in filter.findAllElements('data'))
          if (data.getAttribute('android:scheme') == 'slnews')
            data.getAttribute('android:host') ?? '',
    };
    // Article deep links plus the three launcher shortcuts.
    expect(customHosts, <String>{'article', 'search', 'saved', 'following'});

    final XmlElement articleLink = linkFilters.singleWhere(
      (XmlElement filter) => filter
          .findAllElements('data')
          .any(
            (XmlElement data) =>
                data.getAttribute('android:scheme') == 'slnews' &&
                data.getAttribute('android:host') == 'article',
          ),
    );
    expect(articleLink.getAttribute('android:autoVerify'), 'false');

    final XmlElement httpsLink = linkFilters.singleWhere(
      (XmlElement filter) => filter
          .findAllElements('data')
          .any(
            (XmlElement data) => data.getAttribute('android:scheme') == 'https',
          ),
    );
    expect(httpsLink.getAttribute('android:autoVerify'), 'true');
    final XmlElement httpsData = httpsLink.findAllElements('data').single;
    expect(httpsData.getAttribute('android:host'), r'${deepLinkHost}');
    expect(httpsData.getAttribute('android:pathPrefix'), '/article/');

    // The placeholder must be defined, and to the same host the app claims.
    final File gradle = File('android/app/build.gradle.kts');
    final String gradleText = gradle.readAsStringSync();
    expect(
      gradleText,
      contains('manifestPlaceholders["deepLinkHost"] = "slnews.sl"'),
    );
    expect(appLinkHosts, <String>{'slnews.sl'});
  });
}
