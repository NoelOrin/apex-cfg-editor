import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/parser/cfg_document.dart';
import '../../knowledge/kb_service.dart';
import '../../state/edit_bloc.dart';

/// 知识卡：底部 280 宽区域，展示当前选中键的名称/作用/推荐值/风险警示。
/// 构造签名（无参 const）是任务 10 确定的接线，保持稳定。
///
/// EditBloc 与 KbService 都走可空读取（任务 11 先例：provider 对可空类型
/// 不做 NotFound 断言）——EditorScreen 尚无 provider 装配（任务 15 接入），
/// 任一缺失时整卡隐藏，不依赖知识库也能正常编辑。
class KbCard extends StatelessWidget {
  const KbCard({super.key});

  @override
  Widget build(BuildContext context) {
    final edit = context.read<EditBloc?>();
    if (edit == null) return const SizedBox.shrink();
    return BlocBuilder<EditBloc, EditState>(
      bloc: edit,
      builder: (context, s) {
        final doc = s.doc;
        final i = s.selectedIndex;
        if (doc == null ||
            i == null ||
            i < 0 ||
            i >= doc.lines.length) {
          return const SizedBox.shrink();
        }
        // sealed CfgLine 穷举：键值行解出 (key, KB 域)；
        // 注释/空行/raw 无键 → 卡片隐藏。
        final kv = switch (doc.lines[i]) {
          KeyValueLine(:final key) => (key: key, file: KbFile.videoconfig),
          CvarLine(:final key) => (key: key, file: KbFile.autoexec),
          _ => null,
        };
        if (kv == null) return const SizedBox.shrink();
        final kb = context.read<KbService?>();
        if (kb == null) return const SizedBox.shrink();
        final e = kb.lookup(
            kv.file, kv.key, Localizations.localeOf(context).languageCode);
        final l = AppLocalizations.of(context)!;
        if (e == null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Text(l.kbNotDocumented),
          );
        }
        // 风险呈现：high → 红色警示图标 + 标题红；medium → 中性色图标；
        // low → 不额外标注。颜色一律取自 Theme。
        final high = e.risk == 'high';
        final warned = high || e.risk == 'medium';
        final scheme = Theme.of(context).colorScheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (warned) ...[
                  Icon(LucideIcons.alertTriangle,
                      size: 16,
                      color: high ? scheme.error : scheme.onSurfaceVariant,
                      // 辅助文案（screen reader）同样走 i18n（任务 16 审计收尾）。
                      semanticLabel: high ? l.riskHigh : l.risk),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    e.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: high ? scheme.error : null),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(e.description),
              if (e.recommended.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l.kbRecommended(e.recommended),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
