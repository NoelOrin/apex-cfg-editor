import 'package:apex_cfg_editor/core/parser/cfg_document.dart';
import 'package:apex_cfg_editor/core/parser/videoconfig_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const p = VideoconfigParser();

  test('parses quoted key-value pairs', () {
    final doc = p.parse('"setting.fps_max" "0"\n"setting.r_fullscreen" "1"\n');
    expect(doc.lines.length, 2);
    final kv = doc.lines[0] as KeyValueLine;
    expect(kv.key, 'setting.fps_max');
    expect(kv.value, '0');
  });

  test('unknown lines degrade to RawLine and survive roundtrip', () {
    const src = 'garbage line !!!\n"setting.fps_max" "0"\n';
    final doc = p.parse(src);
    expect(doc.lines[0], isA<RawLine>());
    expect(doc.serialize(), src);
  });

  test('unmodified roundtrip is byte-identical incl. comments/blank/重复键', () {
    const src = '// note\n"setting.fps_max" "0"\n\n"setting.fps_max" "144"\n';
    expect(p.parse(src).serialize(), src);
  });

  test('edited line rebuilds with same style, others keep raw', () {
    final doc = p.parse('"setting.fps_max"    "0"\n"setting.r_fullscreen" "1"\n');
    (doc.lines[0] as KeyValueLine).setNewValue('144');
    expect(doc.serialize(), '"setting.fps_max" "144"\n"setting.r_fullscreen" "1"\n');
  });

  test('CRLF document: edited line keeps \\r, untouched lines byte-identical', () {
    const src = '"setting.fps_max" "0"\r\n"setting.r_fullscreen" "1"\r\n';
    final doc = p.parse(src);
    (doc.lines[0] as KeyValueLine).setNewValue('144');
    expect(
        doc.serialize(), '"setting.fps_max" "144"\r\n"setting.r_fullscreen" "1"\r\n');
  });

  test('empty value and missing trailing newline', () {
    const src = '"setting.csm_enabled" ""';
    expect(p.parse(src).serialize(), src);
  });

  test('roundtrip preserves a document that is a single newline', () {
    expect(p.parse('\n').serialize(), '\n');
  });

  test('roundtrip preserves an empty document', () {
    expect(p.parse('').serialize(), '');
  });

  test('roundtrip preserves a document of two newlines', () {
    expect(p.parse('\n\n').serialize(), '\n\n');
  });
}
