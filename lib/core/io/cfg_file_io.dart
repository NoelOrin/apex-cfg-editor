import 'dart:convert';
import 'dart:io';
import 'package:fast_gbk/fast_gbk.dart';

enum CfgEncoding { utf8, gbk }

class CfgFileData {
  final String text;
  final CfgEncoding encoding;
  final bool hasBadBytes;
  final List<int> originalBytes;
  CfgFileData(this.text, this.encoding, this.hasBadBytes, this.originalBytes);
}

class CfgFileIo {
  static CfgFileData read(String path) => readBytes(File(path).readAsBytesSync());

  static CfgFileData readBytes(List<int> bytes) {
    final bom = bytes.length >= 3 &&
        bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
    if (bom) {
      final text = utf8WithBom(bytes);
      return CfgFileData(text, CfgEncoding.utf8, text.contains('\u{FFFD}'), bytes);
    }
    var ok = true;
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      ok = false;
      text = '';
    }
    if (ok) return CfgFileData(text, CfgEncoding.utf8, false, bytes);
    text = gbk.decode(bytes, allowMalformed: true);
    return CfgFileData(text, CfgEncoding.gbk, text.contains('\u{FFFD}'), bytes);
  }

  static String utf8WithBom(List<int> bytes) =>
      utf8.decode(bytes.sublist(3), allowMalformed: true);

  /// 有坏字节且内容被编辑时由上层拦截告警；未编辑时上层应走 writeOriginalBytes。
  static void write(String path, String text, CfgEncoding enc) {
    final data = enc == CfgEncoding.gbk ? gbk.encode(text) : utf8.encode(text);
    final tmp = '$path.tmp';
    File(tmp).writeAsBytesSync(data, flush: true);
    File(tmp).renameSync(path); // 原子替换
  }

  static void writeOriginalBytes(String path, List<int> originalBytes) {
    final tmp = '$path.tmp';
    File(tmp).writeAsBytesSync(originalBytes, flush: true);
    File(tmp).renameSync(path);
  }
}
