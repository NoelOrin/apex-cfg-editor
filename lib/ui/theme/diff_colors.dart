import 'package:flutter/material.dart';

/// diff 红绿高亮（删除背景 / 新增背景）。
///
/// 以 `ThemeExtension<DiffColors>` 形式注入，SideBySideDiff 只从
/// `Theme.of(context).extension<DiffColors>()` 读取，明暗两套值在
/// acid_theme.dart 的主题里注册；主题未注册时（如部分测试宿主）由
/// 组件回退到 [DiffColors.dark]。
///
/// 酸性语义（v2）：删除行 = 酸性橙红（与警示橙 #FF7A00 同族）、
/// 新增行 = 酸性绿（#AEEF00 / #BFFF00），删除/新增语义保持分明；
/// 两者均为 20% 透明叠加（0x33）。
@immutable
class DiffColors extends ThemeExtension<DiffColors> {
  /// 删除行背景（左栏，modified / removed）。
  final Color deleteBg;

  /// 新增行背景（右栏，modified / added）。
  final Color addBg;

  const DiffColors({required this.deleteBg, required this.addBg});

  /// 浅色主题值：纸白 surface 上可读的淡橙 / 淡酸绿。
  static const light = DiffColors(
    deleteBg: Color(0x33FF7A00),
    addBg: Color(0x33BFFF00),
  );

  /// 深色主题值（默认主题，生产走这套）：近黑 surface 上的暗橙 / 暗酸绿。
  static const dark = DiffColors(
    deleteBg: Color(0x40FF4D00),
    addBg: Color(0x40AEEF00),
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
