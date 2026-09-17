import 'package:apex_cfg_editor/core/update/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('compares v-prefixed versions by numeric components', () {
      expect(compareVersions('v1.10.0', '1.2.3'), greaterThan(0));
      expect(compareVersions('1.2.0', 'v1.2.0'), 0);
      expect(compareVersions('1.1.9', '1.2.0'), lessThan(0));
    });
  });

  group('UpdateService', () {
    test('parses latest release and reports an available update', () async {
      final service = UpdateService(
        currentVersion: '1.0.0',
        fetchJson: (_) async => '''
          {
            "tag_name": "v1.2.0",
            "name": "Performance pass",
            "html_url": "https://github.com/NoelOrin/apex-cfg-editor/releases/tag/v1.2.0"
          }
        ''',
      );

      final result = await service.checkForUpdates();

      expect(result.hasUpdate, isTrue);
      expect(result.latestRelease.version, '1.2.0');
      expect(result.latestRelease.name, 'Performance pass');
      expect(
        result.latestRelease.url.toString(),
        contains('/releases/tag/v1.2.0'),
      );
    });

    test(
      'reports no update when the latest release matches the current version',
      () async {
        final service = UpdateService(
          currentVersion: '1.2.0',
          fetchJson: (_) async =>
              '{"tag_name":"1.2.0","html_url":"https://github.com/NoelOrin/apex-cfg-editor/releases/tag/1.2.0"}',
        );

        final result = await service.checkForUpdates();

        expect(result.hasUpdate, isFalse);
      },
    );

    test('rejects malformed release payloads', () async {
      final service = UpdateService(
        currentVersion: '1.0.0',
        fetchJson: (_) async => '{"name":"missing tag"}',
      );

      expect(service.checkForUpdates, throwsA(isA<UpdateCheckException>()));
    });

    test('wraps fetch failures as update check errors', () async {
      final service = UpdateService(
        currentVersion: '1.0.0',
        fetchJson: (_) async => throw StateError('offline'),
      );

      expect(service.checkForUpdates, throwsA(isA<UpdateCheckException>()));
    });
  });
}
