import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../core/paths/windows_registry.dart';
import '../../l10n/app_localizations.dart';
import 'diff_colors.dart';

/// 展示字体：Windows 11 / Segoe UI Variable 优先；中文经 [kFontFallbacks]
/// 回退系统字体。字体家族对齐 Fluent / Win11 系统字体栈。
const String kFontDisplay = 'Segoe UI Variable Display';

/// UI 正文字体：Windows 11 正文栈，中文回退微软雅黑 UI。
const String kFontUi = 'Segoe UI Variable Text';

/// cfg 内容区 monospace（表格 / diff / 文本编辑器已按需指定）。
const String kFontMono = 'Consolas';

/// 通用字体回退链：Segoe → 微软雅黑 UI / 微软雅黑 → 苹方 / Noto。
const List<String> kFontFallbacks = [
  'Segoe UI Variable Text',
  'Segoe UI',
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'PingFang SC',
  'Noto Sans SC',
  'sans-serif',
];

/// 等宽字体回退链。
const List<String> kFontMonoFallbacks = [
  'Cascadia Mono',
  'Consolas',
  'SF Mono',
  'Menlo',
  'monospace',
];

TextStyle? _withFont(
  TextStyle? style, {
  required String family,
  required List<String> fallbacks,
}) => style?.copyWith(fontFamily: family, fontFamilyFallback: fallbacks);

/// Fluent / Windows 11 语义色板（ThemeExtension）。
/// 色值全部对齐 Win11 Fluent 设计令牌（ResourceDictionary），
/// 强调色默认取系统 accent（[systemAccentColor]），无则回退
/// Windows 默认蓝 #0067C0 / 暗色 #4CC2FF。
@immutable
class AcidPalette extends ThemeExtension<AcidPalette> {
  /// 主色：系统强调色（按钮、选中、品牌点缀）。
  final Color acid;

  /// 强调色之上的文字。
  final Color onAcid;

  /// 窗口底色（SolidBackgroundFillColorBase）。
  final Color bg;

  /// 面板/卡片底色（CardBackgroundFillColorDefault）。
  final Color panel;

  /// 主文字色（TextFillColorPrimary）。
  final Color text;

  /// 次级文字色（TextFillColorSecondary）。
  final Color textMuted;

  /// 描边/分隔（DividerStrokeColorDefault）。
  final Color chrome;

  /// 风险/错误（SystemFillColorCritical）。
  final Color danger;

  const AcidPalette({
    required this.acid,
    required this.onAcid,
    required this.bg,
    required this.panel,
    required this.text,
    required this.textMuted,
    required this.chrome,
    required this.danger,
  });

