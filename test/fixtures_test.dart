import 'dart:convert';
import 'dart:io';

import 'package:apex_cfg_editor/core/io/cfg_file_io.dart';
import 'package:apex_cfg_editor/core/parser/autoexec_parser.dart';
import 'package:apex_cfg_editor/core/parser/cfg_document.dart';
import 'package:apex_cfg_editor/core/parser/videoconfig_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 全文件验收夹具的 roundtrip 守卫：读盘 → 解析 → 序列化 → 与读出的文本
/// 逐字节一致；同时钉住夹具形态（编码/注释/重复键/未知行），
/// 并校验夹具键集与知识库键集的一致性。
void main() {
  late List<int> vcBytes, aeGbkBytes, aeUtf8Bytes;
  late CfgFileData vcData, aeGbk, aeUtf8;

  setUpAll(() {
    vcBytes = File('test/fixtures/videoconfig.sample.txt').readAsBytesSync();
    aeGbkBytes = File('test/fixtures/autoexec.sample.cfg').readAsBytesSync();
    aeUtf8Bytes =
        File('test/fixtures/autoexec_utf8.sample.cfg').readAsBytesSync();
    vcData = CfgFileIo.readBytes(vcBytes);
    aeGbk = CfgFileIo.readBytes(aeGbkBytes);
    aeUtf8 = CfgFileIo.readBytes(aeUtf8Bytes);
  });

  Map<String, dynamic> kbJson(String rel) =>
      jsonDecode(File(rel).readAsStringSync()) as Map<String, dynamic>;

  group('videoconfig.sample.txt', () {
    test('UTF-8 无 BOM、LF 行尾', () {
      expect(vcData.encoding, CfgEncoding.utf8);
      expect(vcData.hasBadBytes, isFalse);
      expect(vcBytes.take(3), isNot(equals([0xEF, 0xBB, 0xBF])));
      expect(vcBytes.contains(0x0D), isFalse, reason: '夹具必须为 LF 行尾');
    });

    test('全文件 roundtrip 逐字节一致（注释/空行/多余空格/未知行原样保真）', () {
      final doc = const VideoconfigParser().parse(vcData.text);
      expect(doc.serialize(), vcData.text);
      expect(utf8.encode(doc.serialize()), vcBytes);
      expect(doc.lines.whereType<RawLine>(), isNotEmpty);
      expect(doc.lines.whereType<CommentLine>(), isNotEmpty);
      expect(doc.lines.whereType<BlankLine>(), isNotEmpty);
    });

    test('39 个真实 setting.* 键，含同一键出现两次', () {
      final kv = const VideoconfigParser()
          .parse(vcData.text)
          .lines
          .whereType<KeyValueLine>()
          .toList();
      final keys = kv.map((l) => l.key).toSet();
      expect(keys.length, 39, reason: '真实 videoconfig.txt 即 39 键');
      expect(kv.length, greaterThan(keys.length), reason: '必须含重复键');
      expect(keys.every((k) => k.startsWith('setting.')), isTrue);
    });

    test('夹具键集 ⊆ 知识库键集（真实键，无合成键）', () {
      final kbKeys = kbJson('assets/kb/zh/videoconfig.json')
          .keys
          .map((k) => k.toLowerCase())
          .toSet();
      final fixtureKeys = const VideoconfigParser()
          .parse(vcData.text)
          .lines
          .whereType<KeyValueLine>()
          .map((l) => l.key.toLowerCase())
          .toSet();
      expect(kbKeys.containsAll(fixtureKeys), isTrue,
          reason: '夹具出现知识库未收录键即失败（任务 6 账本：合成键不算覆盖率）');
    });
  });

  group('autoexec.sample.cfg（GBK）', () {
    test('GBK 编码识别且无坏字节', () {
      expect(aeGbk.encoding, CfgEncoding.gbk);
      expect(aeGbk.hasBadBytes, isFalse);
    });

    test('全文件 roundtrip 逐字节一致', () {
      expect(const AutoexecParser().parse(aeGbk.text).serialize(), aeGbk.text);
    });

    test('按原编码写回得到原字节（GBK 保存链路）', () {
      final tmp = Directory.systemTemp.createTempSync('fixtgbk');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final p = '${tmp.path}/autoexec.cfg';
      CfgFileIo.write(p, aeGbk.text, aeGbk.encoding);
      expect(File(p).readAsBytesSync(), aeGbkBytes);
    });

    test('夹具键集 ⊆ 知识库键集（正式核验，任务 17 账本）', () {
      final kbKeys = kbJson('assets/kb/zh/autoexec.json')
          .keys
          .map((k) => k.toLowerCase())
          .toSet();
      final fixtureKeys = const AutoexecParser()
          .parse(aeGbk.text)
          .lines
          .whereType<CvarLine>()
          .map((l) => l.key.toLowerCase())
          .toSet();
      expect(kbKeys.containsAll(fixtureKeys), isTrue,
          reason: 'autoexec 夹具出现知识库未收录键即失败');
    });

    test('行注释/块注释/bind 引号值/行内注释/重复键形态齐全', () {
      final doc = const AutoexecParser().parse(aeGbk.text);
      final comments =
          doc.lines.whereType<CommentLine>().map((l) => l.raw).toList();
      expect(comments.any((r) => r.trimLeft().startsWith('/*')), isTrue);
      expect(comments.any((r) => r.trimLeft().startsWith('*/')), isTrue);

      final cvars = doc.lines.whereType<CvarLine>().toList();
      final binds = cvars.where((l) => l.key == 'bind').toList();
      expect(binds, isNotEmpty);
      expect(binds.any((l) => l.value.contains('"')), isTrue,
          reason: 'bind 值含引号');
      expect(binds.any((l) => l.inlineComment.startsWith('//')), isTrue,
          reason: 'bind 行带行内注释');

      final counts = <String, int>{};
      for (final l in cvars) {
        counts[l.key] = (counts[l.key] ?? 0) + 1;
      }
      expect(counts['cl_showfps'], 2, reason: '重复键：同一键出现两次');
    });
  });

  group('autoexec_utf8.sample.cfg', () {
    test('UTF-8 编码且与 GBK 版内容一致', () {
      expect(aeUtf8.encoding, CfgEncoding.utf8);
      expect(aeUtf8.hasBadBytes, isFalse);
      expect(aeUtf8Bytes.contains(0x0D), isFalse, reason: '夹具必须为 LF 行尾');
      expect(aeUtf8.text, aeGbk.text);
      expect(
          const AutoexecParser().parse(aeUtf8.text).serialize(), aeUtf8.text);
    });
  });
}
