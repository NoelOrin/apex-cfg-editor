import 'dart:convert';

import 'package:flutter/services.dart';

/// 知识库覆盖的配置文件域：videoconfig.txt、settings.cfg 与 autoexec.cfg。
enum KbFile { videoconfig, settings, autoexec }

/// 知识库条目的单个可选值。
class KbValue {
  final String v, label;

  const KbValue(this.v, this.label);
}

/// 知识库条目：一个键值对的用途说明。
class KbEntry {
  final String name, description, recommended, risk;
  final List<KbValue> values;

  const KbEntry({
    required this.name,
    required this.description,
    required this.recommended,
    required this.risk,
    required this.values,
  });

  KbEntry.fromJson(Map<String, dynamic> j)
    : name = j['name'] ?? '',
      description = j['description'] ?? '',
      recommended = j['recommended'] ?? '',
      risk = j['risk'] ?? 'low',
      values = ((j['values'] as List?) ?? [])
          .map(
            (v) =>
                KbValue(v['v'] as String? ?? '', v['label'] as String? ?? ''),
          )
          .toList();
}

class KbService {
  /// locale → 键 → 条目 JSON。键为规范化形态（去引号、trim、小写）。
  /// 测试注入；生产用 [fromAssets]。保留此字段兼容旧测试与跨域回退。
  final Map<String, Map<String, dynamic>> data;

  /// locale → 文件域 → 键 → 条目 JSON。生产查询优先使用按域数据，
  /// 避免 settings.cfg 与 autoexec.cfg 的同名键互相覆盖。
  final Map<String, Map<KbFile, Map<String, dynamic>>> fileData;
  static const _assetBase = 'assets/kb';

  const KbService({required this.data, this.fileData = const {}});

  /// 从 assets/kb/{zh,en}/{videoconfig,autoexec}.json 加载，
  /// 同一语言的两个文件按序合并为一张表。
  static Future<KbService> fromAssets() async {
    final out = <String, Map<String, dynamic>>{};
    final byFile = <String, Map<KbFile, Map<String, dynamic>>>{};
    for (final loc in const ['zh', 'en']) {
      final merged = <String, dynamic>{};
      final localeFiles = <KbFile, Map<String, dynamic>>{};
      for (final f in KbFile.values) {
        final raw = await rootBundle.loadString(
          '$_assetBase/$loc/${f.name}.json',
        );
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final normalized = {
          for (final e in json.entries) _norm(e.key): e.value,
        };
        localeFiles[f] = normalized;
        merged.addAll(normalized);
      }
      out[loc] = merged;
      byFile[loc] = localeFiles;
    }
    return KbService(data: out, fileData: byFile);
  }

  /// 查找键的说明；先查请求语言，缺失时回退英文，仍未命中返回 null。
  KbEntry? lookup(KbFile file, String key, String locale) {
    for (final loc in [locale, if (locale != 'en') 'en']) {
      final table = fileData[loc]?[file] ?? data[loc];
      if (table == null) continue;
      for (final k in _candidates(key)) {
        final hit = table[k];
        if (hit != null) return KbEntry.fromJson(hit);
      }
    }
    return null;
  }

  /// 去引号、去首尾空白、转小写。
  static String _norm(String key) =>
      key.replaceAll('"', '').trim().toLowerCase();

  /// 查找候选键。videoconfig 解析产出 `setting.fps_max` 这类带前缀键，
  /// autoexec 产出裸 cvar 名（`fps_max`）；两个形态互相尝试，
  /// 保证跨文件类型（如 videoconfig 中出现帧率上限写法）也能命中。
  static List<String> _candidates(String key) {
    final k = _norm(key);
    const prefix = 'setting.';
    if (k.startsWith(prefix)) {
      return [k, k.substring(prefix.length)];
    }
    return [k, '$prefix$k'];
  }
}
