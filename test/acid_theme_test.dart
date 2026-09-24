import 'package:apex_cfg_editor/core/paths/windows_registry.dart';
import 'package:apex_cfg_editor/ui/theme/acid_theme.dart';
import 'package:apex_cfg_editor/ui/theme/diff_colors.dart';
import 'package:apex_cfg_editor/ui/theme/theme_mode_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAcidTheme (dark, 默认主题)', () {
    final theme = buildAcidTheme(Brightness.dark);

    test('Win11 dark surface #202020 with system-blue accent #4CC2FF', () {
      expect(theme.colorScheme.primary, const Color(0xFF4CC2FF));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF202020));
      expect(theme.colorScheme.surface, const Color(0xFF202020));
      expect(theme.colorScheme.onSurface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.surfaceContainer, const Color(0xFF2B2B2B));
    });

    test('danger（风险/警示）映射 SystemFillColorCritical #FF99A4', () {
      expect(theme.colorScheme.error, const Color(0xFFFF99A4));
      expect(AcidPalette.dark.danger, const Color(0xFFFF99A4));
    });

    test('registers AcidPalette + DiffColors extensions', () {
      expect(theme.extension<AcidPalette>(), AcidPalette.dark);
      expect(theme.extension<DiffColors>(), DiffColors.dark);
      // diff 语义：删除=红、新增=绿，色值不同（语义分明）。
      expect(DiffColors.dark.deleteBg, isNot(DiffColors.dark.addBg));
    });

    test('UI font is Segoe UI Variable Text with CJK fallback chain', () {
      final body = theme.textTheme.bodyMedium!;
      expect(body.fontFamily, kFontUi);
      expect(body.fontFamilyFallback, contains('PingFang SC'));
      expect(body.fontFamilyFallback, contains('Microsoft YaHei'));
    });

    test('Windows UI font stack leads with Segoe UI Variable Text', () {
      final body = theme.textTheme.bodyMedium!;
      expect(kFontUi, 'Segoe UI Variable Text');
      expect(body.fontFamily, 'Segoe UI Variable Text');
      expect(body.fontFamilyFallback!.first, 'Segoe UI Variable Text');
      expect(body.fontFamilyFallback, contains('Microsoft YaHei'));
      expect(body.fontFamilyFallback, contains('PingFang SC'));
    });

    test('Fluent body uses UI font while headings keep display font', () {
      final fluentTheme = buildFluentTheme(
        Brightness.dark,
        appearanceReader: NullAppearanceReader(),
      );
      expect(fluentTheme.typography.body!.fontFamily, kFontUi);
      expect(
        fluentTheme.typography.body!.fontFamilyFallback,
        contains('Microsoft YaHei'),
      );
      expect(fluentTheme.typography.title!.fontFamily, kFontDisplay);
    });

    test('Fluent theme follows injected system accent', () {
      final fluentTheme = buildFluentTheme(
        Brightness.dark,
        accent: const Color(0xFF9A5CF4),
        appearanceReader: NullAppearanceReader(),
      );
      expect(fluentTheme.accentColor.normal, const Color(0xFF9A5CF4));
      final palette = fluentTheme.extension<AcidPalette>()!;
      expect(palette.acid, const Color(0xFF9A5CF4));
    });
  });

  group('buildAcidTheme (light)', () {
    final theme = buildAcidTheme(Brightness.light);

    test('Win11 light surface #F3F3F3 with system-blue accent #0067C0', () {
      expect(theme.colorScheme.primary, const Color(0xFF0067C0));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF3F3F3));
      expect(theme.colorScheme.onSurface, const Color(0xFF1A1A1A));
    });

    test('registers light palette + light diff colors', () {
      expect(theme.extension<AcidPalette>(), AcidPalette.light);
      expect(theme.extension<DiffColors>(), DiffColors.light);
    });
  });

  group('AcidPalette ThemeExtension contract', () {
    test('copyWith overrides only given fields', () {
      final p = AcidPalette.dark.copyWith(acid: const Color(0xFF0067C0));
      expect(p.acid, const Color(0xFF0067C0));
      expect(p.bg, AcidPalette.dark.bg);
    });

    test('lerp halfway between dark and light', () {
      final mid = AcidPalette.dark.lerp(AcidPalette.light, 0.5);
      expect(
        mid.bg,
        Color.lerp(const Color(0xFF202020), const Color(0xFFF3F3F3), 0.5),
      );
    });

    test('equality by field values', () {
      expect(AcidPalette.dark, AcidPalette.dark);
      expect(AcidPalette.dark, isNot(AcidPalette.light));
      expect(AcidPalette.dark.hashCode, AcidPalette.dark.hashCode);
    });

    test('withAccent picks readable on-color', () {
      final lightAccent = AcidPalette.withAccent(
        Brightness.dark,
        const Color(0xFFFFFFFF),
      );
      expect(lightAccent.onAcid, const Color(0xFF1A1A1A));
      final darkAccent = AcidPalette.withAccent(
        Brightness.dark,
        const Color(0xFF003855),
      );
      expect(darkAccent.onAcid, const Color(0xFFFFFFFF));
    });
  });

  group('themeMode raw mapping', () {
    test('roundtrips all three modes', () {
      for (final mode in ThemeMode.values) {
        expect(themeModeFromRaw(themeModeToRaw(mode)), mode);
      }
      expect(themeModeFromRaw('nope'), isNull);
      expect(themeModeFromRaw(null), isNull);
    });
  });
}
