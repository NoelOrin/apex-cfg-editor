import 'package:apex_cfg_editor/core/diff/line_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const d = LineDiff();

  test('identical text → single same rows', () {
    final rows = d.diff('a\nb\n', 'a\nb\n');
    expect(rows.map((r) => r.type), everyElement(RowType.same));
  });

  test('value change → modified row pairing', () {
    final rows = d.diff('fps_max 0\nr_full 1\n', 'fps_max 144\nr_full 1\n');
    expect(rows[0].type, RowType.modified);
    expect(rows[0].left, 'fps_max 0');
    expect(rows[0].right, 'fps_max 144');
    expect(rows[1].type, RowType.same);
  });

  test('added / removed lines', () {
    expect(d.diff('a\n', 'a\nb\n').last.type, RowType.added);
    expect(d.diff('a\nb\n', 'a\n').last.type, RowType.removed);
  });

  test('empty baseline → all added', () {
    expect(d.diff('', 'a\nb\n').every((r) => r.type == RowType.added), isTrue);
  });

  test('no trailing newline → modified row preserved', () {
    final rows = d.diff('a\nb', 'a\nc');
    expect(rows.length, 2);
    expect(rows[0].type, RowType.same);
    expect(rows[1].type, RowType.modified);
    expect(rows[1].left, 'b');
    expect(rows[1].right, 'c');
    expect(rows[1].leftNo, 1);
    expect(rows[1].rightNo, 1);
  });

  test('no trailing newline on both sides → all same', () {
    final rows = d.diff('a\nb', 'a\nb');
    expect(rows.length, 2);
    expect(rows.map((r) => r.type), everyElement(RowType.same));
    expect(rows.map((r) => r.left), contains('b'));
  });

  test('trailing newline only on right → all same', () {
    expect(
        d.diff('a\nb', 'a\nb\n').map((r) => r.type), everyElement(RowType.same));
  });

  test('trailing newline only on left → all same', () {
    expect(
        d.diff('a\nb\n', 'a\nb').map((r) => r.type), everyElement(RowType.same));
  });

  test('unequal blocks advance line numbers per side', () {
    final rows = d.diff('a\nb\nc\n', 'a\nx\ny\nc\n');
    expect(rows.length, 4);
    expect(rows[0].type, RowType.same);
    expect(rows[0].leftNo, 0);
    expect(rows[0].rightNo, 0);
    expect(rows[1].type, RowType.modified);
    expect(rows[1].left, 'b');
    expect(rows[1].right, 'x');
    expect(rows[1].leftNo, 1);
    expect(rows[1].rightNo, 1);
    expect(rows[2].type, RowType.added);
    expect(rows[2].right, 'y');
    expect(rows[2].leftNo, isNull);
    expect(rows[2].rightNo, 2);
    expect(rows[3].type, RowType.same);
    expect(rows[3].left, 'c');
    expect(rows[3].leftNo, 2);
    expect(rows[3].rightNo, 3);
  });

  test('insert block before delete block keeps numbering', () {
    // dmp 0.4.1 对该输入产出 [INSERT(b), EQUAL(c), EQUAL(a), DELETE(a)]：
    // INSERT 块在 DELETE 块之前（相邻 INSERT+DELETE 经 cleanupMerge 规范化，
    // 公共 API 不可达，此为行级等价形态：added 行先于 removed 行）。
    final rows = d.diff('c\na\na\n', 'b\nc\na\n');
    expect(rows.length, 4);
    expect(rows[0].type, RowType.added);
    expect(rows[0].right, 'b');
    expect(rows[0].leftNo, isNull);
    expect(rows[0].rightNo, 0);
    expect(rows[1].type, RowType.same);
    expect(rows[1].left, 'c');
    expect(rows[1].leftNo, 0);
    expect(rows[1].rightNo, 1);
    expect(rows[2].type, RowType.same);
    expect(rows[2].left, 'a');
    expect(rows[2].leftNo, 1);
    expect(rows[2].rightNo, 2);
    expect(rows[3].type, RowType.removed);
    expect(rows[3].left, 'a');
    expect(rows[3].leftNo, 2);
    expect(rows[3].rightNo, isNull);
  });
}
