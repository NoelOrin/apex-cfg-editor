import 'package:flutter/material.dart';

/// diff 红绿高亮（删除背景 / 新增背景）。
///
/// 以 `ThemeExtension<DiffColors>` 形式注入；语义对齐 Windows 11
/// SystemFillColorCritical（删）/ SystemFillColorSuccess（增）的半透明叠加。
@immutable
class DiffColors extends ThemeExtension<DiffColors> {
  /// 删除行背景（左栏，modified / removed）。
  final Color deleteBg;

  /// 新增行背景（右栏，modified / added）。
  final Color addBg;

  const DiffColors({required this.deleteBg, required this.addBg});

  /// 浅色主题值。
  static const light = DiffColors(
    deleteBg: Color(0x33C42B1C),
    addBg: Color(0x330F7B0F),
  );

  /// 深色主题值（默认主题，生产走这套）。
  static const dark = DiffColors(
    deleteBg: Color(0x40FF99A4),
    addBg: Color(0x406CCB5F),
  );

  @override
  DiffColors copyWith({Color? deleteBg, Color? addBg}) => DiffColors(
    deleteBg: deleteBg ?? this.deleteBg,
    addBg: addBg ?? this.addBg,
  );

  @override
  DiffColors lerp(covariant DiffColors? other, double t) {
    if (other == null) return this;
    return DiffColors(
      deleteBg: Color.lerp(deleteBg, other.deleteBg, t)!,
      addBg: Color.lerp(addBg, other.addBg, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiffColors && other.deleteBg == deleteBg && other.addBg == addBg;

  @override
  int get hashCode => Object.hash(deleteBg, addBg);
}
