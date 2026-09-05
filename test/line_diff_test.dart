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
}
