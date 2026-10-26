import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class AppRelease {
  const AppRelease({
    required this.versionTag,
    required this.title,
    required this.notes,
    required this.downloadUrl,
    required this.htmlUrl,
  });

  final String versionTag;
  final String title;
  final String notes;
  final String downloadUrl;
  final String htmlUrl;
}

abstract class UpdateService {
  Future<AppRelease?> checkForUpdate();
  Future<bool> launchDownload(String url);
}

class GitHubUpdateService implements UpdateService {
  GitHubUpdateService({
    this.repoOwner = 'onebotyt',
    this.repoName = 'Smart-To-Do',
    this.currentVersion = const String.fromEnvironment('APP_VERSION', defaultValue: '0.1.16'),
  });

  final String repoOwner;
  final String repoName;
  final String currentVersion;

  @override
  Future<AppRelease?> checkForUpdate() async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(
          'https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'SyncTask-App');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final tagName = (data['tag_name'] as String?) ?? '';
      final title = (data['name'] as String?) ?? tagName;
      final notes = (data['body'] as String?) ?? '';
      final htmlUrl = (data['html_url'] as String?) ?? '';

      if (tagName.isEmpty) return null;

      final cleanTag = tagName.replaceAll(RegExp(r'^[vV]'), '');
      if (!_isNewerVersion(cleanTag, currentVersion)) {
        return null;
      }

      String downloadUrl = htmlUrl;
      final assets = (data['assets'] as List<dynamic>?) ?? [];
      for (final a in assets) {
        if (a is Map<String, dynamic>) {
          final name = (a['name'] as String? ?? '').toLowerCase();
          final browserUrl = a['browser_download_url'] as String? ?? '';
          if (Platform.isAndroid) {
            // Prioritize lightweight ~20MB arm64 APK for phones
            if (name.contains('arm64') && name.endsWith('.apk')) {
              downloadUrl = browserUrl;
              break;
            } else if (name.endsWith('.apk') && downloadUrl == htmlUrl) {
              downloadUrl = browserUrl;
            }
          } else if (Platform.isWindows) {
            // Prioritize standard Windows Setup installer
            if (name.endsWith('.exe')) {
              downloadUrl = browserUrl;
              break;
            } else if (name.endsWith('.zip') && downloadUrl == htmlUrl) {
              downloadUrl = browserUrl;
            }
          }
        }
      }

      return AppRelease(
        versionTag: tagName,
        title: title,
        notes: notes,
        downloadUrl: downloadUrl,
        htmlUrl: htmlUrl,
      );
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  @override
  Future<bool> launchDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final currentParts = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    for (var i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  }
}
