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

  /// 序列化：编辑过的键值行重建为 `"key" "value"`，其余保持原样。
  String serialize() {
    final buf = lines.map((l) {
      if (l is KeyValueLine && l.isEdited) return '"${l.key}" "${l.value}"';
      return l.raw;
    }).join('\n');
    return endsWithNewline ? '$buf\n' : buf;
  }
}
