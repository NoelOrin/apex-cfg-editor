import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/cpp.dart' show cpp;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/parser/autoexec_parser.dart';
import '../../core/parser/videoconfig_parser.dart';
import '../../l10n/app_localizations.dart';
import '../../state/edit_bloc.dart';
import '../../state/file_bloc.dart';

/// 全文文本编辑视图：monospace、深色底（flutter_code_editor 默认样式
/// 即 grey.shade900 底 + 浅色字）、cpp 语法近似高亮（cfg 命令形似 C 风格）。
///
/// 输入 300ms 防抖后按文件类型全文重解析进 EditBloc，与表格模式共享
/// 同一数据源（kind 来自可空读取的 FileBloc，null 时按 videoconfig）。
///
/// 查找替换栏（规格 R4）：顶部切换按钮或 Ctrl+F/Cmd+F 唤出，基于
/// CodeController 的 TextEditingValue 操作——下一个/上一个移动选区
/// 定位（首尾回卷），替换/全部替换改写文本。不做高亮所有匹配。程序化
/// 改写不触发 CodeField.onChanged，替换后手动走同一防抖链路。
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
  bool _findOpen = false;
  final _findCtrl = TextEditingController();
  final _replaceCtrl = TextEditingController();

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
    _findCtrl.dispose();
    _replaceCtrl.dispose();
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

  /// 下一个匹配：从选区尾开始找，未命中回卷到开头。
  void _findNext() {
    final text = _ctrl.text;
    final q = _findCtrl.text;
    if (q.isEmpty) return;
    var from = _ctrl.selection.end;
    if (from < 0 || from > text.length) from = 0;
    var idx = text.indexOf(q, from);
    if (idx < 0) idx = text.indexOf(q, 0);
    if (idx < 0) return;
    _ctrl.selection =
        TextSelection(baseOffset: idx, extentOffset: idx + q.length);
  }

  /// 上一个匹配：选区头之前最近的一个，未命中回卷到末尾。
  void _findPrev() {
    final text = _ctrl.text;
    final q = _findCtrl.text;
    if (q.isEmpty) return;
    var start = _ctrl.selection.start;
    if (start < 0 || start > text.length) start = text.length;
    final idx = start > 0 ? text.lastIndexOf(q, start - 1) : -1;
    if (idx < 0) {
      final last = text.lastIndexOf(q);
      if (last < 0) return;
      _ctrl.selection =
          TextSelection(baseOffset: last, extentOffset: last + q.length);
      return;
    }
    _ctrl.selection =
        TextSelection(baseOffset: idx, extentOffset: idx + q.length);
  }

  /// 替换当前选区（仅当选区恰好是完整匹配），然后定位下一个匹配。
  void _replaceOne() {
    final text = _ctrl.text;
    final q = _findCtrl.text;
    if (q.isEmpty) return;
    final sel = _ctrl.selection;
    if (sel.start < 0 || sel.end > text.length || sel.end < sel.start) return;
    if (text.substring(sel.start, sel.end) != q) {
      _findNext(); // 当前选区不是匹配：先定位再等下一次替换
      return;
    }
    final r = _replaceCtrl.text;
    _ctrl.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, r),
      selection: TextSelection.collapsed(offset: sel.start + r.length),
    );
    _onChanged(); // 程序化改写不触发 CodeField.onChanged
    _findNext();
  }

  /// 全部替换（大小写敏感的精确匹配）。
  void _replaceAll() {
    final text = _ctrl.text;
    final q = _findCtrl.text;
    if (q.isEmpty || !text.contains(q)) return;
    _ctrl.value = TextEditingValue(
      text: text.replaceAll(q, _replaceCtrl.text),
      selection: TextSelection.collapsed(offset: 0),
    );
    _onChanged();
  }

  void _openFind() => setState(() => _findOpen = true);

  /// 查找替换栏：查找框（回车=下一个）+ 上一个/下一个 + 替换框 +
  /// 替换/全部替换 + 关闭。
  Widget _findBar(AppLocalizations l) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('findField'),
                controller: _findCtrl,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: l.find,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _findNext(),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.arrowUp),
              tooltip: l.findPrev,
              onPressed: _findPrev,
            ),
            IconButton(
              icon: const Icon(LucideIcons.arrowDown),
              tooltip: l.findNext,
              onPressed: _findNext,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('replaceField'),
                controller: _replaceCtrl,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: l.replace,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.replace),
              tooltip: l.replace,
              onPressed: _replaceOne,
            ),
            IconButton(
              icon: const Icon(LucideIcons.replaceAll),
              tooltip: l.replaceAll,
              onPressed: _replaceAll,
            ),
            IconButton(
              icon: const Icon(LucideIcons.x),
              tooltip: l.close,
              onPressed: () => setState(() => _findOpen = false),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _openFind,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _openFind,
      },
      child: Column(
        children: [
          if (_findOpen)
            _findBar(l)
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.search),
                  tooltip: l.find,
                  onPressed: _openFind,
                ),
              ],
            ),
          Expanded(
            child: CodeField(
              controller: _ctrl,
              onChanged: (_) => _onChanged(),
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
