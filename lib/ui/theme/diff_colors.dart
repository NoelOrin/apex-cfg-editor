import 'package:flutter/material.dart';

/// diff 红绿高亮（删除背景 / 新增背景）。
///
/// 任务 16 起不再硬编码：以 `ThemeExtension<DiffColors>` 形式注入，
/// SideBySideDiff 只从 `Theme.of(context).extension<DiffColors>()` 读取，
/// 明暗两套值在 main.dart 的主题里注册（值本身维持审定的 Apex 红 /
/// 新增绿 20% 透明叠加）；主题未注册时（如部分测试宿主）由组件回退到
/// [DiffColors.dark]。
@immutable
class DiffColors extends ThemeExtension<DiffColors> {
  /// 删除行背景（左栏，modified / removed）。
  final Color deleteBg;

  /// 新增行背景（右栏，modified / added）。
  final Color addBg;

  const DiffColors({required this.deleteBg, required this.addBg});

  /// 浅色主题值：与深色相同的半透明叠加，浅色 surface 上同为可读的淡红/淡绿。
  static const light = DiffColors(
    deleteBg: Color(0x33E2483D),
    addBg: Color(0x3322C55E),
  );

  /// 深色主题值（应用固定深色主题，生产走这套）。
  static const dark = DiffColors(
    deleteBg: Color(0x33E2483D),
    addBg: Color(0x3322C55E),
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