  /// 暗色主题（Windows 11 Dark）。
  static const dark = AcidPalette(
    acid: Color(0xFF4CC2FF),
    onAcid: Color(0xFF003855),
    bg: Color(0xFF202020),
    panel: Color(0xFF2B2B2B),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFF9E9E9E),
    chrome: Color(0xFF3B3B3B),
    danger: Color(0xFFFF99A4),
  );

  /// 亮色主题（Windows 11 Light）。
  static const light = AcidPalette(
    acid: Color(0xFF0067C0),
    onAcid: Color(0xFFFFFFFF),
    bg: Color(0xFFF3F3F3),
    panel: Color(0xFFFFFFFF),
    text: Color(0xFF1A1A1A),
    textMuted: Color(0xFF5D5D5D),
    chrome: Color(0xFFE0E0E0),
    danger: Color(0xFFC42B1C),
  );

  /// 以系统强调色构造色板（Windows 11 跟随系统主题色）。
  static AcidPalette withAccent(Brightness brightness, Color accent) {
    final base = brightness == Brightness.dark ? dark : light;
    final luminance = accent.computeLuminance();
    final onAccent = luminance > 0.5 ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
    return base.copyWith(acid: accent, onAcid: onAccent);
  }

  /// 快捷读取：主题未注册色板时（部分测试宿主）回退暗色值。
  static AcidPalette of(BuildContext context) =>
      fluent.FluentTheme.maybeOf(context)?.extension<AcidPalette>() ??
      Theme.of(context).extension<AcidPalette>() ??
      dark;

  @override
  AcidPalette copyWith({
    Color? acid,
    Color? onAcid,
    Color? bg,
    Color? panel,
    Color? text,
    Color? textMuted,
    Color? chrome,
    Color? danger,
  }) => AcidPalette(
    acid: acid ?? this.acid,
    onAcid: onAcid ?? this.onAcid,
    bg: bg ?? this.bg,
    panel: panel ?? this.panel,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    chrome: chrome ?? this.chrome,
    danger: danger ?? this.danger,
  );

  @override
  AcidPalette lerp(covariant AcidPalette? other, double t) {
    if (other == null) return this;
    return AcidPalette(
      acid: Color.lerp(acid, other.acid, t)!,
      onAcid: Color.lerp(onAcid, other.onAcid, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      chrome: Color.lerp(chrome, other.chrome, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AcidPalette &&
      other.acid == acid &&
      other.onAcid == onAcid &&
      other.bg == bg &&
      other.panel == panel &&
      other.text == text &&
      other.textMuted == textMuted &&
      other.chrome == chrome &&
      other.danger == danger;

  @override
  int get hashCode =>
      Object.hash(acid, onAcid, bg, panel, text, textMuted, chrome, danger);
}

/// 系统强调色（0xAARRGGBB）。非 Windows / 读取失败返回 null。
Color? systemAccentColor({WindowsAppearanceReader? reader}) {
  final r = reader ?? defaultAppearanceReader();
  final value = r.readAccentColorValue();
  if (value == null) return null;
  return Color(value);
}

/// Fluent 生产主题：Fluent UI 控件 + Windows 11 色板 + 系统强调色。
fluent.FluentThemeData buildFluentTheme(
  Brightness brightness, {
  Iterable<ThemeExtension<dynamic>> extraExtensions = const [],
  Color? accent,
  WindowsAppearanceReader? appearanceReader,
}) {
  final resolvedAccent =
      accent ??
      systemAccentColor(reader: appearanceReader) ??
      (brightness == Brightness.dark ? AcidPalette.dark.acid : AcidPalette.light.acid);
  final palette = AcidPalette.withAccent(brightness, resolvedAccent);
  final accentSwatch = fluent.AccentColor.swatch({
    'darkest': Color.lerp(resolvedAccent, Colors.black, 0.28)!,
    'darker': Color.lerp(resolvedAccent, Colors.black, 0.18)!,
    'dark': Color.lerp(resolvedAccent, Colors.black, 0.08)!,
    'normal': resolvedAccent,
    'light': Color.lerp(resolvedAccent, Colors.white, 0.08)!,
    'lighter': Color.lerp(resolvedAccent, Colors.white, 0.18)!,
    'lightest': Color.lerp(resolvedAccent, Colors.white, 0.28)!,
  });
  final typography = fluent.Typography.fromBrightness(
    brightness: brightness,
    color: palette.text,
  );
  final uiTypography = fluent.Typography.raw(
    display: _withFont(
      typography.display,
      family: kFontDisplay,
      fallbacks: kFontFallbacks,
    ),
    titleLarge: _withFont(
      typography.titleLarge,
      family: kFontDisplay,
      fallbacks: kFontFallbacks,
    ),
    title: _withFont(
      typography.title,
      family: kFontDisplay,
      fallbacks: kFontFallbacks,
    ),
    subtitle: _withFont(
      typography.subtitle,
      family: kFontDisplay,
      fallbacks: kFontFallbacks,
    ),
    bodyLarge: _withFont(
      typography.bodyLarge,
      family: kFontUi,
      fallbacks: kFontFallbacks,
    ),
    bodyStrong: _withFont(
      typography.bodyStrong,
      family: kFontUi,
      fallbacks: kFontFallbacks,
    ),
    body: _withFont(
      typography.body,
      family: kFontUi,
      fallbacks: kFontFallbacks,
    ),
    caption: _withFont(
      typography.caption,
      family: kFontUi,
      fallbacks: kFontFallbacks,
    ),
  );
  final extensions = <ThemeExtension<dynamic>>[
    palette,
    brightness == Brightness.dark ? DiffColors.dark : DiffColors.light,
  ];
  for (final extension in extraExtensions) {
    extensions.add(extension as dynamic);
  }
  return fluent.FluentThemeData(
    brightness: brightness,
    accentColor: accentSwatch,
    typography: uiTypography,
    scaffoldBackgroundColor: palette.bg,
    micaBackgroundColor: palette.bg,
    // Acrylic 默认更透一点，侧栏/标题栏叠出 Win11 毛玻璃层次。
    acrylicBackgroundColor: palette.panel.withValues(alpha: 0.82),
    cardColor: palette.panel,
    activeColor: palette.text,
    inactiveColor: palette.textMuted,
    selectionColor: palette.acid.withValues(alpha: 0.36),
    extensions: extensions,
    dividerTheme: fluent.DividerThemeData(
      decoration: BoxDecoration(color: palette.chrome),
    ),
    infoBarTheme: const fluent.InfoBarThemeData(
      padding: EdgeInsetsDirectional.all(12),
    ),
  );
}

/// 让独立 widget 测试和嵌入场景也能使用 Fluent 控件；生产入口由
/// [FluentApp] 提供主题时不会重复包裹。
class FluentThemeFallback extends StatelessWidget {
  final Widget child;

  const FluentThemeFallback({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themedChild = fluent.FluentTheme.maybeOf(context) != null
        ? child
        : fluent.FluentTheme(
            data: buildFluentTheme(
              Brightness.dark,
              extraExtensions:
                  context
                      .findAncestorWidgetOfExactType<Theme>()
                      ?.data
                      .extensions
                      .values ??
                  const [],
              // 测试宿主无系统注册表：用默认 Win11 蓝，避免读宿主环境。
              appearanceReader: NullAppearanceReader(),
            ),
            child: child,
          );
    return Localizations.override(
      context: context,
      locale: Localizations.localeOf(context),
      delegates: const [
        AppLocalizations.delegate,
        fluent.FluentLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      child: themedChild,
    );
  }
}

/// Material 主题构建（旧纯主题单测 / 第三方依赖），色值同 Win11 色板。
ThemeData buildAcidTheme(Brightness brightness) {
  final p = brightness == Brightness.dark
      ? AcidPalette.dark
      : AcidPalette.light;
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: p.acid, brightness: brightness)
      .copyWith(
        primary: p.acid,
        onPrimary: p.onAcid,
        primaryContainer: p.acid,
        onPrimaryContainer: p.onAcid,
        secondary: p.chrome,
        onSecondary: p.onAcid,
        surface: p.bg,
        onSurface: p.text,
        onSurfaceVariant: p.textMuted,
        surfaceContainerLowest: p.bg,
        surfaceContainerLow: p.bg,
        surfaceContainer: p.panel,
        surfaceContainerHigh: p.panel,
        surfaceContainerHighest: p.panel,
        surfaceTint: Colors.transparent,
        error: p.danger,
        onError: isDark ? const Color(0xFF1A1A1A) : p.onAcid,
        outline: isDark ? p.chrome : p.textMuted.withValues(alpha: 0.4),
        outlineVariant: p.chrome,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    primaryColor: p.acid,
    cardColor: p.panel,
    dividerColor: p.chrome,
    fontFamily: kFontUi,
    fontFamilyFallback: kFontFallbacks,
    extensions: [
      p,
      brightness == Brightness.dark ? DiffColors.dark : DiffColors.light,
    ],
  );
}
