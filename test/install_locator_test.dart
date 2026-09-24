import 'dart:io';

import 'package:apex_cfg_editor/core/paths/install_locator.dart';
import 'package:flutter_test/flutter_test.dart';

/// 断言前归一化到 `/`（Windows 风格输入等价）。
String _norm(String? p) => (p ?? '').replaceAll(r'\', '/');

Matcher samePath(String? expected) =>
    predicate<String>((a) => _norm(a) == _norm(expected), 'same path');

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('locator'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String writeConfig(String localDir, {bool settings = true, bool video = true}) {
    final dir = Directory(localDir)..createSync(recursive: true);
    if (settings) File('${dir.path}/settings.cfg').writeAsStringSync('x\n');
    if (video) File('${dir.path}/videoconfig.txt').writeAsStringSync('y\n');
    return dir.path;
  }

  group('Saved Games config dirs', () {
    test('finds settings.cfg and videoconfig.txt in local dir', () {
      final root = writeConfig('${tmp.path}/Saved Games/Respawn/Apex/local');
      final r = InstallLocator(
        env: {'USERPROFILE': tmp.path},
      ).locate();
      expect(r, hasLength(1));
      expect(r.first.settingsPath, samePath('$root/settings.cfg'));
      expect(r.first.videoconfigPath, samePath('$root/videoconfig.txt'));
      expect(r.first.source, InstallSource.savedGames);
    });

    test('settings.cfg alone is enough for a candidate', () {
      final root = writeConfig(
        '${tmp.path}/Saved Games/Respawn/Apex/local',
        video: false,
      );
      final r = InstallLocator(env: {'USERPROFILE': tmp.path}).locate();
      expect(r, hasLength(1));
      expect(r.first.settingsPath, samePath('$root/settings.cfg'));
      expect(r.first.videoconfigPath, isNull);
    });

    test('Documents / OneDrive / install dirs are ignored', () {
      File('${tmp.path}/Documents/Respawn/Apex/local/videoconfig.txt')
          .createSync(recursive: true);
      File(
        '${tmp.path}/Program Files/EA Games/Apex Legends/Respawn/Apex/local/settings.cfg',
      ).createSync(recursive: true);
      final r = InstallLocator(env: {'USERPROFILE': tmp.path}).locate();
      expect(r, isEmpty);
    });

    test('missing USERPROFILE → empty', () {
      expect(InstallLocator(env: const {}).locate(), isEmpty);
    });
  });

  group('custom config dir', () {
    test('dir itself as local dir is accepted', () {
      final root = writeConfig('${tmp.path}/CustomLocal');
      final r = InstallLocator(env: const {}).locate(
        customConfigDir: root,
      );
      expect(r, hasLength(1));
      expect(r.first.source, InstallSource.custom);
      expect(r.first.settingsPath, samePath('$root/settings.cfg'));
    });

    test('dir with nested Respawn/Apex/local is accepted', () {
      final root = writeConfig('${tmp.path}/CustomRoot/Respawn/Apex/local');
      final r = InstallLocator(env: const {}).locate(
        customConfigDir: '${tmp.path}/CustomRoot',
      );
      expect(r, hasLength(1));
      expect(r.first.configDir, samePath(root));
    });

    test('dir as Respawn/Apex accepts local child', () {
      final root = writeConfig('${tmp.path}/RespawnApex/local');
      final r = InstallLocator(env: const {}).locate(
        customConfigDir: '${tmp.path}/RespawnApex',
      );
      expect(r, hasLength(1));
      expect(r.first.configDir, samePath(root));
    });

    test('Saved Games hit does NOT drop custom', () {
      final saved = writeConfig(
        '${tmp.path}/SG/Saved Games/Respawn/Apex/local',
      );
      final custom = writeConfig('${tmp.path}/CustomLocal');
      final r = InstallLocator(env: {'USERPROFILE': '${tmp.path}/SG'}).locate(
        customConfigDir: custom,
      );
      expect(r, hasLength(2));
      expect(r[0].source, InstallSource.savedGames);
      expect(r[1].source, InstallSource.custom);
      expect(r[0].configDir, samePath(saved));
      expect(r[1].configDir, samePath(custom));
    });

    test('custom without any config files is ignored', () {
      Directory('${tmp.path}/Empty').createSync();
      final r = InstallLocator(env: const {}).locate(
        customConfigDir: '${tmp.path}/Empty',
      );
      expect(r, isEmpty);
    });

    test('dedup: same local dir via both sources kept once (saved first)', () {
      final root = writeConfig(
        '${tmp.path}/SG/Saved Games/Respawn/Apex/local',
      );
      final r = InstallLocator(env: {'USERPROFILE': '${tmp.path}/SG'}).locate(
        customConfigDir: root,
      );
      expect(r, hasLength(1));
      expect(r.first.source, InstallSource.savedGames);
    });

    test('backslash and trailing slash normalize to same path', () {
      final root = writeConfig('${tmp.path}/CustomLocal');
      final a = InstallLocator(env: const {}).locate(
        customConfigDir: root.replaceAll('/', r'\'),
      );
      final b = InstallLocator(env: const {}).locate(
        customConfigDir: '$root/',
      );
      expect(a, hasLength(1));
      expect(b, hasLength(1));
      expect(a.first.configDir, b.first.configDir);
    });
  });
}
