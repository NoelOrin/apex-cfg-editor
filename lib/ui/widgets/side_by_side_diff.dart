import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/diff/line_diff.dart';
import '../../state/diff_bloc.dart';
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
          return Container(
            color: Theme.of(context).colorScheme.surface,
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
          return Container(
            color: Theme.of(context).colorScheme.surface,
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
