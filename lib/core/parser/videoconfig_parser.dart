import 'cfg_document.dart';

class VideoconfigParser {
  const VideoconfigParser();

  static final _kv = RegExp(r'^(\s*)"([^"]+)"(\s+)"([^"]*)"(\s*)$');

  CfgDocument parse(String src) {
    final hasTrailing = src.endsWith('\n');
    final rawLines = src.split('\n');
    if (hasTrailing) rawLines.removeLast();
    final lines = <CfgLine>[];
    for (final raw in rawLines) {
      final t = raw.trim();
      if (t.isEmpty) {
        lines.add(BlankLine(raw));
      } else if (t.startsWith('//')) {
        lines.add(CommentLine(raw));
      } else {
        final m = _kv.firstMatch(raw);
        if (m == null) {
          lines.add(RawLine(raw));
        } else {
          lines.add(KeyValueLine(
            key: m.group(2)!,
            value: m.group(4)!,
            raw: raw,
          ));
        }
      }
    }
    return CfgDocument(lines: lines, endsWithNewline: hasTrailing);
  }
}
