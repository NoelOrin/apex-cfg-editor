import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/parser/cfg_document.dart';
import '../../knowledge/kb_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/edit_bloc.dart';
import '../theme/acid_theme.dart';

/// 选中键的 Fluent 知识说明面板。
class KbCard extends StatelessWidget {
  const KbCard({super.key});

  @override
  Widget build(BuildContext context) {
    final edit = context.read<EditBloc?>();
    if (edit == null) return const SizedBox.shrink();
    return FluentThemeFallback(
      child: BlocBuilder<EditBloc, EditState>(
        bloc: edit,
        builder: (context, s) {
          final doc = s.doc;
          final i = s.selectedIndex;
          if (doc == null || i == null || i < 0 || i >= doc.lines.length) {
            return const SizedBox.shrink();
          }
          final kv = switch (doc.lines[i]) {
            KeyValueLine(:final key) => (key: key, file: KbFile.videoconfig),
            CvarLine(:final key) => (key: key, file: KbFile.autoexec),
            _ => null,
          };
          if (kv == null) return const SizedBox.shrink();
          final kb = context.read<KbService?>();
          if (kb == null) return const SizedBox.shrink();
          final entry = kb.lookup(
            kv.file,
            kv.key,
            Localizations.localeOf(context).languageCode,
          );
          final l = AppLocalizations.of(context)!;
          if (entry == null) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Text(l.kbNotDocumented),
            );
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
}
