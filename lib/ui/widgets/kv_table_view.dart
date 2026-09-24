import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/parser/cfg_document.dart';
import '../../knowledge/kb_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/edit_bloc.dart';
import '../../state/file_bloc.dart';
import '../theme/acid_theme.dart';

/// 把文件类型映射到知识库域（settings.cfg 用操作设置域，videoconfig 用画质域）。
KbFile kbFileForKind(CfgKind? kind) => switch (kind) {
  CfgKind.settings => KbFile.settings,
  CfgKind.videoconfig => KbFile.videoconfig,
  CfgKind.autoexec => KbFile.autoexec,
  null => KbFile.autoexec,
};

/// KV 表格中忽略的键（键位绑定条目数量大且以 bind 指令形式存在，
/// 表格模式不展示；文本模式仍可查看/编辑，文档原行保留）。
const kvHiddenKeys = {'bind_US_standard', 'bind_held_US_standard'};

bool _isHidden(CfgLine line) => switch (line) {
  KeyValueLine(:final key) => kvHiddenKeys.contains(key),
  CvarLine(:final key) => kvHiddenKeys.contains(key),
  _ => false,
};

/// Fluent 键值编辑表格：行结构保持不变，值控件采用 TextBox / ComboBox。
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
    return FluentThemeFallback(
      child: BlocBuilder<EditBloc, EditState>(
        bloc: editBloc,
        builder: (context, s) {
          final doc = s.doc;
          if (doc == null) {
            return Center(
              child: Text(AppLocalizations.of(context)!.emptyDocHint),
            );
          }
          final kb = context.read<KbService?>();
          final locale = Localizations.localeOf(context).languageCode;
          // settings.cfg 中既可能是 KeyValueLine（"key" "value"）也可能是
          // CvarLine（bind_... 等），不能按行类型判断域；统一用 FileBloc
          // 的文件类型映射到对应知识库域。
          final kbFile = kbFileForKind(fileBloc.state.kind);
          // 过滤后的（展示行下标 → 文档真实下标）映射；事件必须用文档下标。
          final visible = <int>[
            for (var i = 0; i < doc.lines.length; i++)
              if (!_isHidden(doc.lines[i])) i,
          ];
          return ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 24),
            itemCount: visible.length,
            itemBuilder: (context, vi) {
              final i = visible[vi];
              final line = doc.lines[i];
              final kvData = switch (line) {
                KeyValueLine(:final key, :final value) => (
                  key: key,
                  value: value,
                  file: kbFile,
                ),
                CvarLine(:final key, :final value) => (
                  key: key,
                  value: value,
                  file: kbFile,
                ),
                _ => null,
              };
              if (kvData == null) {
                return ListTile.selectable(
                  selected: s.selectedIndex == i,
                  onPressed: () => editBloc.add(SelectionChanged(i)),
                  title: Text(
                    line.raw,
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      fontFamily: kFontMono,
                      fontFamilyFallback: kFontMonoFallbacks,
                      color: FluentTheme.of(
                        context,
                      ).resources.textFillColorSecondary,
                    ),
                  ),
                );
              }

              final (:key, :value, :file) = kvData;
              final entry = kb?.lookup(file, key, locale);
              final hasOptions =
                  entry != null &&
                  entry.values.isNotEmpty &&
                  entry.values.any((option) => option.v == value);
              final editor = hasOptions
                  ? ComboBox<String>(
                      key: ValueKey<CfgLine>(line),
                      value: value,
                      isExpanded: true,
                      items: entry.values
                          .map(
                            (option) => ComboBoxItem<String>(
                              value: option.v,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (next) {
                        if (next != null) {
                          editBloc.add(LineValueChanged(index: i, value: next));
                        }
                      },
                    )
                  : TextBox(
                      key: ValueKey<CfgLine>(line),
                      controller: TextEditingController(text: value),
                      onChanged: (next) =>
                          editBloc.add(LineValueChanged(index: i, value: next)),
                    );

              return ListTile.selectable(
                selected: s.selectedIndex == i,
                onPressed: () => editBloc.add(SelectionChanged(i)),
                title: Text(
                  key,
                  style: const TextStyle(
                    fontFamily: kFontMono,
                    fontFamilyFallback: kFontMonoFallbacks,
                  ),
                ),
                subtitle: entry == null || entry.description.trim().isEmpty
                    ? null
                    : Text(entry.description),
                trailing: SizedBox(width: 190, child: editor),
              );
            },
          );
        },
      ),
    );
  }
}
