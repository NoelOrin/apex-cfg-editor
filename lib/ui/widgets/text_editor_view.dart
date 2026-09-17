import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/highlight_core.dart' show Mode;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/parser/autoexec_parser.dart';
import '../../core/parser/settings_parser.dart';
import '../../core/parser/videoconfig_parser.dart';
import '../../l10n/app_localizations.dart';
import '../../state/edit_bloc.dart';
import '../../state/file_bloc.dart';
import '../theme/acid_theme.dart';

/// 全文文本编辑视图：Consolas 等宽字体、稳定底色和 Apex CFG 词法高亮。
/// 命令、注释、字符串和数字使用独立的高对比颜色，避免配置文本难以扫描。
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

final _cfgLanguage = Mode(
  aliases: const ['apexcfg'],
  contains: [
    Mode(className: 'comment', begin: r'//', end: r'$'),
    Mode(className: 'comment', begin: r'/\*', end: r'\*/'),
    Mode(
      className: 'string',
      begin: r'"',
      end: r'"',
      contains: [Mode(begin: r'\\[\s\S]', relevance: 0)],
    ),
    Mode(
      className: 'number',
      begin: r'\b-?(?:\d+(?:\.\d*)?|\.\d+)\b',
      relevance: 0,
    ),
    Mode(
      className: 'command',
      begin: r'^[ \t]*[A-Za-z_][A-Za-z0-9_]*',
      end: r'(?=\s|$)',
      relevance: 0,
    ),
  ],
);

CodeThemeData _buildCfgCodeTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return CodeThemeData(
    styles: {
      'root': TextStyle(
        color: isDark ? const Color(0xFFE8F0E0) : const Color(0xFF1E241A),
        backgroundColor: isDark
            ? const Color(0xFF10130E)
            : const Color(0xFFFCFDF8),
      ),
      'comment': TextStyle(
        color: isDark ? const Color(0xFF82B982) : const Color(0xFF4D7A4B),
        fontStyle: FontStyle.italic,
      ),
      'string': TextStyle(
        color: isDark ? const Color(0xFFF2C56B) : const Color(0xFF9B5A00),
      ),
      'number': TextStyle(
        color: isDark ? const Color(0xFF7EC8E3) : const Color(0xFF007A8A),
      ),
      'keyword': TextStyle(
        color: isDark ? const Color(0xFFDDA0FF) : const Color(0xFF7B2CBF),
        fontWeight: FontWeight.w600,
      ),
      'built_in': TextStyle(
        color: isDark ? const Color(0xFFFF9F68) : const Color(0xFFC2410C),
      ),
      'meta': TextStyle(
        color: isDark ? const Color(0xFF91D5FF) : const Color(0xFF146C94),
      ),
      'function': TextStyle(
        color: isDark ? const Color(0xFFBFFF00) : const Color(0xFF4F6900),
      ),
      'title': TextStyle(
        color: isDark ? const Color(0xFFBFFF00) : const Color(0xFF4F6900),
      ),
      'command': TextStyle(
        color: isDark ? const Color(0xFFBFFF00) : const Color(0xFF4F6900),
        fontWeight: FontWeight.w600,
      ),
    },
  );
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
      language: _cfgLanguage,
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
      final kind = fileBloc?.state.kind ?? CfgKind.videoconfig;
      widget.editBloc.add(
        FullTextChanged(switch (kind) {
          CfgKind.videoconfig => const VideoconfigParser().parse(_ctrl.text),
          CfgKind.settings => const SettingsParser().parse(_ctrl.text),
          CfgKind.autoexec => const AutoexecParser().parse(_ctrl.text),
        }),
      );
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
    _ctrl.selection = TextSelection(
      baseOffset: idx,
      extentOffset: idx + q.length,
    );
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
      _ctrl.selection = TextSelection(
        baseOffset: last,
        extentOffset: last + q.length,
      );
      return;
    }
    _ctrl.selection = TextSelection(
      baseOffset: idx,
      extentOffset: idx + q.length,
    );
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
        bottom: BorderSide(
          color:
              (FluentTheme.maybeOf(context) ??
                      buildFluentTheme(Brightness.dark))
                  .resources
                  .dividerStrokeColorDefault,
        ),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextBox(
            key: const ValueKey('findField'),
            controller: _findCtrl,
            style: const TextStyle(
              fontFamily: kFontMono,
              fontFamilyFallback: kFontMonoFallbacks,
              fontSize: 13,
            ),
            placeholder: l.find,
            onSubmitted: (_) => _findNext(),
          ),
        ),
        Tooltip(
          message: l.findPrev,
          child: IconButton(
            icon: const Icon(LucideIcons.arrowUp),
            onPressed: _findPrev,
          ),
        ),
        Tooltip(
          message: l.findNext,
          child: IconButton(
            icon: const Icon(LucideIcons.arrowDown),
            onPressed: _findNext,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextBox(
            key: const ValueKey('replaceField'),
            controller: _replaceCtrl,
            style: const TextStyle(
              fontFamily: kFontMono,
              fontFamilyFallback: kFontMonoFallbacks,
              fontSize: 13,
            ),
            placeholder: l.replace,
          ),
        ),
        Tooltip(
          message: l.replace,
          child: IconButton(
            icon: const Icon(LucideIcons.replace),
            onPressed: _replaceOne,
          ),
        ),
        Tooltip(
          message: l.replaceAll,
          child: IconButton(
            icon: const Icon(LucideIcons.replaceAll),
            onPressed: _replaceAll,
          ),
        ),
        Tooltip(
          message: l.close,
          child: IconButton(
            icon: const Icon(LucideIcons.x),
            onPressed: () => setState(() => _findOpen = false),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FluentThemeFallback(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _openFind,
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
                  Tooltip(
                    message: l.find,
                    child: IconButton(
                      icon: const Icon(LucideIcons.search),
                      onPressed: _openFind,
                    ),
                  ),
                ],
              ),
            Expanded(
              child: material.Material(
                color: Colors.transparent,
                child: CodeTheme(
                  data: _buildCfgCodeTheme(
                    FluentTheme.maybeOf(context)?.brightness ??
                        material.Theme.of(context).brightness,
                  ),
                  child: CodeField(
                    controller: _ctrl,
                    expands: true,
                    onChanged: (_) => _onChanged(),
                    textStyle: const TextStyle(
                      fontFamily: kFontMono,
                      fontFamilyFallback: kFontMonoFallbacks,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
