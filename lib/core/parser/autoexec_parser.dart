import 'cfg_document.dart';

/// autoexec.cfg 解析器：cvar 命令、bind（原样视作可编辑 cvar 条目）、
/// 行/块注释。未知行降级为 [RawLine]。
class AutoexecParser {
  const AutoexecParser();

  static final _cvar = RegExp(r'^(\s*)([^\s/][^\s]*)(?:\s+(.*?))?(\s*)$');

  /// 首个位于双引号字符串之外的注释起点（`//` 或 `/*`）下标；无则 -1。
  /// 引号内的 `//`、`/*` 是值的一部分（Source 引擎语义）；`\\"` 等转义不改变引号状态。
  static int _commentStart(String s) {
    var inQuote = false;
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == '\\') {
        i += 2; // 转义：连同下一字符跳过
        continue;
      }
      if (c == '"') {
        inQuote = !inQuote;
      } else if (!inQuote &&
          c == '/' &&
          i + 1 < s.length &&
          (s[i + 1] == '/' || s[i + 1] == '*')) {
        return i;
      }
      i += 1;
    }
    return -1;
  }

  CfgDocument parse(String src) {
    final hasTrailing = src.endsWith('\n');
    final rawLines = src.split('\n');
    if (hasTrailing) rawLines.removeLast();
    final lines = <CfgLine>[];
    var inBlock = false;
    for (final raw in rawLines) {
      final t = raw.trim();
      if (t.isEmpty) {
        lines.add(BlankLine(raw));
        continue;
      }
      if (inBlock) {
        lines.add(CommentLine(raw));
        if (t.contains('*/')) inBlock = false;
        continue;
      }
      if (t.startsWith('/*')) {
        lines.add(CommentLine(raw));
        // 单行完整闭合（如 `/* x */`）不进入块状态。
        if (!t.contains('*/')) inBlock = true;
        continue;
      }
      if (t.startsWith('//')) {
        lines.add(CommentLine(raw));
        continue;
      }
      final m = _cvar.firstMatch(raw);
      if (m == null) {
        lines.add(RawLine(raw));
        continue;
      }
      final rest = (m.group(3) ?? '').trim();
      String value = rest, comment = '';
      final ci = _commentStart(rest);
      if (ci >= 0) {
        value = rest.substring(0, ci).trim();
        comment = rest.substring(ci).trim();
        // 行中 `/*` 亦开启注释区段：该行内无闭合 `*/` 则后续行进入块注释。
        if (rest.startsWith('/*', ci) && !rest.contains('*/', ci)) {
          inBlock = true;
        }
      }
      lines.add(CvarLine(
        key: m.group(2)!,
        value: value,
        inlineComment: comment,
        raw: raw,
      ));
    }
    return CfgDocument(lines: lines, endsWithNewline: hasTrailing);
  }
}
