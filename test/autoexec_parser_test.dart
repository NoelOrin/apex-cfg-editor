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

  test('// inside quotes stays part of the value', () {
    final doc = p.parse('bind "T" "say // hi"\n');
    final kv = doc.lines[0] as CvarLine;
    expect(kv.key, 'bind');
    expect(kv.value, '"T" "say // hi"');
    expect(kv.inlineComment, '');
  });

  test('unquoted // after quoted value still splits a comment', () {
    final doc = p.parse('fps_max 128 // cap\n');
    final kv = doc.lines[0] as CvarLine;
    expect(kv.value, '128');
    expect(kv.inlineComment, '// cap');
  });

  test('escaped quotes keep quote state, // inside stays value', () {
    final doc = p.parse('bind "T" "say \\"// ok\\""\n');
    final kv = doc.lines[0] as CvarLine;
    expect(kv.value, '"T" "say \\"// ok\\""');
    expect(kv.inlineComment, '');
  });

  test('mid-line block comment opens comment region', () {
    final doc = p.parse('fps_max 128 /* note\nmat_queue_mode 2\n');
    final kv = doc.lines[0] as CvarLine;
    expect(kv.key, 'fps_max');
    expect(kv.value, '128');
    expect(kv.inlineComment, '/* note');
    expect(doc.lines[1], isA<CommentLine>());
  });

  test('CRLF document: edited cvar line keeps \\r, others byte-identical', () {
    final doc = p.parse('fps_max 128 // cap\r\nmat_queue_mode 2\r\n');
    (doc.lines[0] as CvarLine).setNewValue('0');
    expect(doc.serialize(), 'fps_max 0 // cap\r\nmat_queue_mode 2\r\n');
  });

  test('empty value edit rebuilds without trailing space (with comment)', () {
    final doc = p.parse('fps_max 128 // cap\n');
    (doc.lines[0] as CvarLine).setNewValue('');
    expect(doc.serialize(), 'fps_max // cap\n');
  });

  test('empty value edit rebuilds bare key (no comment, no trailing space)', () {
    final doc = p.parse('fps_max 128\n');
    (doc.lines[0] as CvarLine).setNewValue('');
    expect(doc.serialize(), 'fps_max\n');
  });

  test('single-line fully closed block comment: next line is CvarLine', () {
    final doc = p.parse('/* c */\nfps_max 128\n');
    expect(doc.lines[0], isA<CommentLine>());
    expect(doc.lines[1], isA<CvarLine>());
    expect(doc.serialize(), '/* c */\nfps_max 128\n');
  });

  test('self-closing mid-line block comment stays on one line', () {
    final doc = p.parse('fps_max 128 /* note */\nmat_queue_mode 2\n');
    final kv = doc.lines[0] as CvarLine;
    expect(kv.value, '128');
    expect(kv.inlineComment, '/* note */');
    expect(doc.lines[1], isA<CvarLine>());
  });
}
