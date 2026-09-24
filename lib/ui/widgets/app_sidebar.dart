import 'package:fluent_ui/fluent_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/acid_theme.dart';

/// 左侧主导航（Fluent NavigationView 风格）。
///
/// 菜单职责：编辑器 / 知识库 / 变更对比 / 设置；文件操作仍留在标题栏。
/// 选中态对齐 Win11 左侧指示条 + 浅色底；整栏 Acrylic 毛玻璃。
class AppSidebar extends StatelessWidget {
  static const double expandedWidth = 208;
  static const double itemHeight = 40;

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AcidPalette.of(context);
    return Acrylic(
      tint: palette.bg,
      tintAlpha: 0.72,
      luminosityAlpha: 0.5,
      blurAmount: 28,
      child: Container(
        width: expandedWidth,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: palette.chrome.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            _NavItem(
              key: const ValueKey('sidebar.editor'),
              icon: LucideIcons.table2,
              label: _labelOf(context, 0),
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            _NavItem(
              key: const ValueKey('sidebar.knowledgeBase'),
              icon: LucideIcons.bookOpen,
              label: _labelOf(context, 1),
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
            _NavItem(
              key: const ValueKey('sidebar.diffPreview'),
              icon: LucideIcons.gitCompare,
              label: _labelOf(context, 2),
              selected: selectedIndex == 2,
              onTap: () => onSelected(2),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                height: 1,
                color: palette.chrome.withValues(alpha: 0.4),
              ),
            ),
            _NavItem(
              key: const ValueKey('sidebar.settings'),
              icon: LucideIcons.settings2,
              label: _labelOf(context, 3),
              selected: selectedIndex == 3,
              onTap: () => onSelected(3),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _labelOf(BuildContext context, int index) {
    final l = AppLocalizations.of(context)!;
    return switch (index) {
      0 => l.navEditor,
      1 => l.knowledgeBase,
      2 => l.diffPreview,
      _ => l.settings,
    };
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AcidPalette.of(context);
    final bg = selected
        ? palette.acid.withValues(alpha: 0.14)
        : Colors.transparent;
    final fg = selected ? palette.text : palette.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: HoverButton(
        onPressed: onTap,
        builder: (context, state) {
          final hoverBg = state.isHovered && !selected
              ? palette.text.withValues(alpha: 0.06)
              : bg;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: AppSidebar.itemHeight,
            decoration: BoxDecoration(
              color: hoverBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 3,
                  height: 18,
                  margin: const EdgeInsetsDirectional.only(start: 2),
                  decoration: BoxDecoration(
                    color: selected ? palette.acid : Colors.transparent,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
