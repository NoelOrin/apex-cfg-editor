import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// Windows 个性化设置（强调色 / 明暗）只读探测。失败一律回退 null，
/// 调用方使用 Fluent 默认强调色与系统 brightness。
abstract class WindowsAppearanceReader {
  /// 系统强调色（0xAARRGGBB 的 Flutter Color.value）。失败返回 null。
  int? readAccentColorValue();

  /// true=浅色 false=深色；读不到返回 null（跟随平台 brightness）。
  bool? readAppsUseLightTheme();
}

final class Win32AppearanceReader implements WindowsAppearanceReader {
  @override
  int? readAccentColorValue() {
    try {
      final key = CURRENT_USER.open(r'Software\Microsoft\Windows\DWM');
      try {
        // AccentColor 为 DWORD，字节序 ABGR → 转 ARGB。
        final abgr = key.getInt('AccentColor');
        if (abgr == null) return null;
        final a = (abgr >> 24) & 0xFF;
        final b = (abgr >> 16) & 0xFF;
        final g = (abgr >> 8) & 0xFF;
        final r = abgr & 0xFF;
        return (a << 24) | (r << 16) | (g << 8) | b;
      } finally {
        key.close();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  bool? readAppsUseLightTheme() {
    try {
      final key = CURRENT_USER.open(
        r'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
      );
      try {
        final v = key.getInt('AppsUseLightTheme');
        if (v == null) return null;
        return v != 0;
      } finally {
        key.close();
      }
    } catch (_) {
      return null;
    }
  }
}

/// 非 Windows 平台空实现：读不到系统外观，回退 Fluent 默认。
final class NullAppearanceReader implements WindowsAppearanceReader {
  @override
  int? readAccentColorValue() => null;

  @override
  bool? readAppsUseLightTheme() => null;
}

/// 平台工厂：Windows 读真实注册表，其余平台空实现。
/// [isWindows] 仅测试注入；生产用 [Platform.isWindows]。
WindowsAppearanceReader defaultAppearanceReader({bool? isWindows}) =>
    (isWindows ?? Platform.isWindows)
    ? Win32AppearanceReader()
    : NullAppearanceReader();
