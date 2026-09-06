import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/diff/line_diff.dart';
import '../../state/diff_bloc.dart';
import '../theme/acid_theme.dart';
import '../theme/diff_colors.dart';

const _mono = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  height: 1.3,
);

/// 栏最小宽度：窗口过窄时不再压缩，改为横向滚动。
const _minColumnWidth = 320.0;

/// 行号列宽（容纳 5 位数字），行号缺省时留白等宽对齐。
const _lineNoWidth = 40.0;

/// 并排 diff 视图：左原始（基线）/ 右当前，行级红绿高亮。
///
/// 单 ListView 驱动整行——同一行索引的左右两栏在同一个 Row 内，
/// 天然左右对齐（不使用双 ListView，规避滚动错位）。
/// 长行不软换行（softWrap: false），超出栏宽裁剪，由外层横向
/// SingleChildScrollView 统一驱动两栏滚动查看。
/// 红绿高亮色经 `ThemeExtension<DiffColors>` 注入（main.dart 注册 light/dark
/// 值），主题未注册时回退 dark 值。
class SideBySideDiff extends StatelessWidget {
  final DiffBloc diffBloc;

  const SideBySideDiff({super.key, required this.diffBloc});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiffBloc, DiffState>(
      bloc: diffBloc,
      builder: (context, state) {
        if (state.rows.isEmpty) {
          return _gridTexture(
            context,
            child: Center(
              child: Text(AppLocalizations.of(context)!.noChanges),
            ),
          );
        }
        return LayoutBuilder(builder: (context, constraints) {
          final half = constraints.maxWidth / 2;
          final columnWidth =
              half < _minColumnWidth ? _minColumnWidth : half;
          final diffColors =
              Theme.of(context).extension<DiffColors>() ?? DiffColors.dark;
          return _gridTexture(
            context,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: columnWidth * 2,
                child: ListView.builder(
                  itemCount: state.rows.length,
                  itemBuilder: (context, i) {
                    final r = state.rows[i];
                    final deleteColor =
                        r.type == RowType.modified || r.type == RowType.removed
                            ? diffColors.deleteBg
                            : null;
                    final addColor =
                        r.type == RowType.modified || r.type == RowType.added
                            ? diffColors.addBg
                            : null;
                    // IntrinsicHeight + stretch：removed 行右栏空、added 行
                    // 左栏空仍与配对行等高，保证双栏行号逐行对齐。
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _Cell(
                              text: r.left ?? '',
                              lineNo: r.leftNo,
                              background: deleteColor,
                            ),
                          ),
                          Expanded(
                            child: _Cell(
                              text: r.right ?? '',
                              lineNo: r.rightNo,
                              background: addColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

/// diff 面板底纹：极淡的方格纹理（酸绿 3% 透明度 < 4% 上限，克制）。
/// [child] 铺在纹理之上。
Widget _gridTexture(BuildContext context, {required Widget child}) {
  final acid = AcidPalette.of(context).acid.withValues(alpha: 0.03);
  return Container(
    color: Theme.of(context).colorScheme.surface,
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _GridPainter(color: acid)),
        ),
        child,
      ],
    ),
  );
}

/// 方格纹理画笔：24px 网格，1px 线宽，颜色由 [_gridTexture] 给定。
class _GridPainter extends CustomPainter {
  final Color color;

  const _GridPainter({required this.color});

  static const _cell = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += _cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += _cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.color != color;
}

class _Cell extends StatelessWidget {
  final String text;
  final int? lineNo;
  final Color? background;

  const _Cell({
    required this.text,
    required this.lineNo,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final numberStyle = _mono.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: _lineNoWidth,
            child: Text(
              lineNo?.toString() ?? '',
              style: numberStyle,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: _mono,
              softWrap: false,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}
