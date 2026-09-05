import 'package:flutter/material.dart';

import '../../state/edit_bloc.dart';

/// 全文文本编辑视图占位：真实实现由后续任务填充。
/// 构造签名（editBloc）是任务 10 确定的接线，保持稳定。
class TextEditorView extends StatelessWidget {
  final EditBloc editBloc;

  const TextEditorView({super.key, required this.editBloc});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
