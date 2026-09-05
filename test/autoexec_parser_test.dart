import 'package:apex_cfg_editor/core/parser/cfg_document.dart';
import 'package:apex_cfg_editor/core/parser/autoexec_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const p = AutoexecParser();

  test('parses cvar lines with inline comment', () {
    final doc = p.parse('fps_max 128 // cap\nmat_queue_mode 2\n');
    final kv = doc.lines[0] as CvarLine;
    expect(kv.key, 'fps_max');
    expect(kv.value, '128');
    expect(kv.inlineComment, '// cap');
  });

  test('bind line becomes editable cvar-like entry', () {
    final doc = p.parse('bind "F6" "quit"\n');
    final kv = doc.lines[0] as CvarLine;
    expect(kv.key, 'bind');
    expect(kv.value, '"F6" "quit"');
  });

  test('block comments spanning lines are preserved', () {
    const src = '/* head\nstill comment */\nfps_max 128\n';
    expect(p.parse(src).lines[0], isA<CommentLine>());
    expect(p.parse(src).lines[1], isA<CommentLine>());
    expect(p.parse(src).serialize(), src);
  });

  test('unknown/blank/comment roundtrip byte-identical', () {
    const src = '// FPS\n\nfps_max 128\nexec banned.cfg\nunbindall\n';
    expect(p.parse(src).serialize(), src);
  });

  test('edited cvar rebuilds keeping inline comment', () {
    final doc = p.parse('fps_max 128 // cap\n');
    (doc.lines[0] as CvarLine).setNewValue('0');
    expect(doc.serialize(), 'fps_max 0 // cap\n');
  });
}
