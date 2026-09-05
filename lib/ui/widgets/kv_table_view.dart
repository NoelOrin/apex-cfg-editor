import 'package:flutter/material.dart';

import '../../state/edit_bloc.dart';
import '../../state/file_bloc.dart';

/// 键值表格视图占位：真实实现由后续任务填充。
/// 构造签名（editBloc + fileBloc）是任务 10 确定的接线，保持稳定。
class KvTableView extends StatelessWidget {
  final EditBloc editBloc;
  final FileBloc fileBloc;

  const KvTableView({
    super.key,
    required this.editBloc,
    required this.fileBloc,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
