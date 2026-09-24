import 'package:apex_cfg_editor/core/paths/windows_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaultAppearanceReader (平台工厂)', () {
    test('non-Windows → null-reading reader (macOS 开发期/测试安全)', () {
      final r = defaultAppearanceReader(isWindows: false);
      expect(r.readAccentColorValue(), isNull);
      expect(r.readAppsUseLightTheme(), isNull);
    });

    test('Windows → win32-backed reader type', () {
      expect(
        defaultAppearanceReader(isWindows: true),
        isA<Win32AppearanceReader>(),
      );
    });
  });

  test('NullAppearanceReader always returns null', () {
    final r = NullAppearanceReader();
    expect(r.readAccentColorValue(), isNull);
    expect(r.readAppsUseLightTheme(), isNull);
  });
}
