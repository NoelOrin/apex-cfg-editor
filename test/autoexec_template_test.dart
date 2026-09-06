import 'package:apex_cfg_editor/core/templates/autoexec_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('autoexecTemplate', () {
    test('all non-empty lines are comments (不改变游戏行为)', () {
      for (final line in autoexecTemplate.split('\n')) {
        if (line.trim().isEmpty) continue;
        expect(
          line.trimLeft().startsWith('//'),
          isTrue,
          reason: '非注释行会改变游戏行为: $line',
        );
      }
    });

    test('bilingual: 中文与英文说明同时存在', () {
      expect(autoexecTemplate, contains('帧数'));
      expect(autoexecTemplate, contains(RegExp(r'[A-Za-z]{4,}')));
    });

    test('performance group has 3-5 example cvar lines', () {
      final exampleLines = autoexecTemplate
          .split('\n')
          .where((l) => RegExp(r'^// [a-z_]+ \S+\s*$').hasMatch(l))
          .toList();
      expect(exampleLines.length, inInclusiveRange(3, 5));
    });

    test('ends with a trailing newline', () {
      expect(autoexecTemplate.endsWith('\n'), isTrue);
    });
  });
}
