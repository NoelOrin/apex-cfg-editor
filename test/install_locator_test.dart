import 'dart:io';

import 'package:apex_cfg_editor/core/paths/install_locator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Windows 上探测引擎用 `\` 拼接（文件系统等价），断言前归一化到 `/`。
String _norm(String? p) => (p ?? '').replaceAll(r'\', '/');

Matcher samePath(String? expected) =>
    predicate<String>((a) => _norm(a) == _norm(expected), 'same path');

/// 假注册表：键为 `view|keyPath|valueName`，子键为 `view|keyPath`。
class FakeRegistry implements RegistryReader {
  final Map<String, String?> values;
  final Map<String, List<String>> keys;

  FakeRegistry({this.values = const {}, this.keys = const {}});

  @override
  String? readString(RegistryView view, String keyPath, String valueName) =>
      values['${view.name}|$keyPath|$valueName'];

  @override
  List<String> subKeys(RegistryView view, String keyPath) =>
      keys['${view.name}|$keyPath'] ?? const [];
}

class FakeDrives implements DriveLister {
  final List<String> letters;
  FakeDrives(this.letters);
  @override
  List<String> driveLetters() => letters;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('locator'));
  tearDown(() => tmp.deleteSync(recursive: true));

  // 在 tmp 下造一个 Apex 安装目录，返回其路径。
  String makeApexInstall({
    String name = 'Apex Legends',
    String? autoexecSubdir,
    bool autoexecFile = false,
  }) {
    final dir = Directory('${tmp.path}/$name')..createSync(recursive: true);
    if (autoexecSubdir != null) {
      final cfg = Directory('${dir.path}/$autoexecSubdir')
        ..createSync(recursive: true);
      if (autoexecFile) {
        File('${cfg.path}/autoexec.cfg').writeAsStringSync('// t\n');
      }
    }
    return dir.path;
  }

  group('Saved Games config roots', () {
    test('finds settings.cfg and videoconfig.txt in the same local dir', () {
      final root = '${tmp.path}/Saved Games/Respawn/Apex/local';
      File('$root/settings.cfg').createSync(recursive: true);
      File('$root/videoconfig.txt').createSync(recursive: true);
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: {'USERPROFILE': tmp.path},
      ).locate();
      expect(r, hasLength(1));
      expect(r.first.settingsPath, samePath('$root/settings.cfg'));
      expect(r.first.videoconfigPath, samePath('$root/videoconfig.txt'));
    });

    test('settings.cfg alone is enough for a config candidate', () {
      final root = '${tmp.path}/Saved Games/Respawn/Apex/local';
      File('$root/settings.cfg').createSync(recursive: true);
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: {'USERPROFILE': tmp.path},
      ).locate();
      expect(r, hasLength(1));
      expect(r.first.settingsPath, samePath('$root/settings.cfg'));
    });

    test('Documents and OneDrive paths are ignored', () {
      File(
        '${tmp.path}/Documents/Respawn/Apex/local/videoconfig.txt',
      ).createSync(recursive: true);
      File(
        '${tmp.path}/OneDrive/Documents/Respawn/Apex/local/settings.cfg',
      ).createSync(recursive: true);
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: {'USERPROFILE': tmp.path, 'OneDrive': '${tmp.path}/OneDrive'},
      ).locate();
      expect(r, isEmpty);
    });
  });

  group('EA App roots (uninstall scan + common dirs + drive scan)', () {
    test('uninstall entry with Apex in DisplayName (case-insensitive) → '
        'InstallLocation becomes install', () {
      final apex = makeApexInstall(
        name: 'EA Games/Apex Legends',
        autoexecSubdir: 'cfg',
      );
      final r = InstallLocator(
        registry: FakeRegistry(
          keys: {
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall': [
              'Apex Legends™',
            ],
            'machine|SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall':
                [],
            'user|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall': [],
          },
          values: {
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Apex Legends™|DisplayName':
                'Apex Legends™',
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Apex Legends™|InstallLocation':
                apex,
          },
        ),
        drives: FakeDrives([]),
        env: const {},
      ).locate();
      expect(r, hasLength(1));
      expect(_norm(r.first.installDir), _norm(apex));
      expect(r.first.source, InstallSource.eaApp);
      expect(r.first.autoexecDir, samePath('$apex/cfg'));
    });

    test('non-Apex DisplayName ignored', () {
      final r = InstallLocator(
        registry: FakeRegistry(
          keys: {
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall': [
              'Some Game',
            ],
          },
          values: {
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Some Game|DisplayName':
                'Some Game',
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Some Game|InstallLocation':
                '${tmp.path}/x',
          },
        ),
        drives: FakeDrives([]),
        env: const {},
      ).locate();
      expect(r, isEmpty);
    });

    test(
      'drive-letter scan yields EA Games / Origin Games / plain candidates',
      () {
        final probe = InstallLocator(
          registry: FakeRegistry(),
          drives: FakeDrives(['C', 'D']),
          env: const {},
        );
        final roots = probe.eaCommonRoots();
        expect(
          roots,
          containsAll([
            'C:/Program Files/EA Games/Apex Legends',
            'C:/Program Files/Origin Games/Apex Legends',
            'D:/EA Games/Apex Legends',
            'D:/Origin Games/Apex Legends',
            'D:/Apex Legends',
          ]),
        );
      },
    );
  });

  group('installsFromInstallDirs (纯逻辑：候选根 → 去重列表)', () {
    test('existing dir → install with autoexec candidates; dedup on '
        'normalized path (case + slash-insensitive)', () {
      final apex = makeApexInstall(autoexecSubdir: 'global/cfg');
      final r =
          InstallLocator(
            registry: FakeRegistry(),
            drives: FakeDrives([]),
            env: const {},
          ).installsFromInstallDirs([
            apex,
            apex.toUpperCase(),
            apex.replaceAll('/', '\\'),
          ]);
      expect(r, hasLength(1));
      expect(r.first.autoexecDir, samePath('$apex/global/cfg'));
    });

    test('missing dir filtered out', () {
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: const {},
      ).installsFromInstallDirs(['${tmp.path}/nope']);
      expect(r, isEmpty);
    });
  });

  group('customInstallDir (用户记忆路径)', () {
    test('detection empty → custom dir candidates included', () {
      final apex = makeApexInstall(
        name: 'Custom/steamapps/common/Apex Legends',
        autoexecSubdir: 'global/cfg',
        autoexecFile: true,
      );
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: const {},
      ).locate(customInstallDir: '${tmp.path}/Custom');
      expect(r, hasLength(1));
      expect(_norm(r.first.installDir), _norm(apex));
      expect(r.first.source, InstallSource.custom);
      expect(r.first.autoexecPath, samePath('$apex/global/cfg/autoexec.cfg'));
    });

    test('custom dir itself used when it is the game root', () {
      final apex = makeApexInstall(
        name: 'GameRoot',
        autoexecSubdir: 'cfg',
        autoexecFile: true,
      );
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: const {},
      ).locate(customInstallDir: apex);
      expect(r, hasLength(1));
      expect(_norm(r.first.installDir), _norm(apex));
      expect(r.first.autoexecPath, samePath('$apex/cfg/autoexec.cfg'));
    });

    test('detection non-empty → custom dir NOT added', () {
      final doc = '${tmp.path}/Saved Games';
      File(
        '$doc/Respawn/Apex/local/videoconfig.txt',
      ).createSync(recursive: true);
      makeApexInstall(name: 'Elsewhere');
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: {'USERPROFILE': tmp.path},
      ).locate(customInstallDir: '${tmp.path}/Elsewhere');
      expect(r, hasLength(1));
      expect(r.first.source, InstallSource.videoconfigDoc);
    });

    test('nonexistent custom dir ignored silently', () {
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: const {},
      ).locate(customInstallDir: '${tmp.path}/ghost');
      expect(r, isEmpty);
    });
  });

  group('ordering', () {
    test('Saved Games config → EA install only', () {
      final doc = '${tmp.path}/Saved Games';
      File('$doc/Respawn/Apex/local/settings.cfg').createSync(recursive: true);
      final eaApex = makeApexInstall(name: 'EA/Origin Games/Apex Legends');
      final r = InstallLocator(
        registry: FakeRegistry(
          keys: {
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall': [
              'EALauncher',
            ],
          },
          values: {
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\EALauncher|DisplayName':
                'Apex Legends',
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\EALauncher|InstallLocation':
                eaApex,
          },
        ),
        drives: FakeDrives([]),
        env: {'USERPROFILE': tmp.path},
      ).locate();
      expect(r.map((i) => i.source).toList(), [
        InstallSource.videoconfigDoc,
        InstallSource.eaApp,
      ]);
      expect(_norm(r[1].installDir), _norm(eaApex));
    });
  });

  group('apexInstallDirFromOpenedDir (customInstallDir 回写推导)', () {
    test('cfg / global/cfg / r2/cfg 父目录 → 剥到安装根', () {
      const f = apexInstallDirFromOpenedDir;
      expect(_norm(f('${tmp.path}/Apex/cfg')!), _norm('${tmp.path}/Apex'));
      expect(
        _norm(f('${tmp.path}/Apex/global/cfg')!),
        _norm('${tmp.path}/Apex'),
      );
      expect(_norm(f('${tmp.path}/Apex/r2/cfg')!), _norm('${tmp.path}/Apex'));
    });

    test('Steam 安装树内任意文件 → 根为 Apex Legends 目录', () {
      const f = apexInstallDirFromOpenedDir;
      final apex = '${tmp.path}/Lib/steamapps/common/Apex Legends';
      expect(_norm(f('$apex/cfg')!), _norm(apex));
      expect(_norm(f('$apex/whatever/deep/dir')!), _norm(apex));
      expect(_norm(f(apex)!), _norm(apex));
    });

    test('Saved Games 配置目录 → null（配置根不是安装目录）', () {
      expect(
        apexInstallDirFromOpenedDir(
          '${tmp.path}/Saved Games/Respawn/Apex/local',
        ),
        isNull,
      );
    });

    test('随机目录 → null；反斜杠输入归一化', () {
      expect(apexInstallDirFromOpenedDir('${tmp.path}/Downloads'), isNull);
      expect(apexInstallDirFromOpenedDir(r'C:\Game\Apex\cfg'), 'C:/Game/Apex');
    });
  });
}
