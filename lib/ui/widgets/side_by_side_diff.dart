import 'package:flutter/material.dart';

import '../../state/diff_bloc.dart';

/// 并排 diff 视图占位：真实实现由后续任务填充。
/// 构造签名（diffBloc）是任务 10 确定的接线，保持稳定。
class SideBySideDiff extends StatelessWidget {
  final DiffBloc diffBloc;

  const SideBySideDiff({super.key, required this.diffBloc});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
