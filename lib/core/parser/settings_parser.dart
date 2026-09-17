import 'cfg_document.dart';
import 'autoexec_parser.dart';

/// settings.cfg 解析器：操作设置文件在不同版本中可能使用
/// `"key" "value"`，也可能使用 `bind ...` / 裸 cvar 指令。
/// 先按 cvar 结构保留注释与未知行，再把引号键值行提升为 KeyValueLine。
class SettingsParser {
  const SettingsParser();

  static final _kv = RegExp(r'^(\s*)"([^"]+)"(\s+)"([^"]*)"(\s*)$');

  CfgDocument parse(String src) {
    final parsed = const AutoexecParser().parse(src);
    final lines = parsed.lines.map<CfgLine>((line) {
      if (line is! CvarLine) return line;
      final t = line.raw.trim();
      if (t == '{' || t == '}' || (t.startsWith('"') && t.endsWith('{'))) {
        return RawLine(line.raw);
      }
      final m = _kv.firstMatch(line.raw);
      if (m == null) {
        return t.startsWith('"') ? RawLine(line.raw) : line;
      }
      return KeyValueLine(key: m.group(2)!, value: m.group(4)!, raw: line.raw);
    }).toList();
    return CfgDocument(lines: lines, endsWithNewline: parsed.endsWithNewline);
  }
}
