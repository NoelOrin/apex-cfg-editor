import 'package:diff_match_patch/diff_match_patch.dart' as dmp;

/// 双栏对齐视图的行类型。
enum RowType { same, modified, added, removed }

/// 一行对齐结果：same 行左右一致；modified 行左右按位置配对；
/// removed 只填 left，added 只填 right；行号从 0 起，缺失一侧为 null。
class DiffRow {
  final RowType type;
  final String? left, right;
  final int? leftNo, rightNo;
  DiffRow(this.type, {this.left, this.right, this.leftNo, this.rightNo});
}

/// 行级 diff：diff_match_patch 的行模式包装。
class LineDiff {
  const LineDiff();

  /// 基线 → 当前行级对齐视图（git 双栏风格）。
  List<DiffRow> diff(String baseline, String current) {
    // 归一化：非空且不以 \n 结尾的文本补终止符，保证逐行切分不丢行；
    // 补的终止符只用于行切分，不会出现在任何 DiffRow 文本中。
    if (baseline.isNotEmpty && !baseline.endsWith('\n')) baseline += '\n';
    if (current.isNotEmpty && !current.endsWith('\n')) current += '\n';
    if (baseline == current) return _allSame(baseline, current);
    // 1000ms（diff_match_patch 的 diffTimeout 单位是秒）。
    final engine = dmp.DiffMatchPatch()..diffTimeout = 1.0;

    // 0.4.x 未导出 linesToChars/charsToLines，这里按同款算法自行编解码：
    // 每行（含行尾 \n）映射为一个码元，diff 在码元串上进行，再还原为行文本。
    final lineArray = <String>['']; // 0 号为占位空行，与包内实现一致
    final lineHash = <String, int>{};
    final chars1 = _encode(baseline, lineArray, lineHash);
    final chars2 = _encode(current, lineArray, lineHash);
    final lineDiffs = engine.diff(chars1, chars2);
    _decodeLines(lineDiffs, lineArray);

    // 逐块展开为 (op, 行列表)，再把相邻 del+ins 配对
    final rows = <DiffRow>[];
    int li = 0, ri = 0;
    final ops = lineDiffs.map((e) => MapEntry(e.operation, e.text)).toList();
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final ls = op.key == dmp.DIFF_DELETE || op.key == dmp.DIFF_EQUAL
          ? (op.value.split('\n')..removeLast())
          : <String>[];
      final rs = op.key == dmp.DIFF_INSERT || op.key == dmp.DIFF_EQUAL
          ? (op.value.split('\n')..removeLast())
          : <String>[];
      if (op.key == dmp.DIFF_EQUAL) {
        for (final l in ls) {
          rows.add(DiffRow(RowType.same,
              left: l, right: l, leftNo: li++, rightNo: ri++));
        }
      } else {
        // 收集紧随其后的另一个非 EQUAL 块配对
        List<String> dels = ls, adds = rs;
        if (op.key == dmp.DIFF_DELETE &&
            i + 1 < ops.length &&
            ops[i + 1].key == dmp.DIFF_INSERT) {
          adds = ops[i + 1].value.split('\n')..removeLast();
          i++;
        } else if (op.key == dmp.DIFF_INSERT &&
            i + 1 < ops.length &&
            ops[i + 1].key == dmp.DIFF_DELETE) {
          dels = ops[i + 1].value.split('\n')..removeLast();
          i++;
        }
        final n = dels.length < adds.length ? dels.length : adds.length;
        for (var k = 0; k < n; k++) {
          rows.add(DiffRow(RowType.modified,
              left: dels[k], right: adds[k], leftNo: li++, rightNo: ri++));
        }
        for (var k = n; k < dels.length; k++) {
          rows.add(DiffRow(RowType.removed, left: dels[k], leftNo: li++));
        }
        for (var k = n; k < adds.length; k++) {
          rows.add(DiffRow(RowType.added, right: adds[k], rightNo: ri++));
        }
      }
    }
    return rows.map(_stripTrailingCr).toList();
  }

  /// 显示层归一化：CRLF 输入的行文本剥掉单个行尾 `\r`（Flutter Text 渲染
  /// 不可见的显示噪声）。仅作用于 DiffRow 文本，不影响 diff 比较对象。
  DiffRow _stripTrailingCr(DiffRow r) => DiffRow(r.type,
      left: r.left == null ? null : _withoutCr(r.left!),
      right: r.right == null ? null : _withoutCr(r.right!),
      leftNo: r.leftNo,
      rightNo: r.rightNo);

  static String _withoutCr(String s) =>
      s.endsWith('\r') ? s.substring(0, s.length - 1) : s;

  List<DiffRow> _allSame(String baseline, String current) {
    final l = baseline.split('\n')..removeLast();
    final r = current.split('\n')..removeLast();
    final rows = <DiffRow>[];
    for (var i = 0; i < l.length; i++) {
      rows.add(DiffRow(RowType.same,
          left: l[i], right: r[i], leftNo: i, rightNo: i));
    }
    return rows.map(_stripTrailingCr).toList();
  }

  /// 把文本按行（含行尾 \n）编码为“一行一码元”的字符串。
  String _encode(
      String text, List<String> lineArray, Map<String, int> lineHash) {
    final chars = StringBuffer();
    var lineStart = 0;
    while (lineStart < text.length) {
      var lineEnd = text.indexOf('\n', lineStart);
      lineEnd = lineEnd == -1 ? text.length : lineEnd + 1;
      final line = text.substring(lineStart, lineEnd);
      lineStart = lineEnd;
      final idx = lineHash.putIfAbsent(line, () {
        lineArray.add(line);
        return lineArray.length - 1;
      });
      chars.writeCharCode(idx);
    }
    return chars.toString();
  }

  /// 把 diff 结果中的码元还原为行文本（原地改写，等价于包内 charsToLines）。
  void _decodeLines(List<dmp.Diff> diffs, List<String> lineArray) {
    for (final d in diffs) {
      final buf = StringBuffer();
      for (var i = 0; i < d.text.length; i++) {
        buf.write(lineArray[d.text.codeUnitAt(i)]);
      }
      d.text = buf.toString();
    }
  }
}
