import 'dart:convert';
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
    expect(r.hasBadBytes, isFalse);
    expect(r.text.contains('帧数优化'), isTrue);
  });

  test('bom file with bad bytes flagged, not thrown', () {
    final r = CfgFileIo.readBytes([0xEF, 0xBB, 0xBF, 0x61, 0xFF]);
    expect(r.encoding, CfgEncoding.utf8);
    expect(r.hasBadBytes, isTrue);
    expect(r.text.startsWith('a'), isTrue);
    expect(r.text.contains('\u{FFFD}'), isTrue);
  });

  test('gbk text writes back by original encoding', () {
    final f = File('${tmp.path}/c.cfg')
      ..writeAsBytesSync(gbk.encode('// 帧数优化\nfps_max 128\n'));
    final r = CfgFileIo.read(f.path);
    expect(r.hasBadBytes, isFalse);
    final gbkPath = '${tmp.path}/c-gbk.cfg';
    CfgFileIo.write(gbkPath, r.text, r.encoding);
    expect(File(gbkPath).readAsBytesSync(), f.readAsBytesSync());
    final r2 = CfgFileIo.read(gbkPath);
    expect(r2.encoding, CfgEncoding.gbk);
    expect(r2.text, r.text);
    final utf8Path = '${tmp.path}/c-utf8.cfg';
    CfgFileIo.write(utf8Path, r.text, CfgEncoding.utf8);
    expect(File(utf8Path).readAsBytesSync(), isNot(f.readAsBytesSync()));
    expect(gbk.decode(File(utf8Path).readAsBytesSync()).contains('\u{FFFD}'),
        isFalse);
  });

  test('bad bytes flagged via U+FFFD', () {
    final r = CfgFileIo.readBytes([0x61, 0x20, 0xFF, 0x0A]);
    expect(r.hasBadBytes, isTrue);
  });

  test('write with bom: true keeps EF BB BF for utf8 content', () {
    final f = File('${tmp.path}/bom.cfg')
      ..writeAsBytesSync([0xEF, 0xBB, 0xBF, ...'fps_max 128\n'.codeUnits]);
    final r = CfgFileIo.read(f.path);
    expect(r.encoding, CfgEncoding.utf8);
    CfgFileIo.write(f.path, r.text, r.encoding, bom: true);
    final bytes = File(f.path).readAsBytesSync();
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(utf8.decode(bytes.sublist(3)), r.text);
  });

  test('write without bom flag produces no BOM', () {
    final f = File('${tmp.path}/plain.cfg')..writeAsStringSync('a\n');
    final r = CfgFileIo.read(f.path);
    CfgFileIo.write(f.path, r.text, r.encoding);
    expect(File(f.path).readAsBytesSync().first, isNot(0xEF));
  });

  test('bom flag has no effect for gbk', () {
    final f = File('${tmp.path}/g.cfg')
      ..writeAsBytesSync(gbk.encode('// 帧数优化\n'));
    final r = CfgFileIo.read(f.path);
    CfgFileIo.write(f.path, r.text, r.encoding, bom: true);
    expect(File(f.path).readAsBytesSync(), f.readAsBytesSync());
  });
}
