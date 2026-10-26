import 'package:flutter_test/flutter_test.dart';
import 'package:synctask/platform/update_service.dart';

void main() {
  group('GitHubUpdateService', () {
    test('release model initializes correctly', () {
      const release = AppRelease(
        versionTag: 'v0.1.2',
        title: 'SyncTask v0.1.2',
        notes: 'Bug fixes and performance improvements',
        downloadUrl: 'https://github.com/onebotyt/Smart-To-Do/releases/download/v0.1.2/app.apk',
        htmlUrl: 'https://github.com/onebotyt/Smart-To-Do/releases/tag/v0.1.2',
      );

      expect(release.versionTag, 'v0.1.2');
      expect(release.title, 'SyncTask v0.1.2');
      expect(release.downloadUrl, contains('.apk'));
    });

    test('update service handles default constructor attributes', () {
      final service = GitHubUpdateService(
        repoOwner: 'onebotyt',
        repoName: 'Smart-To-Do',
        currentVersion: '0.1.0',
      );

      expect(service.repoOwner, 'onebotyt');
      expect(service.repoName, 'Smart-To-Do');
      expect(service.currentVersion, '0.1.0');
    });
  });
}
