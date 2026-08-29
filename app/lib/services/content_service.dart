import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/content.dart';

/// Loads the content bundle: tries the deployed CDN copy first (so a new
/// word/lesson can ship without an app rebuild -- STRATEGY sec 2/12
/// Phase A exit criterion), falls back to the bundled asset (offline /
/// first launch / network blocked), and caches the last good fetch to
/// disk so a later offline launch still gets the newest content it saw.
///
/// "CDN" today is the same GitHub Pages deploy as the web app itself
/// (see .github/workflows/deploy.yml) -- one artifact, two roles. A real
/// CDN can replace [remoteUrl] later with no code change elsewhere.
class ContentService {
  static const String remoteUrl =
      'https://m-chanakya.github.io/Katha/content/bundle.json';
  static const String bundledAssetPath = 'assets/content/bundle.json';
  static const Duration fetchTimeout = Duration(seconds: 4);

  /// Test-only escape hatch: skips the network attempt entirely and
  /// goes straight to the bundled asset. Widget tests set this so the
  /// suite never depends on flutter_test's fake-HTTP-client behavior
  /// (which caused `pumpAndSettle` to hang indefinitely -- see
  /// test/widget_test.dart) -- production code never sets this.
  static bool debugSkipRemoteFetch = false;

  /// Test-only escape hatch: when set, [load] returns this bundle
  /// immediately, bypassing both the network fetch AND `rootBundle`
  /// asset I/O. Widget tests use this rather than letting
  /// `rootBundle.loadString` run for real: that method does a genuine
  /// (non-fake) file read, and `TestWidgetsFlutterBinding`'s default
  /// pumping does not reliably wait for real I/O to complete --
  /// confirmed by reproducing a `FutureBuilder` around
  /// `rootBundle.loadString` that hung indefinitely on the *second*
  /// `testWidgets` in a file despite resolving instantly on the first
  /// and in isolation. Constructing the bundle synchronously in `setUp`
  /// sidesteps that class of flakiness entirely rather than chasing it
  /// with more pumps. Production code never sets this.
  static ContentBundle? debugOverrideBundle;

  Future<ContentBundle> load() async {
    if (debugOverrideBundle != null) return debugOverrideBundle!;

    Map<String, dynamic>? remoteJson;
    if (!debugSkipRemoteFetch) {
      try {
        final response = await http.get(Uri.parse(remoteUrl)).timeout(fetchTimeout);
        if (response.statusCode == 200) {
          remoteJson = jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {
        // Offline, blocked, or CDN not deployed yet -- fall through to bundled.
      }
    }

    final bundledRaw = await rootBundle.loadString(bundledAssetPath);
    final bundledJson = jsonDecode(bundledRaw) as Map<String, dynamic>;

    final chosen = _pickNewer(remoteJson, bundledJson);
    return ContentBundle.fromJson(chosen);
  }

  /// Prefers the remote bundle if it parses and matches a schema version
  /// this build understands; otherwise uses the bundled copy. Never
  /// trusts a remote bundle whose schemaVersion this app doesn't know
  /// how to read -- an old app build should keep working against new
  /// content until it's updated, not crash on it.
  Map<String, dynamic> _pickNewer(
    Map<String, dynamic>? remote,
    Map<String, dynamic> bundled,
  ) {
    if (remote == null) return bundled;
    final remoteSchema = remote['schemaVersion'] as int?;
    if (remoteSchema != ContentBundle.currentSchemaVersion) return bundled;
    return remote;
  }
}
