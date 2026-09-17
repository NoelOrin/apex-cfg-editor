import 'package:apex_cfg_editor/core/parser/cfg_document.dart';
import 'package:apex_cfg_editor/core/parser/settings_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses quoted operation settings and preserves bind/cvar lines', () {
    const src = '''
"Settings"
{
    "setting.mouse_sensitivity" "2.5"
    bind "F" "+interact"
    m_rawinput 1
}
''';
    final doc = const SettingsParser().parse(src);

    final quoted = doc.lines[2] as KeyValueLine;
    expect(quoted.key, 'setting.mouse_sensitivity');
    expect(quoted.value, '2.5');

    expect(doc.lines[3], isA<CvarLine>());
    expect((doc.lines[3] as CvarLine).key, 'bind');
    expect(doc.lines[4], isA<CvarLine>());
    expect(doc.serialize(), src);
  });

  test('edited quoted setting keeps settings.cfg syntax', () {
    const src = '"setting.mouse_sensitivity" "2.5"\n';
    final doc = const SettingsParser().parse(src);
    (doc.lines.single as KeyValueLine).setNewValue('3.0');

    expect(doc.serialize(), '"setting.mouse_sensitivity" "3.0"\n');
  });
}
