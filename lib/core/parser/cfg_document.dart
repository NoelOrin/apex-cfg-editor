/// 一行的四种形态。raw 始终保存原始文本，保证未编辑行逐字节写回。
sealed class CfgLine {
  final String raw;
  CfgLine(this.raw);
}

class KeyValueLine extends CfgLine {
  final String key;
  String _value;
  bool _edited = false;
  // `_value` 用私有命名初始化形参（对外参数名自动去下划线，即 `value:`）；
  // raw 需显式转发，因 CfgLine.raw 为位置参数，named 位置的 super.raw 不成立。
  KeyValueLine({required this.key, required this._value, required String raw})
      : super(raw);
  String get value => _value;
  void setNewValue(String v) {
    _value = v;
    _edited = true;
  }

  bool get isEdited => _edited;
}

/// autoexec 侧的可编辑条目（cvar / bind 等），重建为 `key value //注释`。
class CvarLine extends CfgLine {
  final String key;
  String _value;
  // 行内注释（如 `// cap`），可为空串。
  final String inlineComment;
  bool _edited = false;
  // 与 KeyValueLine 相同的私有命名初始化形参风格，raw 需显式转发。
  CvarLine({
    required this.key,
    required this._value,
    this.inlineComment = '',
    required String raw,
  }) : super(raw);
  String get value => _value;
  void setNewValue(String v) {
    _value = v;
    _edited = true;
  }

  bool get isEdited => _edited;
}

class CommentLine extends CfgLine {
  CommentLine(super.raw);
}

class BlankLine extends CfgLine {
  BlankLine(super.raw);
}

class RawLine extends CfgLine {
  RawLine(super.raw);
}

class CfgDocument {
  final List<CfgLine> lines;
  final bool endsWithNewline;
  CfgDocument({required this.lines, required this.endsWithNewline});

  /// 序列化：编辑过的键值行重建为 `"key" "value"`、编辑过的 cvar 行重建为
  /// `key value`（含行内注释则追加），其余保持原样。重建行按 raw 的行尾
  /// 风格补回 `\r`（CRLF 文档编辑后不产生混合行尾）；cvar 行 value 为空时
  /// 只输出 key，不产生 `key ` 尾随空格。
  String serialize() {
    final buf = lines.map((l) {
      if (l is KeyValueLine && l.isEdited) {
        return '"${l.key}" "${l.value}"${l.raw.endsWith('\r') ? '\r' : ''}';
      }
      if (l is CvarLine && l.isEdited) {
        final head = l.value.isEmpty ? l.key : '${l.key} ${l.value}';
        return '$head'
            '${l.inlineComment.isEmpty ? '' : ' ${l.inlineComment}'}'
            '${l.raw.endsWith('\r') ? '\r' : ''}';
      }
      return l.raw;
    }).join('\n');
    return endsWithNewline ? '$buf\n' : buf;
  }
}
