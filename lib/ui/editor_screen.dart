import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state/diff_bloc.dart';
import '../state/edit_bloc.dart';
import '../state/file_bloc.dart';
import 'widgets/kb_card.dart';
import 'widgets/kv_table_view.dart';
import 'widgets/side_by_side_diff.dart';
import 'widgets/text_editor_view.dart';

/// 主界面三区布局：顶栏（文件名/模式切换/保存/还原）+
/// 编辑区（flex 6）+ 底部区（高 220，内含知识卡 280 宽 + 行级 diff）。
/// 三个 bloc 均由外部注入（测试接缝）。
class EditorScreen extends StatefulWidget {
  final EditBloc editBloc;
  final DiffBloc diffBloc;
  final FileBloc fileBloc;

  const EditorScreen({
    super.key,
    required this.editBloc,
    required this.diffBloc,
    required this.fileBloc,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool _textMode = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<FileBloc, FileState>(
          bloc: widget.fileBloc,
          // 无文件时回退到应用标题；有文件时只显示文件名。
          builder: (_, s) => Text(
            s.path?.split('/').last.split('\\').last ?? l.appTitle,
          ),
        ),
        actions: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(LucideIcons.table2),
                label: Text(l.modeTable),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(LucideIcons.code2),
                label: Text(l.modeText),
              ),
            ],
            selected: {_textMode},
            onSelectionChanged: (v) => setState(() => _textMode = v.first),
          ),
          // IconButton 的 tooltip 同时充当无障碍语义（semanticLabel 不可传）。
          IconButton(
            icon: const Icon(LucideIcons.save),
            tooltip: l.save,
            onPressed: () => widget.fileBloc.add(SaveRequested()),
          ),
          IconButton(
            icon: const Icon(LucideIcons.history),
            tooltip: l.restore,
            // TODO(restore): 还原对话框由后续任务接入。
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: _textMode
                ? TextEditorView(editBloc: widget.editBloc)
                : KvTableView(
                    editBloc: widget.editBloc,
                    fileBloc: widget.fileBloc,
                  ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                const SizedBox(width: 280, child: KbCard()),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SideBySideDiff(diffBloc: widget.diffBloc),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
