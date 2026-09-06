import 'dart:io';

import 'package:apex_cfg_editor/core/paths/install_locator.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final dir = Directory('${tmp.path}/$name')
      ..createSync(recursive: true);
    if (autoexecSubdir != null) {
      final cfg = Directory('${dir.path}/$autoexecSubdir')
        ..createSync(recursive: true);
      if (autoexecFile) {
        File('${cfg.path}/autoexec.cfg').writeAsStringSync('// t\n');
      }
    }
    return dir.path;
  }

  group('document roots (videoconfig 候选)', () {
    test('finds videoconfig under USERPROFILE/Documents', () {
      final doc = '${tmp.path}/Documents';
      File('$doc/Respawn/Apex/local/videoconfig.txt')
          .createSync(recursive: true);
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: {'USERPROFILE': tmp.path},
      ).locate();
      expect(r, hasLength(1));
      expect(r.first.videoconfigPath,
          '$doc/Respawn/Apex/local/videoconfig.txt');
      expect(r.first.source, InstallSource.videoconfigDoc);
    });

    test('OneDrive env variants: Documents and 文档, all three variables', () {
      // %OneDrive% 指向 OneDrive 根，其下 Documents / 文档 才是文档库。
      for (final leaf in ['Documents', '文档']) {
        final doc = '${tmp.path}/OneDrive/$leaf';
        File('$doc/Respawn/Apex/local/videoconfig.txt')
            .createSync(recursive: true);
        final r = InstallLocator(
          registry: FakeRegistry(),
          drives: FakeDrives([]),
          env: {'OneDrive': '${tmp.path}/OneDrive'},
        ).locate();
        expect(r.map((i) => i.videoconfigPath),
            contains('$doc/Respawn/Apex/local/videoconfig.txt'));
      }
      for (final varName in ['OneDriveCommercial', 'OneDriveConsumer']) {
        final doc = '${tmp.path}/$varName/Documents';
        File('$doc/Respawn/Apex/local/videoconfig.txt')
            .createSync(recursive: true);
        final r = InstallLocator(
          registry: FakeRegistry(),
          drives: FakeDrives([]),
          env: {varName: '${tmp.path}/$varName'},
        ).locate();
        expect(r.map((i) => i.videoconfigPath),
            contains('$doc/Respawn/Apex/local/videoconfig.txt'));
      }
    });

    test('no videoconfig file → no document entry', () {
      Directory('${tmp.path}/Documents/Respawn/Apex/local')
          .createSync(recursive: true);
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: {'USERPROFILE': tmp.path},
      ).locate();
      expect(r, isEmpty);
    });
  });

  group('steam roots (registry + libraryfolders.vdf)', () {
    test('HKCU SteamPath → vdf → Apex install with existing autoexec dir',
        () {
      final apex = makeApexInstall(
          name: 'Steam/steamapps/common/Apex Legends',
          autoexecSubdir: 'global/cfg',
          autoexecFile: true);
      final steamRoot = '${tmp.path}/Steam';
      Directory('$steamRoot/steamapps').createSync(recursive: true);
      File('$steamRoot/steamapps/libraryfolders.vdf').writeAsStringSync('''
"libraryfolders"
{
  "0" { "path" "$steamRoot" }
}
''');
      final r = InstallLocator(
        registry: FakeRegistry(values: {
          'user|Software\\Valve\\Steam|SteamPath': steamRoot,
        }),
        drives: FakeDrives([]),
        env: const {},
      ).locate();
      expect(r, hasLength(1));
      expect(r.first.installDir, apex);
      expect(r.first.source, InstallSource.steam);
      expect(r.first.autoexecDir, '$apex/global/cfg');
      expect(r.first.autoexecPath, '$apex/global/cfg/autoexec.cfg');
    });

    test('HKLM WOW6432Node InstallPath used when HKCU missing', () {
      final apex = makeApexInstall(
          name: 'Steam2/steamapps/common/Apex Legends');
      final steamRoot = '${tmp.path}/Steam2';
      Directory('$steamRoot/steamapps').createSync(recursive: true);
      File('$steamRoot/steamapps/libraryfolders.vdf').writeAsStringSync(
          '"libraryfolders"\n{\n  "0" { "path" "$steamRoot" }\n}\n');
      final r = InstallLocator(
        registry: FakeRegistry(values: {
          'machine|SOFTWARE\\WOW6432Node\\Valve\\Steam|InstallPath':
              steamRoot,
        }),
        drives: FakeDrives([]),
        env: const {},
      ).locate();
      expect(r, hasLength(1));
      expect(r.first.installDir, apex);
      expect(r.first.autoexecPath, isNull);
    });

    test('vdf backslash escapes unescaped; secondary library probed', () {
      // vdf 的 "path" 是库根（不是游戏目录）；游戏目录由
      // <库根>/steamapps/common/Apex Legends 推导。
      final libRoot = '${tmp.path}/SteamLib';
      final apex = makeApexInstall(
          name: 'SteamLib/steamapps/common/Apex Legends',
          autoexecSubdir: 'r2/cfg',
          autoexecFile: true);
      final steamRoot = '${tmp.path}/Steam3';
      Directory('$steamRoot/steamapps').createSync(recursive: true);
      // vdf 中 Windows 路径的反斜杠转义：/ → \\
      final winPath = libRoot.replaceAll('/', r'\\');
      File('$steamRoot/steamapps/libraryfolders.vdf').writeAsStringSync(
          '"libraryfolders"\n{\n  "0" { "path" "$winPath" }\n}\n');
      final r = InstallLocator(
        registry: FakeRegistry(values: {
          'user|Software\\Valve\\Steam|SteamPath': steamRoot,
        }),
        drives: FakeDrives([]),
        env: const {},
      ).locate();
      expect(r, hasLength(1));
      expect(r.first.autoexecDir, '$apex/r2/cfg');
    });

    test('corrupt vdf skipped without throwing', () {
      final steamRoot = '${tmp.path}/Steam4';
      Directory('$steamRoot/steamapps').createSync(recursive: true);
      File('$steamRoot/steamapps/libraryfolders.vdf')
          .writeAsBytesSync([0xFF, 0xFE, 0x80, 0x00]);
      final r = InstallLocator(
        registry: FakeRegistry(values: {
          'user|Software\\Valve\\Steam|SteamPath': steamRoot,
        }),
        drives: FakeDrives([]),
        env: const {},
      ).locate();
      expect(r, isEmpty);
    });

    test('cfg dir exists without autoexec.cfg → dir recorded, path null '
        '(first candidate creatable)', () {
      makeApexInstall(
          name: 'Steam5/steamapps/common/Apex Legends',
          autoexecSubdir: 'cfg');
      final steamRoot = '${tmp.path}/Steam5-roots';
      Directory('$steamRoot/steamapps').createSync(recursive: true);
      File('$steamRoot/steamapps/libraryfolders.vdf').writeAsStringSync('''
"libraryfolders"
{
  "0" { "path" "${tmp.path}/Steam5" }
}
''');
      final r = InstallLocator(
        registry: FakeRegistry(values: {
          'user|Software\\Valve\\Steam|SteamPath': steamRoot,
        }),
        drives: FakeDrives([]),
        env: const {},
      ).locate();
      expect(r, hasLength(1));
      expect(r.first.autoexecDir,
          '${tmp.path}/Steam5/steamapps/common/Apex Legends/cfg');
      expect(r.first.autoexecPath, isNull);
    });

    test('no cfg subdir at all → first candidate (cfg) as creatable position',
        () {
      final apex = makeApexInstall(
          name: 'Steam6/steamapps/common/Apex Legends');
      final steamRoot = '${tmp.path}/Steam6-roots';
      Directory('$steamRoot/steamapps').createSync(recursive: true);
      File('$steamRoot/steamapps/libraryfolders.vdf').writeAsStringSync('''
"libraryfolders"
{
  "0" { "path" "$steamRoot" }
  "1" { "path" "${tmp.path}/Steam6" }
}
''');
      final r = InstallLocator(
        registry: FakeRegistry(values: {
          'user|Software\\Valve\\Steam|SteamPath': steamRoot,
        }),
        drives: FakeDrives([]),
        env: const {},
      ).locate();
      expect(r, hasLength(1));
      expect(r.first.installDir, apex);
      expect(r.first.autoexecDir, '$apex/cfg');
      expect(Directory('$apex/cfg').existsSync(), isFalse); // 尚未创建
    });
  });

  group('EA App roots (uninstall scan + common dirs + drive scan)', () {
    test('uninstall entry with Apex in DisplayName (case-insensitive) → '
        'InstallLocation becomes install', () {
      final apex = makeApexInstall(
          name: 'EA Games/Apex Legends', autoexecSubdir: 'cfg');
      final r = InstallLocator(
        registry: FakeRegistry(
          keys: {
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall':
                ['Apex Legends™'],
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
      expect(r.first.installDir, apex);
      expect(r.first.source, InstallSource.eaApp);
      expect(r.first.autoexecDir, '$apex/cfg');
    });

    test('non-Apex DisplayName ignored', () {
      final r = InstallLocator(
        registry: FakeRegistry(
          keys: {
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall':
                ['Some Game'],
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

    test('drive-letter scan yields EA Games / Origin Games / plain candidates',
        () {
      final probe = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives(['C', 'D']),
        env: const {},
      );
      final roots = probe.eaCommonRoots();
      expect(roots, containsAll([
        'C:/Program Files/EA Games/Apex Legends',
        'C:/Program Files/Origin Games/Apex Legends',
        'D:/EA Games/Apex Legends',
        'D:/Origin Games/Apex Legends',
        'D:/Apex Legends',
      ]));
    });
  });

  group('installsFromInstallDirs (纯逻辑：候选根 → 去重列表)', () {
    test('existing dir → install with autoexec candidates; dedup on '
        'normalized path (case + slash-insensitive)', () {
      final apex = makeApexInstall(autoexecSubdir: 'global/cfg');
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: const {},
      ).installsFromInstallDirs([apex, apex.toUpperCase(), apex.replaceAll('/', '\\')]);
      expect(r, hasLength(1));
      expect(r.first.autoexecDir, '$apex/global/cfg');
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
          autoexecFile: true);
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: const {},
      ).locate(customInstallDir: '${tmp.path}/Custom');
      expect(r, hasLength(1));
      expect(r.first.installDir, apex);
      expect(r.first.source, InstallSource.custom);
      expect(r.first.autoexecPath, '$apex/global/cfg/autoexec.cfg');
    });

    test('custom dir itself used when it is the game root', () {
      final apex = makeApexInstall(
          name: 'GameRoot', autoexecSubdir: 'cfg', autoexecFile: true);
      final r = InstallLocator(
        registry: FakeRegistry(),
        drives: FakeDrives([]),
        env: const {},
      ).locate(customInstallDir: apex);
      expect(r, hasLength(1));
      expect(r.first.installDir, apex);
      expect(r.first.autoexecPath, '$apex/cfg/autoexec.cfg');
    });

    test('detection non-empty → custom dir NOT added', () {
      final doc = '${tmp.path}/Documents';
      File('$doc/Respawn/Apex/local/videoconfig.txt')
          .createSync(recursive: true);
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
    test('videoconfig docs → steam → ea', () {
      final doc = '${tmp.path}/Documents';
      File('$doc/Respawn/Apex/local/videoconfig.txt')
          .createSync(recursive: true);
      final steamApex = makeApexInstall(
          name: 'S/steamapps/common/Apex Legends');
      final steamRoot = '${tmp.path}/SR';
      Directory('$steamRoot/steamapps').createSync(recursive: true);
      File('$steamRoot/steamapps/libraryfolders.vdf').writeAsStringSync('''
"libraryfolders"
{
  "0" { "path" "${tmp.path}/S" }
}
''');
      final eaApex = makeApexInstall(name: 'EA/Origin Games/Apex Legends');
      final r = InstallLocator(
        registry: FakeRegistry(
          keys: {
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall':
                ['EALauncher'],
          },
          values: {
            'user|Software\\Valve\\Steam|SteamPath': steamRoot,
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\EALauncher|DisplayName':
                'Apex Legends',
            'machine|SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\EALauncher|InstallLocation':
                eaApex,
          },
        ),
        drives: FakeDrives([]),
        env: {'USERPROFILE': tmp.path},
      ).locate();
      expect(r.map((i) => i.source).toList(),
          [InstallSource.videoconfigDoc, InstallSource.steam, InstallSource.eaApp]);
      expect(r[1].installDir, steamApex);
    });
  });
}
