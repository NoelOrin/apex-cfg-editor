import 'package:apex_cfg_editor/core/paths/windows_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaultRegistryReader (平台工厂)', () {
    test('non-Windows → null-reading reader (macOS 开发期/测试安全)', () {
      final r = defaultRegistryReader(isWindows: false);
      expect(
        r.readString(RegistryView.user, r'Software\Valve\Steam', 'SteamPath'),
        isNull,
      );
      expect(
        r.subKeys(
          RegistryView.machine,
          r'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        ),
        isEmpty,
      );
    });

    test('Windows → win32-backed reader type', () {
      expect(
        defaultRegistryReader(isWindows: true),
        isA<Win32RegistryReader>(),
      );
    });
  });

  group('fixedDriveLister', () {
    test('probes C-F drive roots', () {
      expect(fixedDriveLister.driveLetters(), ['C', 'D', 'E', 'F']);
    });
  });
}
