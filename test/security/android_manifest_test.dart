import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  test('deep links stay on the custom scheme', () {
    // An HTTPS autoVerify filter without a served assetlinks.json would let the
    // app claim a domain it does not control; the custom scheme is deliberate.
    // (`<queries>` also carries an https scheme for url_launcher, so only the
    // intent filters are in scope here.)
    final Iterable<XmlElement> data = manifest
        .findAllElements('intent-filter')
        .expand((XmlElement filter) => filter.findAllElements('data'))
        .where(
          (XmlElement node) => node.getAttribute('android:scheme') != null,
        );
    expect(data, isNotEmpty);
    for (final XmlElement node in data) {
      expect(node.getAttribute('android:scheme'), 'slnews');
    }
  });
}
