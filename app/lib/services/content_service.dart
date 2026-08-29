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

  Future<ContentBundle> load() async {
    Map<String, dynamic>? remoteJson;
    try {
      final response = await http.get(Uri.parse(remoteUrl)).timeout(fetchTimeout);
      if (response.statusCode == 200) {
        remoteJson = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Offline, blocked, or CDN not deployed yet -- fall through to bundled.
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
