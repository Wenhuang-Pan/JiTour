import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime releaseDate;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releaseDate,
  });
}

class UpdateService {
  static const String currentVersion = '2.3.0';
  static const String githubOwner = 'Wenhuang-Pan';
  static const String githubRepo = 'JiTour';
  static const String _releasesUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
  static const Duration _cacheDuration = Duration(hours: 1);

  static Future<UpdateInfo?> checkForUpdate(
      {bool ignoreSkip = false, bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedResult = await _getCachedUpdate();
      if (cachedResult != null) {
        if (!ignoreSkip) {
          final skippedVersion = await _getSkippedVersion();
          if (skippedVersion == cachedResult.version) {
            return null;
          }
        }
        return cachedResult;
      }
    }

    try {
      final response = await http.get(
        Uri.parse(_releasesUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        String latestVersion = data['tag_name'] ?? '';
        if (latestVersion.startsWith('v')) {
          latestVersion = latestVersion.substring(1);
        }

        if (_compareVersions(latestVersion, currentVersion) > 0) {
          if (!ignoreSkip) {
            final skippedVersion = await _getSkippedVersion();
            if (skippedVersion == latestVersion) {
              return null;
            }
          }

          String downloadUrl = '';
          final assets = data['assets'] as List? ?? [];
          for (var asset in assets) {
            final name = asset['name'] ?? '';
            if (name.endsWith('.apk') || name.contains('web')) {
              downloadUrl = asset['browser_download_url'] ?? '';
              break;
            }
          }

          if (downloadUrl.isEmpty && data['body'] != null) {
            final body = data['body'].toString();
            final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(body);
            if (urlMatch != null) {
              downloadUrl = urlMatch.group(0) ?? '';
            }
          }

          if (downloadUrl.isEmpty) {
            downloadUrl =
                'https://github.com/$githubOwner/$githubRepo/releases/tag/v$latestVersion';
          }

          final updateInfo = UpdateInfo(
            version: latestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: data['body'] ?? '',
            releaseDate:
                DateTime.tryParse(data['published_at'] ?? '') ?? DateTime.now(),
          );

          await _cacheUpdate(updateInfo);
          return updateInfo;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> _cacheUpdate(UpdateInfo updateInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('update_cache_version', updateInfo.version);
    await prefs.setString('update_cache_download_url', updateInfo.downloadUrl);
    await prefs.setString(
        'update_cache_release_notes', updateInfo.releaseNotes);
    await prefs.setString(
        'update_cache_release_date', updateInfo.releaseDate.toIso8601String());
    await prefs.setInt(
        'update_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<UpdateInfo?> _getCachedUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('update_cache_timestamp');
    if (timestamp == null) return null;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(cacheTime) > _cacheDuration) {
      return null;
    }

    final version = prefs.getString('update_cache_version');
    final downloadUrl = prefs.getString('update_cache_download_url');
    final releaseNotes = prefs.getString('update_cache_release_notes');
    final releaseDateStr = prefs.getString('update_cache_release_date');

    if (version != null && downloadUrl != null) {
      return UpdateInfo(
        version: version,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes ?? '',
        releaseDate: DateTime.tryParse(releaseDateStr ?? '') ?? DateTime.now(),
      );
    }
    return null;
  }

  static Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skipped_update_version', version);
  }

  static Future<void> clearSkip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('skipped_update_version');
  }

  static Future<String?> _getSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('skipped_update_version');
  }

  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  static String getVersion() => currentVersion;
}
