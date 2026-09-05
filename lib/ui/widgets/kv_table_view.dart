import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/parser/cfg_document.dart';
import '../../knowledge/kb_service.dart';
import '../../state/edit_bloc.dart';
import '../../state/file_bloc.dart';

/// 键值表格视图：每行 键名（monospace）| 值控件 | KB 简述。
/// KB 命中且带枚举值时用下拉，否则用文本输入；KB 未注入
/// （EditorScreen 尚无 RepositoryProvider，任务 15 装配）时全部退化为
/// 纯文本输入，不依赖知识库也能编辑。
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
  Widget build(BuildContext context) {
    return BlocBuilder<EditBloc, EditState>(
      bloc: editBloc,
      builder: (context, s) {
        final doc = s.doc;
        if (doc == null) {
          return Center(
            child: Text(AppLocalizations.of(context)!.emptyDocHint),
          );
        }
        // 可空读取：无 provider 时返回 null 而不是抛错（provider 对
        // 可变参类型不做 NotFound 断言）。
        final kb = context.read<KbService?>();
        final locale = Localizations.localeOf(context).languageCode;
        return ListView.builder(
          itemCount: doc.lines.length,
          itemBuilder: (context, i) {
            final line = doc.lines[i];
            // sealed CfgLine 穷举：键值行解出 (key, value, kb 域)，
            // 其余（Comment/Blank/Raw）显示原文。
            final kvData = switch (line) {
              KeyValueLine(:final key, :final value) =>
                (key: key, value: value, file: KbFile.videoconfig),
              CvarLine(:final key, :final value) =>
                (key: key, value: value, file: KbFile.autoexec),
              _ => null,
            };
            if (kvData == null) {
              return ListTile(
                dense: true,
                onTap: () => editBloc.add(SelectionChanged(i)),
                selected: s.selectedIndex == i,
                title: Text(
                  line.raw,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              );
            }
            final (:key, :value, :file) = kvData;
            final entry = kb?.lookup(file, key, locale);
            return ListTile(
              dense: true,
              onTap: () => editBloc.add(SelectionChanged(i)),
              selected: s.selectedIndex == i,
              title: Text(
                key,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              subtitle: entry == null
                  ? null
                  : Text(entry.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: SizedBox(
                width: 160,
                child: entry != null &&
                        entry.values.isNotEmpty &&
                        // 当前值必须在枚举内才用下拉，否则 initialValue
                        // 触发 DropdownButtonFormField 的唯一项断言。
                        entry.values.any((v) => v.v == value)
                    ? DropdownButtonFormField<String>(
                        initialValue: value,
                        items: entry.values
                            .map((v) => DropdownMenuItem(
                                value: v.v, child: Text(v.label)))
                            .toList(),
                        onChanged: (v) => editBloc
                            .add(LineValueChanged(index: i, value: v ?? '')),
                      )
                    : TextFormField(
                        // 按行对象做身份 key：initialValue 只在字段初始化时
                        // 生效，行对象不变（就地编辑）时保持字段状态，
                        // 文档整体替换（DocumentOpened/restore）后对象更替、
                        // 字段按新值重建——避免重建后文本与状态错乱。
                        key: ValueKey<CfgLine>(line),
                        initialValue: value,
                        onChanged: (v) =>
                            editBloc.add(LineValueChanged(index: i, value: v)),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
