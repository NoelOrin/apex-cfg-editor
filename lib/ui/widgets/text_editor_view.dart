import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/cpp.dart' show cpp;

import '../../core/parser/autoexec_parser.dart';
import '../../core/parser/videoconfig_parser.dart';
import '../../state/edit_bloc.dart';
import '../../state/file_bloc.dart';

/// 全文文本编辑视图：monospace、深色底（flutter_code_editor 默认样式
/// 即 grey.shade900 底 + 浅色字）、cpp 语法近似高亮（cfg 命令形似 C 风格）。
///
/// 输入 300ms 防抖后按文件类型全文重解析进 EditBloc，与表格模式共享
/// 同一数据源（kind 来自可空读取的 FileBloc，null 时按 videoconfig）。
///
/// 控制器只在进入本视图时以 Bloc 当前内容初始化一次，**不随 Bloc 状态
/// 反向同步**：本视图防抖产出的 FullTextChanged 会原样回放当前文本，
/// 若再反向同步会造成光标/输入抖动甚至覆盖未提交编辑；代价是文本模式下
/// 外部 Bloc 变更（如还原）不回显，重新切换模式即可取到最新内容。
/// EditorScreen 在模式切换时重建本视图，initState 即「进入文本模式」
/// 时机。构造签名（editBloc）是任务 10 确定的接线，保持稳定。
class TextEditorView extends StatefulWidget {
  final EditBloc editBloc;

  const TextEditorView({super.key, required this.editBloc});

  @override
  State<TextEditorView> createState() => _TextEditorViewState();
}

class _TextEditorViewState extends State<TextEditorView> {
  late final CodeController _ctrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = CodeController(
      text: widget.editBloc.state.doc?.serialize() ?? '',
      language: cpp,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      // 可空读取：EditorScreen 无 provider（任务 10 接线），null 不抛错；
      // provider 存在但 kind 未定时也按 videoconfig 处理。
      final fileBloc = context.read<FileBloc?>();
      final isAutoexec = fileBloc?.state.kind == CfgKind.autoexec;
      widget.editBloc.add(FullTextChanged(
        isAutoexec
            ? const AutoexecParser().parse(_ctrl.text)
            : const VideoconfigParser().parse(_ctrl.text),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return CodeField(
      controller: _ctrl,
      onChanged: (_) => _onChanged(),
      textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
    );
  }
}
