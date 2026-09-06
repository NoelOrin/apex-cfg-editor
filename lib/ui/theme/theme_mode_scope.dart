import 'package:flutter/material.dart';

/// themeMode 持久化映射（settings.json 的 `themeMode` 字段，单层 JSON）：
/// 存储/读取均为小写枚举名字符串（'system' / 'light' / 'dark'），
/// 非法值一律返回 null（回退默认暗色）。
ThemeMode? themeModeFromRaw(String? raw) => switch (raw) {
  'system' => ThemeMode.system,
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => null,
};

/// [themeModeFromRaw] 的反向：写入 settings.json 的规范字符串。
String themeModeToRaw(ThemeMode mode) => mode.name;

/// 主题模式作用域：ApexCfgEditorApp 在 MaterialApp 外层注入当前
/// [ThemeMode] 与切换回调，自绘标题栏的亮/暗按钮读取并触发切换。
/// 作用域缺失时（部分测试宿主直接 pump EditorScreen）标题栏隐藏该按钮，
/// 不影响其余功能。
class ThemeModeScope extends InheritedWidget {
  /// 当前主题模式（MaterialApp themeMode 的同源值）。
  final ThemeMode mode;

  /// 切换回调（实现负责持久化到 SettingsStore）。
  final ValueChanged<ThemeMode> onChanged;

  const ThemeModeScope({
    super.key,
    required this.mode,
    required this.onChanged,
    required super.child,
  });

  /// 可空读取：无作用域时返回 null（调用方决定降级形态）。
  static ThemeModeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();

  @override
  bool updateShouldNotify(ThemeModeScope oldWidget) =>
      oldWidget.mode != mode || oldWidget.onChanged != onChanged;
}
