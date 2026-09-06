import 'dart:io';

import 'package:apex_cfg_editor/ui/theme/acid_theme.dart';
import 'package:apex_cfg_editor/ui/theme/diff_colors.dart';
import 'package:apex_cfg_editor/ui/theme/theme_mode_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAcidTheme (dark, 默认主题)', () {
    final theme = buildAcidTheme(Brightness.dark);

    test('acid green primary #AEEF00 on near-black surface #0A0B08', () {
      expect(theme.colorScheme.primary, const Color(0xFFAEEF00));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0A0B08));
      expect(theme.colorScheme.surface, const Color(0xFF0A0B08));
      expect(theme.colorScheme.onSurface, const Color(0xFFE8F0E0));
      expect(theme.colorScheme.surfaceContainer, const Color(0xFF121410));
    });

    test('danger（风险/警示）映射为酸性橙 #FF7A00', () {
      expect(theme.colorScheme.error, const Color(0xFFFF7A00));
      expect(AcidPalette.dark.danger, const Color(0xFFFF7A00));
    });

    test('registers AcidPalette + DiffColors extensions', () {
      expect(theme.extension<AcidPalette>(), AcidPalette.dark);
      expect(theme.extension<DiffColors>(), DiffColors.dark);
      // diff 语义：删除=酸性橙红、新增=酸绿，色值不同（语义分明）。
      expect(DiffColors.dark.deleteBg, isNot(DiffColors.dark.addBg));
    });

    test('display font is ChakraPetch with Chinese fallback chain', () {
      // ThemeData 不再直接暴露 fontFamily；断言走 textTheme 中的正文样式。
      final body = theme.textTheme.bodyMedium!;
      expect(body.fontFamily, 'ChakraPetch');
      expect(body.fontFamilyFallback, contains('PingFang SC'));
      expect(body.fontFamilyFallback, contains('Microsoft YaHei'));
    });
  });

  group('buildAcidTheme (light)', () {
    final theme = buildAcidTheme(Brightness.light);

    test('acid green #BFFF00 on paper white #F4F6F0', () {
      expect(theme.colorScheme.primary, const Color(0xFFBFFF00));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF4F6F0));
      expect(theme.colorScheme.onSurface, const Color(0xFF0C0E08));
    });

    test('registers light palette + light diff colors', () {
      expect(theme.extension<AcidPalette>(), AcidPalette.light);
      expect(theme.extension<DiffColors>(), DiffColors.light);
    });
  });

  group('AcidPalette ThemeExtension contract', () {
    test('copyWith overrides only given fields', () {
      final p = AcidPalette.dark.copyWith(acid: const Color(0xFFBFFF00));
      expect(p.acid, const Color(0xFFBFFF00));
      expect(p.bg, AcidPalette.dark.bg);
    });

    test('lerp halfway between dark and light', () {
      final mid = AcidPalette.dark.lerp(AcidPalette.light, 0.5);
      expect(
        mid.bg,
        Color.lerp(const Color(0xFF0A0B08), const Color(0xFFF4F6F0), 0.5),
      );
    });

    test('equality by field values', () {
      expect(AcidPalette.dark, AcidPalette.dark);
      expect(AcidPalette.dark, isNot(AcidPalette.light));
      expect(AcidPalette.dark.hashCode, AcidPalette.dark.hashCode);
    });
  });

  group('themeMode raw mapping', () {
    test('roundtrips all three modes', () {
      for (final mode in ThemeMode.values) {
        expect(themeModeFromRaw(themeModeToRaw(mode)), mode);
      }
    });

    test('illegal / missing values are null', () {
      expect(themeModeFromRaw(null), isNull);
      expect(themeModeFromRaw(''), isNull);
      expect(themeModeFromRaw('sepia'), isNull);
      expect(themeModeFromRaw('42'), isNull);
    });
  });

  group('font assets', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('Chakra Petch ttf files exist on disk (OFL bundle)', () {
      for (final f in [
        'ChakraPetch-Regular.ttf',
        'ChakraPetch-SemiBold.ttf',
        'ChakraPetch-Bold.ttf',
        'ChakraPetch-BoldItalic.ttf',
        'OFL.txt',
      ]) {
        expect(
          File('assets/fonts/$f').existsSync(),
          isTrue,
          reason: 'missing assets/fonts/$f',
        );
      }
    });

    test('fonts load through rootBundle (declared in pubspec)', () async {
      for (final f in [
        'assets/fonts/ChakraPetch-Regular.ttf',
        'assets/fonts/ChakraPetch-Bold.ttf',
        'assets/fonts/ChakraPetch-BoldItalic.ttf',
      ]) {
        final data = await rootBundle.load(f);
        expect(data.lengthInBytes, greaterThan(10000), reason: f);
      }
    });
  });
}
