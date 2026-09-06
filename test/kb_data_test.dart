import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 知识库数据本体测试（任务 6 账本项）：校验 assets/kb 下四份 JSON 的
/// zh/en 键集一致、五字段完整、risk 枚举合法、values 子结构合规。
/// 直接读盘而非注入，保证测试的就是打包进 assets 的真实数据。
void main() {
  const files = ['videoconfig', 'autoexec'];
  const locales = ['zh', 'en'];
  const fiveFields = ['name', 'description', 'recommended', 'risk', 'values'];
  const allowedRisks = {'low', 'medium', 'high'};

  Map<String, dynamic> load(String locale, String file) =>
      jsonDecode(File('assets/kb/$locale/$file.json').readAsStringSync())
          as Map<String, dynamic>;

  for (final file in files) {
    group('assets/kb/*/$file.json', () {
      final tables = {for (final l in locales) l: load(l, file)};

      test('zh/en 键集完全一致（parity）', () {
        final zhKeys = tables['zh']!.keys.toSet();
        final enKeys = tables['en']!.keys.toSet();
        expect(zhKeys, enKeys, reason: 'zh/en 键集必须一致，缺翻或缺键都是数据缺陷');
      });

      test('键名规范化形态（无引号、非空、trim 后无首尾空白）', () {
        for (final table in tables.values) {
          for (final key in table.keys) {
            expect(key, isNot(contains('"')), reason: '键 $key 不应带引号');
            expect(key.trim(), key, reason: '键 $key 不应有首尾空白');
            expect(key, isNotEmpty);
          }
        }
      });

      test('每条五字段完整且类型正确', () {
        for (final entry in [
          for (final t in tables.values) ...t.values
        ]) {
          final m = entry as Map<String, dynamic>;
          for (final f in fiveFields) {
            expect(m.containsKey(f), isTrue, reason: '条目缺字段 $f: $m');
          }
          expect(m['name'], isA<String>());
          expect(m['description'], isA<String>());
          expect((m['name'] as String).trim(), isNotEmpty);
          expect((m['description'] as String).trim(), isNotEmpty);
          expect(m['recommended'], isA<String>());
          expect(m['values'], isA<List>());
        }
      });

      test('risk 枚举合法（low|medium|high）', () {
        for (final entry in [
          for (final t in tables.values) ...t.values
        ]) {
          final risk = (entry as Map<String, dynamic>)['risk'] as String?;
          expect(allowedRisks.contains(risk), isTrue,
              reason: 'risk="$risk" 不在 low|medium|high 中');
        }
      });

      test('values 子项均有非空 v 与 label', () {
        for (final entry in [
          for (final t in tables.values) ...t.values
        ]) {
          final values = (entry as Map<String, dynamic>)['values'] as List;
          for (final v in values) {
            final m = v as Map<String, dynamic>;
            expect(m.containsKey('v'), isTrue, reason: 'values 子项缺 v: $m');
            expect(m.containsKey('label'), isTrue, reason: 'values 子项缺 label: $m');
            expect((m['v'] as String).trim(), isNotEmpty);
            expect((m['label'] as String).trim(), isNotEmpty);
          }
        }
      });
    });
  }
}
