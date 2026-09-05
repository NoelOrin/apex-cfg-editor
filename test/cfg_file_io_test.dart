import 'dart:io';
import 'package:apex_cfg_editor/core/io/cfg_file_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fast_gbk/fast_gbk.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cfgio'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('utf8 file reads and writes back identical', () {
    final f = File('${tmp.path}/a.cfg')..writeAsBytesSync('fps_max 128\n'.codeUnits);
    final r = CfgFileIo.read(f.path);
    expect(r.encoding, CfgEncoding.utf8);
    expect(r.hasBadBytes, isFalse);
    CfgFileIo.write(f.path, 'fps_max 0\n', r.encoding);
    expect(File(f.path).readAsStringSync(), 'fps_max 0\n');
  });

  test('gbk file with chinese comment detected and preserved', () {
    final f = File('${tmp.path}/b.cfg')
      ..writeAsBytesSync(gbk.encode('// 帧数优化\nfps_max 128\n'));
    final r = CfgFileIo.read(f.path);
    expect(r.encoding, CfgEncoding.gbk);
    expect(r.text.contains('帧数优化'), isTrue);
  });

  test('bad bytes flagged via U+FFFD', () {
    final r = CfgFileIo.readBytes([0x61, 0x20, 0xFF, 0x0A]);
    expect(r.hasBadBytes, isTrue);
  });
}
