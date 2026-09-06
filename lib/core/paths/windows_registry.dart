import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

import 'install_locator.dart';

export 'install_locator.dart' show RegistryReader, RegistryView, DriveLister;

/// 生产注册表读取（win32_registry 封装，底层即 win32 FFI）。所有失败
/// （键不存在、权限不足、非字符串值）自吞为 null / 空列表：探测是尽力
/// 而为，注册表不可读不应让应用崩溃。
final class Win32RegistryReader implements RegistryReader {
  @override
  String? readString(RegistryView view, String keyPath, String valueName) {
    try {
      final base = view == RegistryView.user ? CURRENT_USER : LOCAL_MACHINE;
      final key = base.open(keyPath);
      try {
        return key.getString(valueName);
      } finally {
        key.close();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  List<String> subKeys(RegistryView view, String keyPath) {
    try {
      final base = view == RegistryView.user ? CURRENT_USER : LOCAL_MACHINE;
      final key = base.open(keyPath);
      try {
        return List<String>.of(key.keys);
      } finally {
        key.close();
      }
    } catch (_) {
      return const [];
    }
  }
}

/// 非 Windows 平台的空实现：注册表读取一律落空，探测自然退化为
/// 文件系统候选（macOS 开发期 / 测试环境安全，绝不触碰真实系统）。
final class NullRegistryReader implements RegistryReader {
  @override
  String? readString(RegistryView view, String keyPath, String valueName) =>
      null;

  @override
  List<String> subKeys(RegistryView view, String keyPath) => const [];
}

/// 平台工厂：Windows 走真实注册表，其余平台走空实现。
/// [isWindows] 仅测试注入；生产用 [Platform.isWindows]。
RegistryReader defaultRegistryReader({bool? isWindows}) =>
    (isWindows ?? Platform.isWindows)
    ? Win32RegistryReader()
    : NullRegistryReader();

/// EA App 常见根目录的盘符枚举（C-F，规格约定；EA 默认装 C 盘，
/// 自定义库常见 D-F）。真实盘符枚举无跨平台必要——候选根逐个
/// existsSync 探测，不存在的盘自然落空。
const fixedDriveLister = _FixedDriveLister();

final class _FixedDriveLister implements DriveLister {
  const _FixedDriveLister();

  @override
  List<String> driveLetters() => const ['C', 'D', 'E', 'F'];
}
