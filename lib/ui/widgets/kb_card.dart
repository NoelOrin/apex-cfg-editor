import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/parser/cfg_document.dart';
import '../../knowledge/kb_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/edit_bloc.dart';
import '../../state/file_bloc.dart';
import '../theme/acid_theme.dart';
import 'kv_table_view.dart';

/// 选中键的 Fluent 知识说明面板。
///
/// [editBloc] 为显式接线；未传入时兼容旧宿主的 context provider 模式。
/// [showEmptyState] 用于工作台面板：无选中项或未收录时给出稳定提示，而不是
/// 留下整块空白。
/// 传入 [fileBloc] 时按文件类型选择对应知识库域（settings.cfg 用操作设置域），
/// 不传则回退按行类型判断（兼容旧宿主）。
class KbCard extends StatelessWidget {
  final EditBloc? editBloc;
  final bool showEmptyState;

  /// 可选的文件 Bloc。传入时按文件类型（settings.cfg / videoconfig /
  /// autoexec）选择对应知识库域；为 null 时回退按行类型判断（兼容旧宿主）。
  final FileBloc? fileBloc;

  const KbCard({
    super.key,
    this.editBloc,
    this.fileBloc,
    this.showEmptyState = false,
  });

  @override
  Widget build(BuildContext context) {
    final edit = editBloc ?? context.read<EditBloc?>();
    if (edit == null) return const SizedBox.shrink();
    return FluentThemeFallback(
      child: BlocBuilder<EditBloc, EditState>(
        bloc: edit,
        builder: (context, s) {
          final l = AppLocalizations.of(context)!;
          final doc = s.doc;
          if (doc == null) {
            return showEmptyState
                ? _emptyState(context, l.kbSelectKeyHint)
                : const SizedBox.shrink();
          }

          final i = s.selectedIndex;
          if (i == null || i < 0 || i >= doc.lines.length) {
            return showEmptyState
                ? _emptyState(context, l.kbSelectKeyHint)
                : const SizedBox.shrink();
          }

          // 优先按 FileBloc 的文件类型选域（settings.cfg 与 autoexec 同名键会
          // 互相覆盖）；无 FileBloc 时回退旧行类型逻辑。
          final file = fileBloc != null
              ? kbFileForKind(fileBloc!.state.kind)
              : switch (doc.lines[i]) {
                  KeyValueLine() => KbFile.videoconfig,
                  CvarLine() => KbFile.autoexec,
                  _ => KbFile.autoexec,
                };
          final kv = switch (doc.lines[i]) {
            KeyValueLine(:final key) => (key: key, file: file),
            CvarLine(:final key) => (key: key, file: file),
            _ => null,
          };
          if (kv == null) {
            return showEmptyState
                ? _emptyState(context, l.kbSelectKeyHint)
                : const SizedBox.shrink();
          }

          final kb = context.read<KbService?>();
          if (kb == null) return const SizedBox.shrink();
          final entry = kb.lookup(
            kv.file,
            kv.key,
            Localizations.localeOf(context).languageCode,
          );
          if (entry == null || entry.description.trim().isEmpty) {
            return showEmptyState
                ? _emptyState(context, l.kbNotDocumented)
                : const SizedBox.shrink();
          }

          final high = entry.risk == 'high';
          final warned = high || entry.risk == 'medium';
          final palette = AcidPalette.of(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (warned) ...[
                      Icon(
                        LucideIcons.alertTriangle,
                        size: 16,
                        color: high ? palette.danger : palette.textMuted,
                        semanticLabel: high ? l.riskHigh : l.risk,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        entry.name,
                        style: FluentTheme.of(context).typography.subtitle
                            ?.copyWith(color: high ? palette.danger : null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(entry.description),
                if (entry.recommended.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.kbRecommended(entry.recommended),
                    style: TextStyle(color: palette.textMuted),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context, String message) {
    final palette = AcidPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, height: 1.5),
        ),
      ),
    );
  }
}
