import 'package:flutter/material.dart';

import 'diff_colors.dart';

/// 展示字体（Chakra Petch，SIL OFL 1.1，见 assets/fonts/OFL.txt）。
/// 标题 / 顶栏 / 大数字使用；中文经 [kFontFallbacks] 回退系统字体，
/// 不影响中文正文渲染。
const String kFontDisplay = 'ChakraPetch';

/// cfg 内容区维持 monospace（表格 / diff / 文本编辑器已按需指定）。
const String kFontMono = 'monospace';

/// 中文字体回退链：Per-glyph 回退，拉丁字形命中 ChakraPetch，
/// 中文落到系统字体（macOS 苹方 / Windows 雅黑 / Linux Noto），最后 monospace。
const List<String> kFontFallbacks = [
  'PingFang SC',
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'Noto Sans SC',
  'Menlo',
  'Consolas',
  'monospace',
];

/// 酸性风格色板（ThemeExtension）：全应用颜色集中于此与 [DiffColors]，
/// 组件一律经 `Theme.of(context).extension<AcidPalette>()` 取色，
/// 禁止散落硬编码。
///
/// 色板（docs/ui-style-guide.md「酸性风格 v2」）：
/// - 主色酸性绿 #BFFF00（暗色下 #AEEF00 保证对比）
/// - 暗色：近黑底 #0A0B08、面板 #121410、文字 #E8F0E0
/// - 亮色：纸白底 #F4F6F0、文字 #0C0E08
/// - 点缀铬银 #C8CCD4；风险/警示酸性橙 #FF7A00
@immutable
class AcidPalette extends ThemeExtension<AcidPalette> {
  /// 主色：酸性绿。
  final Color acid;

  /// 酸绿之上的文字（近黑，双主题一致的高对比反白）。
  final Color onAcid;

  /// 窗口底色（暗=近黑 / 亮=纸白）。
  final Color bg;

  /// 面板底色（顶栏、卡片、对话框浮层）。
  final Color panel;

  /// 主文字色。
  final Color text;

  /// 次级文字色（辅助说明、行号、文件名）。
  final Color textMuted;

  /// 铬银点缀（分隔、描边细节）。
  final Color chrome;

  /// 风险/警示酸性橙（替换原 errorColor 语义，kb 卡片高风险、diff 删除行）。
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

  /// 暗色主题值（默认主题：近黑底 + 酸绿 #AEEF00）。
  static const dark = AcidPalette(
    acid: Color(0xFFAEEF00),
    onAcid: Color(0xFF0A0B08),
    bg: Color(0xFF0A0B08),
    panel: Color(0xFF121410),
    text: Color(0xFFE8F0E0),
    textMuted: Color(0xFF8A9484),
    chrome: Color(0xFFC8CCD4),
    danger: Color(0xFFFF7A00),
  );

  /// 亮色主题值（纸白底 + 酸绿 #BFFF00）。
  static const light = AcidPalette(
    acid: Color(0xFFBFFF00),
    onAcid: Color(0xFF0C0E08),
    bg: Color(0xFFF4F6F0),
    panel: Color(0xFFFCFDF8),
    text: Color(0xFF0C0E08),
    textMuted: Color(0xFF5A6154),
    chrome: Color(0xFFC8CCD4),
    danger: Color(0xFFFF7A00),
  );

  /// 快捷读取：主题未注册色板时（部分测试宿主）回退暗色值。
  static AcidPalette of(BuildContext context) =>
      Theme.of(context).extension<AcidPalette>() ?? dark;

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

/// 酸性风格主题构建：light/dark 两套共用结构，色值取自 [AcidPalette]，
/// 并注册 [AcidPalette] 与 [DiffColors] 两个 ThemeExtension。
/// 全局字体为展示字体 Chakra Petch（中文回退见 [kFontFallbacks]），
/// cfg 内容区由各组件显式指定 monospace。
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
        onError: p.onAcid,
        outline: isDark
            ? p.chrome.withValues(alpha: 0.38)
            : p.chrome.withValues(alpha: 0.55),
        outlineVariant: isDark
            ? p.chrome.withValues(alpha: 0.16)
            : p.chrome.withValues(alpha: 0.30),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: kFontDisplay,
    fontFamilyFallback: kFontFallbacks,
    splashFactory: NoSplash.splashFactory,
    // 酸性风格：选中行酸绿薄涂，焦点不再额外发光。
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    extensions: <ThemeExtension<dynamic>>[
      p,
      brightness == Brightness.dark ? DiffColors.dark : DiffColors.light,
    ],
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      selectedTileColor: p.acid.withValues(alpha: 0.14),
      selectedColor: p.text,
      iconColor: p.textMuted,
      dense: true,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      selectedIcon: const Icon(Icons.check),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.acid,
        foregroundColor: p.onAcid,
        shape: const RoundedRectangleBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.acid,
        side: BorderSide(color: p.acid, width: 1),
        shape: const RoundedRectangleBorder(),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.panel,
      contentTextStyle: TextStyle(color: p.text),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.panel,
      shape: const RoundedRectangleBorder(),
      titleTextStyle: TextStyle(
        fontFamily: kFontDisplay,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: p.text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: p.acid, width: 1.5),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.panel,
        border: Border.all(color: scheme.outline),
      ),
      textStyle: TextStyle(color: p.text, fontSize: 12),
    ),
  );
}
