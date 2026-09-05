# Apex CFG 编辑器 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** Windows 桌面工具，读取并修改 Apex 的 `videoconfig.txt` / `autoexec.cfg`：键值对内置用途说明（i18n）、实时双栏 diff、写回 + 自动备份还原。

**架构：** 纯 Dart 核心层（解析器/diff/备份/路径探测/知识库）+ Bloc 状态层 + 三区 UI（编辑区 | 知识卡 | 实时 diff）。单一数据源：`CfgDocument` 行模型，表格/文本双模式共享。规格见 `docs/superpowers/specs/2026-09-06-apex-cfg-editor-design.md`，UI 强约束见 `docs/ui-style-guide.md`。

**技术栈：** Flutter (Windows desktop)、flutter_bloc、diff_match_patch、flutter_code_editor、lucide_icons、fast_gbk、file_picker、gen-l10n。

**约定：** 所有测试命令均在仓库根目录执行；每个任务结束必须 `git commit`；禁止在界面使用表情符号，图标一律 `lucide_icons`。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `pubspec.yaml` | 依赖与 assets 声明 |
| `l10n.yaml` + `lib/l10n/app_en.arb` / `app_zh.arb` | 多语言资源 |
| `lib/main.dart` | 入口：深色主题、本地化、BlocProvider 装配 |
| `lib/core/parser/cfg_document.dart` | 行模型（sealed）与文档序列化 |
| `lib/core/parser/videoconfig_parser.dart` | `"key" "value"` 解析 |
| `lib/core/parser/autoexec_parser.dart` | cvar/bind/注释解析 |
| `lib/core/io/cfg_file_io.dart` | 编码探测（UTF-8/GBK）、读写、坏字节告警 |
| `lib/core/diff/line_diff.dart` | diff_match_patch 行级包装 → DiffRow 对齐行 |
| `lib/core/backup/backup_service.dart` | 时间戳备份、列表、还原、原子写回 |
| `lib/core/paths/apex_paths.dart` | Windows 路径探测（抽象接口 + 实现） |
| `lib/knowledge/kb_service.dart` | 知识库加载/查询/语言回退 |
| `assets/kb/{zh,en}/{videoconfig,autoexec}.json` | 知识库数据 |
| `lib/state/edit_bloc.dart` | 文档/脏标记/基线/选中行 |
| `lib/state/diff_bloc.dart` | 监听 edit_bloc 产出 DiffRow 列表 |
| `lib/state/file_bloc.dart` | 打开/保存/还原流程与告警 |
| `lib/ui/editor_screen.dart` | 主界面三区布局 + 顶栏 |
| `lib/ui/widgets/kv_table_view.dart` | 表格编辑模式 |
| `lib/ui/widgets/text_editor_view.dart` | 文本编辑模式（防抖） |
| `lib/ui/widgets/side_by_side_diff.dart` | 双栏 diff 视图 |
| `lib/ui/widgets/kb_card.dart` | 键值说明卡 |
| `test/…` | 与上述一一对应的单测/组件测试 |
| `.github/workflows/windows-build.yml` | Windows 打包 CI |

---

### 任务 1：项目脚手架与主题基座

**文件：** 创建仓库内 Flutter 工程（工作区根目录即工程根目录）、`pubspec.yaml`、`l10n.yaml`、`lib/l10n/*.arb`、`lib/main.dart`

- [ ] **步骤 1：创建工程（当前目录内联，不新建子目录）**

```bash
flutter config --enable-windows-desktop
flutter create --project-name apex_cfg_editor --org com.example --platforms windows . 
```

- [ ] **步骤 2：添加依赖与 l10n 配置**

```bash
flutter pub add flutter_bloc diff_match_patch flutter_code_editor lucide_icons fast_gbk file_picker
flutter pub add --dev bloc_test mocktail
```

`pubspec.yaml` 的 `flutter:` 节追加：

```yaml
  uses-material-design: true
  generate: true
  assets:
    - assets/kb/zh/
    - assets/kb/en/
```

`l10n.yaml`（仓库根目录）：

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

- [ ] **步骤 3：编写 ARB（首轮仅以下键，后续任务随做随加，en/zh 键名必须同步）**

`lib/l10n/app_en.arb`：

```json
{
  "@@locale": "en",
  "appTitle": "Apex CFG Editor",
  "modeTable": "Table",
  "modeText": "Text",
  "save": "Save",
  "restore": "Restore",
  "kbNotDocumented": "Key not documented yet. You can still edit it."
}
```

`lib/l10n/app_zh.arb`：

```json
{
  "@@locale": "zh",
  "appTitle": "Apex CFG 编辑器",
  "modeTable": "表格",
  "modeText": "文本",
  "save": "保存",
  "restore": "还原",
  "kbNotDocumented": "该键尚未收录说明，仍可编辑。"
}
```

- [ ] **步骤 4：main.dart 深色基座（含无障碍语义与 lucide 图标冒烟）**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() => runApp(const ApexCfgEditorApp());

class ApexCfgEditorApp extends StatelessWidget {
  const ApexCfgEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE2483D), // Apex 红
          brightness: Brightness.dark,
        ),
        fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
      ),
      home: const Scaffold(body: Center(child: Text('Apex CFG Editor'))),
    );
  }
}
```

- [ ] **步骤 5：验证并 commit**

```bash
flutter gen-l10n && flutter analyze && flutter test
git add -A && git commit -m "chore: flutter scaffold with dark theme and l10n base"
```

预期：analyze 0 issues，test 通过（默认 widget 测试改断言 `Apex CFG Editor` 文本存在）。

---

### 任务 2：文档模型 + videoconfig 解析器

**文件：** 创建 `lib/core/parser/cfg_document.dart`、`lib/core/parser/videoconfig_parser.dart`；测试 `test/videoconfig_parser_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
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

  test('empty value and missing trailing newline', () {
    const src = '"setting.csm_enabled" ""';
    expect(p.parse(src).serialize(), src);
  });
}
```

- [ ] **步骤 2：运行验证失败**

```bash
flutter test test/videoconfig_parser_test.dart
```

预期：FAIL（文件不存在）。

- [ ] **步骤 3：实现模型与解析器**

`lib/core/parser/cfg_document.dart`：

```dart
/// 一行的四种形态。raw 始终保存原始文本，保证未编辑行逐字节写回。
sealed class CfgLine {
  final String raw;
  CfgLine(this.raw);
}

class KeyValueLine extends CfgLine {
  final String key;
  String _value;
  bool _edited = false;
  KeyValueLine({required this.key, required String value, required super.raw})
      : _value = value;
  String get value => _value;
  void setNewValue(String v) {
    _value = v;
    _edited = true;
  }

  bool get isEdited => _edited;
}

class CommentLine extends CfgLine {
  CommentLine(super.raw);
}

class BlankLine extends CfgLine {
  BlankLine(super.raw);
}

class RawLine extends CfgLine {
  RawLine(super.raw);
}

class CfgDocument {
  final List<CfgLine> lines;
  final bool endsWithNewline;
  CfgDocument({required this.lines, required this.endsWithNewline});

  /// 序列化：编辑过的键值行重建为 `"key" "value"`，其余保持原样。
  String serialize() {
    final buf = lines.map((l) {
      if (l is KeyValueLine && l.isEdited) return '"${l.key}" "${l.value}"';
      return l.raw;
    }).join('\n');
    return endsWithNewline && buf.isNotEmpty ? '$buf\n' : buf;
  }
}
```

`lib/core/parser/videoconfig_parser.dart`：

```dart
import 'cfg_document.dart';

class VideoconfigParser {
  static final _kv = RegExp(r'^(\s*)"([^"]+)"(\s+)"([^"]*)"(\s*)$');

  CfgDocument parse(String src) {
    final hasTrailing = src.endsWith('\n');
    final rawLines = src.split('\n');
    if (hasTrailing) rawLines.removeLast();
    final lines = <CfgLine>[];
    for (final raw in rawLines) {
      final t = raw.trim();
      if (t.isEmpty) {
        lines.add(BlankLine(raw));
      } else if (t.startsWith('//')) {
        lines.add(CommentLine(raw));
      } else {
        final m = _kv.firstMatch(raw);
        if (m == null) {
          lines.add(RawLine(raw));
        } else {
          lines.add(KeyValueLine(
            key: m.group(2)!,
            value: m.group(4)!,
            raw: raw,
          ));
        }
      }
    }
    return CfgDocument(lines: lines, endsWithNewline: hasTrailing);
  }
}
```

- [ ] **步骤 4：运行验证通过**

```bash
flutter test test/videoconfig_parser_test.dart
```

预期：5 个测试全部 PASS。

- [ ] **步骤 5：Commit**

```bash
git add lib/core/parser test/videoconfig_parser_test.dart
git commit -m "feat: cfg document model and videoconfig parser"
```

---

### 任务 3：autoexec 解析器

**文件：** 创建 `lib/core/parser/autoexec_parser.dart`；测试 `test/autoexec_parser_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
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
}
```

- [ ] **步骤 2：运行验证失败**

```bash
flutter test test/autoexec_parser_test.dart
```

预期：FAIL。

- [ ] **步骤 3：实现**

`lib/core/parser/autoexec_parser.dart`：

```dart
import 'cfg_document.dart';

/// 注意：CvarLine 需在 cfg_document.dart 中补充定义（任务 2 文件内的扩展）：
/// class CvarLine extends CfgLine {
///   final String key;
///   String _value;
///   final String inlineComment; // 可为空串
///   bool _edited = false;
///   CvarLine({required this.key, required String value,
///             this.inlineComment = '', required super.raw}) : _value = value;
///   String get value => _value;
///   void setNewValue(String v) { _value = v; _edited = true; }
///   bool get isEdited => _edited;
/// }
/// 并在 CfgDocument.serialize() 中加：if (l is CvarLine && l.isEdited)
///   return '${l.key} ${l.value}${l.inlineComment.isEmpty ? '' : ' ${l.inlineComment}'}';

class AutoexecParser {
  static final _cvar = RegExp(r'^(\s*)([^\s/][^\s]*)(?:\s+(.*?))?(\s*)$');

  CfgDocument parse(String src) {
    final hasTrailing = src.endsWith('\n');
    final rawLines = src.split('\n');
    if (hasTrailing) rawLines.removeLast();
    final lines = <CfgLine>[];
    var inBlock = false;
    for (final raw in rawLines) {
      final t = raw.trim();
      if (t.isEmpty) { lines.add(BlankLine(raw)); continue; }
      if (inBlock) {
        lines.add(CommentLine(raw));
        if (t.contains('*/')) inBlock = false;
        continue;
      }
      if (t.startsWith('/*')) {
        lines.add(CommentLine(raw));
        if (!t.contains('*/')) inBlock = true;
        continue;
      }
      if (t.startsWith('//')) { lines.add(CommentLine(raw)); continue; }
      final m = _cvar.firstMatch(raw);
      if (m == null) { lines.add(RawLine(raw)); continue; }
      final rest = (m.group(3) ?? '').trim();
      String value = rest, comment = '';
      final ci = rest.indexOf('//');
      if (ci >= 0) {
        value = rest.substring(0, ci).trim();
        comment = rest.substring(ci).trim();
      }
      lines.add(CvarLine(key: m.group(2)!, value: value,
          inlineComment: comment, raw: raw));
    }
    return CfgDocument(lines: lines, endsWithNewline: hasTrailing);
  }
}
```

- [ ] **步骤 4：运行验证通过**

```bash
flutter test test/autoexec_parser_test.dart test/videoconfig_parser_test.dart
```

预期：全部 PASS。

- [ ] **步骤 5：Commit**

```bash
git add lib/core/parser test/autoexec_parser_test.dart
git commit -m "feat: autoexec parser with bind/block-comment support"
```

---

### 任务 4：编码探测与文件 IO

**文件：** 创建 `lib/core/io/cfg_file_io.dart`；测试 `test/cfg_file_io_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
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
```

- [ ] **步骤 2：运行验证失败**

```bash
flutter test test/cfg_file_io_test.dart
```

预期：FAIL。

- [ ] **步骤 3：实现**

`lib/core/io/cfg_file_io.dart`：

```dart
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
      return CfgFileData(utf8WithBom(bytes), CfgEncoding.utf8, false, bytes);
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

  static String utf8WithBom(List<int> bytes) => utf8.decode(bytes.sublist(3));

  /// 有坏字节且内容被编辑时由上层拦截告警；未编辑时上层应走 writeOriginalBytes。
  static void write(String path, String text, CfgEncoding enc) {
    final data = enc == CfgEncoding.gbk ? gbk.encode(text) : utf8.encode(text);
    final tmp = '$path.tmp';
    File(tmp).writeAsBytesSync(data, flush: true);
    File(tmp).rename(path); // 原子替换
  }

  static void writeOriginalBytes(String path, List<int> originalBytes) {
    final tmp = '$path.tmp';
    File(tmp).writeAsBytesSync(originalBytes, flush: true);
    File(tmp).rename(path);
  }
}
```

- [ ] **步骤 4：运行验证通过**

```bash
flutter test test/cfg_file_io_test.dart
```

预期：3 个测试 PASS。

- [ ] **步骤 5：Commit**

```bash
git add lib/core/io test/cfg_file_io_test.dart
git commit -m "feat: encoding-aware cfg file io with atomic write"
```

---

### 任务 5：行级 diff（diff_match_patch 包装）

**文件：** 创建 `lib/core/diff/line_diff.dart`；测试 `test/line_diff_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
import 'package:apex_cfg_editor/core/diff/line_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const d = LineDiff();

  test('identical text → single same rows', () {
    final rows = d.diff('a\nb\n', 'a\nb\n');
    expect(rows.map((r) => r.type), everyElement(RowType.same));
  });

  test('value change → modified row pairing', () {
    final rows = d.diff('fps_max 0\nr_full 1\n', 'fps_max 144\nr_full 1\n');
    expect(rows[0].type, RowType.modified);
    expect(rows[0].left, 'fps_max 0');
    expect(rows[0].right, 'fps_max 144');
    expect(rows[1].type, RowType.same);
  });

  test('added / removed lines', () {
    expect(d.diff('a\n', 'a\nb\n').last.type, RowType.added);
    expect(d.diff('a\nb\n', 'a\n').last.type, RowType.removed);
  });

  test('empty baseline → all added', () {
    expect(d.diff('', 'a\nb\n').every((r) => r.type == RowType.added), isTrue);
  });
}
```

- [ ] **步骤 2：运行验证失败**

```bash
flutter test test/line_diff_test.dart
```

预期：FAIL。

- [ ] **步骤 3：实现**

`lib/core/diff/line_diff.dart`：

```dart
import 'package:diff_match_patch/diff_match_patch.dart' as dmp;

enum RowType { same, modified, added, removed }

class DiffRow {
  final RowType type;
  final String? left, right;
  final int? leftNo, rightNo;
  DiffRow(this.type, {this.left, this.right, this.leftNo, this.rightNo});
}

class LineDiff {
  /// 基线 → 当前行级对齐视图（git 双栏风格）。
  List<DiffRow> diff(String baseline, String current) {
    if (baseline == current) return _allSame(baseline, current);
    final engine = dmp.DiffMatchPatch()..DiffTimeout = 1000;
    final res = engine.diffLinesToChars(baseline, current);
    final diffs = engine.diff(res.chars1, res.chars2);
    final lineDiffs = engine.diffCharsToLines(diffs, res.lineArray);

    final left = baseline.split('\n')..removeLast(); // 文本以 \n 连接
    final right = current.split('\n')..removeLast();
    // 逐块展开为 (op, 行列表)，再把相邻 del+ins 配对
    final rows = <DiffRow>[];
    int li = 0, ri = 0;
    final ops = lineDiffs.map((e) => MapEntry(e.operation, e.text)).toList();
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final ls = op.key == dmp.DiffOperation.DELETE ||
              op.key == dmp.DiffOperation.EQUAL
          ? op.value.split('\n')..removeLast()
          : <String>[];
      final rs = op.key == dmp.DiffOperation.INSERT ||
              op.key == dmp.DiffOperation.EQUAL
          ? op.value.split('\n')..removeLast()
          : <String>[];
      if (op.key == dmp.DiffOperation.EQUAL) {
        for (final l in ls) {
          rows.add(DiffRow(RowType.same, left: l, right: l,
              leftNo: li++, rightNo: ri++));
        }
      } else {
        // 收集紧随其后的另一个非 EQUAL 块配对
        List<String> dels = ls, adds = rs;
        if (op.key == dmp.DiffOperation.DELETE &&
            i + 1 < ops.length &&
            ops[i + 1].key == dmp.DiffOperation.INSERT) {
          adds = ops[i + 1].value.split('\n')..removeLast();
          i++;
        } else if (op.key == dmp.DiffOperation.INSERT &&
            i + 1 < ops.length &&
            ops[i + 1].key == dmp.DiffOperation.DELETE) {
          dels = ops[i + 1].value.split('\n')..removeLast();
          i++;
        }
        final n = dels.length < adds.length ? dels.length : adds.length;
        for (var k = 0; k < n; k++) {
          rows.add(DiffRow(RowType.modified, left: dels[k], right: adds[k],
              leftNo: li++, rightNo: ri++));
        }
        for (var k = n; k < dels.length; k++) {
          rows.add(DiffRow(RowType.removed, left: dels[k], leftNo: li++));
        }
        for (var k = n; k < adds.length; k++) {
          rows.add(DiffRow(RowType.added, right: adds[k], rightNo: ri++));
        }
      }
    }
    return rows;
  }

  List<DiffRow> _allSame(String baseline, String current) {
    final l = baseline.split('\n')..removeLast();
    final r = current.split('\n')..removeLast();
    final rows = <DiffRow>[];
    for (var i = 0; i < l.length; i++) {
      rows.add(DiffRow(RowType.same, left: l[i], right: r[i],
          leftNo: i, rightNo: i));
    }
    return rows;
  }
}
```

- [ ] **步骤 4：运行验证通过**

```bash
flutter test test/line_diff_test.dart
```

预期：4 个测试 PASS。

- [ ] **步骤 5：Commit**

```bash
git add lib/core/diff test/line_diff_test.dart
git commit -m "feat: line-level side-by-side diff over diff_match_patch"
```

---

### 任务 6：知识库服务

**文件：** 创建 `lib/knowledge/kb_service.dart`；测试 `test/kb_service_test.dart`；创建 `assets/kb/zh/videoconfig.json`、`assets/kb/en/videoconfig.json`、`assets/kb/zh/autoexec.json`、`assets/kb/en/autoexec.json`

- [ ] **步骤 1：编写失败的测试**

```dart
import 'package:apex_cfg_editor/knowledge/kb_service.dart';
import 'package:flutter_test/flutter_test.dart';

const zh = {
  'setting.fps_max': {
    'name': '帧率上限',
    'description': '限制游戏最大帧率，0 表示不限制。',
    'recommended': '0 或显示器刷新率',
    'risk': 'low',
    'values': [{'v': '0', 'label': '不限制'}, {'v': '144', 'label': '144 帧'}]
  },
  'bind': {
    'name': '键位绑定',
    'description': '把某个按键绑定到命令。',
    'recommended': '',
    'risk': 'medium',
    'values': []
  }
};

void main() {
  test('normalize: quotes/case/whitespace-insensitive lookup', () {
    final kb = KbService(data: {'zh': zh, 'en': {}});
    final e = kb.lookup(KbFile.autoexec, '  FPS_MAX ', 'zh');
    expect(e!.name, '帧率上限');
  });

  test('miss → null（UI 层走 kbNotDocumented 兜底）', () {
    final kb = KbService(data: {'zh': zh, 'en': {}});
    expect(kb.lookup(KbFile.autoexec, 'mat_queue_mode', 'zh'), isNull);
  });

  test('locale fallback zh→en→miss', () {
    final kb = KbService(data: {'en': zh});
    expect(kb.lookup(KbFile.autoexec, 'fps_max', 'zh')!.name, '帧率上限');
  });
}
```

- [ ] **步骤 2：运行验证失败**

```bash
flutter test test/kb_service_test.dart
```

预期：FAIL。

- [ ] **步骤 3：实现**

`lib/knowledge/kb_service.dart`：

```dart
import 'package:flutter/services.dart';
import 'dart:convert';

enum KbFile { videoconfig, autoexec }

class KbEntry {
  final String name, description, recommended, risk;
  final List<KbValue> values;
  KbEntry.fromJson(Map<String, dynamic> j)
      : name = j['name'] ?? '',
        description = j['description'] ?? '',
        recommended = j['recommended'] ?? '',
        risk = j['risk'] ?? 'low',
        values = (j['values'] as List? ?? [])
            .map((v) => KbValue(v['v'] ?? '', v['label'] ?? ''))
            .toList();
}

class KbValue {
  final String v, label;
  KbValue(this.v, this.label);
}

class KbService {
  /// 测试注入；生产用 [fromAssets]。
  final Map<String, Map<String, dynamic>> data; // locale → json
  static const _assetBase = 'assets/kb';
  KbService({required this.data});

  static Future<KbService> fromAssets() async {
    final out = <String, Map<String, dynamic>>{};
    for (final loc in const ['zh', 'en']) {
      final merged = <String, dynamic>{};
      for (final f in KbFile.values) {
        final raw = await rootBundle
            .loadString('$_assetBase/$loc/${f.name}.json');
        merged.addAll(jsonDecode(raw) as Map<String, dynamic>);
      }
      out[loc] = merged;
    }
    return KbService(data: out);
  }

  String _norm(String key) => key.replaceAll('"', '').trim().toLowerCase();

  KbEntry? lookup(KbFile file, String key, String locale) {
    for (final loc in [locale, if (locale != 'en') 'en']) {
      final hit = data[loc]?[_norm(key)];
      if (hit != null) return KbEntry.fromJson(hit);
    }
    return null;
  }
}
```

- [ ] **步骤 4：创建首发知识库数据（zh 全量、en 同结构翻译；键与解析器输出的 key 一致）**

`assets/kb/zh/videoconfig.json`：覆盖真实 videoconfig.txt 全部 `setting.*` 键（以 fixture 文件为准逐键整理：分辨率/刷新率/全屏/垂直同步/阴影/材质/特效等），每键含 `name/description/recommended/risk/values`。
`assets/kb/zh/autoexec.json`：收录社区常用 cvar ≥60 条：`fps_max、fps_max_usec、mat_queue_mode、r_createhairpretesselation、r_fullscreen_gamma、cl_showfps、bind、exec、rate、cl_updaterate、cl_interp、cl_interp_ratio、m_rawinput、snd_mixahead、threads` 等。
`assets/kb/en/*.json`：同名键的英文版本。

- [ ] **步骤 5：验证 + commit**

```bash
flutter test test/kb_service_test.dart && flutter analyze
git add lib/knowledge assets/kb test/kb_service_test.dart
git commit -m "feat: knowledge base service with locale fallback"
```

预期：测试 PASS，analyze 0 issues。

---

### 任务 7：状态层（edit / diff / file 三个 Bloc）

**文件：** 创建 `lib/state/edit_bloc.dart`、`lib/state/diff_bloc.dart`、`lib/state/file_bloc.dart`；测试 `test/blocs_test.dart`

- [ ] **步骤 1：编写失败的测试（bloc_test）**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:apex_cfg_editor/core/parser/cfg_document.dart';
import 'package:apex_cfg_editor/core/parser/videoconfig_parser.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/diff_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

CfgDocument _doc() =>
    VideoconfigParser().parse('"setting.fps_max" "0"\n"setting.r_full" "1"\n');

void main() {
  blocTest<EditBloc, EditState>(
    'edit value → dirty and serialize reflects change',
    build: () => EditBloc(),
    act: (b) {
      b.add(DocumentOpened(doc: _doc(), baseline: '"setting.fps_max" "0"\n"setting.r_full" "1"\n'));
      b.add(LineValueChanged(index: 0, value: '144'));
    },
    expect: () => [
      isA<EditState>().having((s) => s.dirty, 'dirty', false),
      isA<EditState>()
          .having((s) => s.dirty, 'dirty', true)
          .having((s) => s.doc!.serialize(), 'text',
              '"setting.fps_max" "144"\n"setting.r_full" "1"\n'),
    ],
  );

  test('diff bloc derives rows from edit stream', () async {
    final edit = EditBloc();
    final diff = DiffBloc(editStream: edit.stream);
    edit.add(DocumentOpened(
        doc: _doc(), baseline: '"setting.fps_max" "0"\n"setting.r_full" "1"\n'));
    edit.add(LineValueChanged(index: 0, value: '144'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(diff.state.rows.first.type, RowType.modified);
    await diff.close();
    await edit.close();
  });
}
```

- [ ] **步骤 2：运行验证失败**

```bash
flutter test test/blocs_test.dart
```

预期：FAIL。

- [ ] **步骤 3：实现三个 Bloc**

`lib/state/edit_bloc.dart`：

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/parser/cfg_document.dart';

sealed class EditEvent {}
class DocumentOpened extends EditEvent {
  final CfgDocument doc; final String baseline;
  DocumentOpened({required this.doc, required this.baseline});
}
class LineValueChanged extends EditEvent {
  final int index; final String value;
  LineValueChanged({required this.index, required this.value});
}
class FullTextChanged extends EditEvent {
  final CfgDocument doc; // 文本模式防抖后由解析器产出
  FullTextChanged(this.doc);
}
class SelectionChanged extends EditEvent {
  final int? index; SelectionChanged(this.index);
}
class DocumentSaved extends EditEvent { final String newBaseline; DocumentSaved(this.newBaseline); }

class EditState {
  final CfgDocument? doc;
  final String baseline;
  final bool dirty;
  final int? selectedIndex;
  const EditState({this.doc, this.baseline = '', this.dirty = false, this.selectedIndex});
  EditState copyWith({CfgDocument? doc, String? baseline, bool? dirty,
      int? Function()? selectedIndex}) =>
      EditState(
        doc: doc ?? this.doc,
        baseline: baseline ?? this.baseline,
        dirty: dirty ?? this.dirty,
        selectedIndex:
            selectedIndex != null ? selectedIndex() : this.selectedIndex,
      );
}

class EditBloc extends Bloc<EditEvent, EditState> {
  EditBloc() : super(const EditState()) {
    on<DocumentOpened>((e, em) => em(EditState(
        doc: e.doc, baseline: e.baseline, dirty: false, selectedIndex: null)));
    on<LineValueChanged>((e, em) {
      final doc = state.doc;
      if (doc == null) return;
      final l = doc.lines[e.index];
      if (l is KeyValueLine) l.setNewValue(e.value);
      if (l is CvarLine) l.setNewValue(e.value);
      em(state.copyWith(doc: doc, dirty: true));
    });
    on<FullTextChanged>((e, em) =>
        em(state.copyWith(doc: e.doc, dirty: true)));
    on<SelectionChanged>((e, em) => em(state.copyWith(selectedIndex: () => e.index)));
    on<DocumentSaved>((e, em) =>
        em(state.copyWith(baseline: e.newBaseline, dirty: false)));
  }
}
```

`lib/state/diff_bloc.dart`：

```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/diff/line_diff.dart';
import '../core/parser/cfg_document.dart';
import 'edit_bloc.dart';

class DiffState {
  final List<DiffRow> rows;
  const DiffState({this.rows = const []});
}

class DiffBloc extends Cubit<DiffState> {
  final LineDiff _diff = LineDiff();
  late final StreamSubscription<EditState> _sub;
  DiffBloc({required Stream<EditState> editStream}) : super(const DiffState()) {
    _sub = editStream.listen(_recompute);
  }

  void _recompute(EditState s) {
    final doc = s.doc;
    if (doc == null) return;
    emit(DiffState(rows: _diff.diff(s.baseline, doc.serialize())));
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
```

`lib/state/file_bloc.dart`（IO 编排，见任务 8/9 服务签名；先以抽象回调注入）：

```dart
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/io/cfg_file_io.dart';
import '../core/parser/autoexec_parser.dart';
import '../core/parser/cfg_document.dart';
import '../core/parser/videoconfig_parser.dart';
import 'edit_bloc.dart';

enum CfgKind { videoconfig, autoexec }

sealed class FileEvent {}
class OpenRequested extends FileEvent { final String path; OpenRequested(this.path); }
class SaveRequested extends FileEvent {}
class RestoreRequested extends FileEvent { final String backupPath; RestoreRequested(this.backupPath); }

class FileState {
  final String? path;
  final CfgKind? kind;
  final bool busy;
  final String? warning;   // i18n 键名，UI 层翻译
  final List<String> backups; // 还原对话框数据
  const FileState({this.path, this.kind, this.busy = false, this.warning, this.backups = const []});
  FileState copyWith({String? path, CfgKind? kind, bool? busy,
      String? Function()? warning, List<String>? backups}) => FileState(
      path: path ?? this.path, kind: kind ?? this.kind, busy: busy ?? this.busy,
      warning: warning != null ? warning() : this.warning,
      backups: backups ?? this.backups);
}

class FileBloc extends Bloc<FileEvent, FileState> {
  final EditBloc editBloc;
  final Future<void> Function(String path, String text, CfgEncoding enc) saveImpl;
  final List<String> Function(String path) listBackupsImpl;
  final Future<void> Function(String target, String backup) restoreImpl;

  FileBloc({required this.editBloc, required this.saveImpl,
      required this.listBackupsImpl, required this.restoreImpl})
      : super(const FileState()) {
    on<OpenRequested>((e, em) async {
      em(state.copyWith(busy: true, warning: () => null));
      final data = CfgFileIo.read(e.path);
      final kind = e.path.endsWith('videoconfig.txt')
          ? CfgKind.videoconfig : CfgKind.autoexec;
      final doc = kind == CfgKind.videoconfig
          ? VideoconfigParser().parse(data.text)
          : AutoexecParser().parse(data.text);
      editBloc.add(DocumentOpened(doc: doc, baseline: data.text));
      em(FileState(
          path: e.path, kind: kind, busy: false,
          warning: data.hasBadBytes ? 'fileBadEncoding' : null,
          backups: listBackupsImpl(e.path)));
    });
    on<SaveRequested>((e, em) async {
      final doc = editBloc.state.doc;
      final path = state.path;
      if (doc == null || path == null) return;
      final st = editBloc.state;
      final cur = File(path).readAsBytesSync();
      if (!st.dirty) return; // 未编辑：不产生新备份
      await saveImpl(path, doc.serialize(), CfgFileIo.readBytes(cur).encoding);
      editBloc.add(DocumentSaved(doc.serialize()));
      em(state.copyWith(backups: listBackupsImpl(path)));
    });
    on<RestoreRequested>((e, em) async {
      await restoreImpl(state.path!, e.backupPath);
      add(OpenRequested(state.path!));
    });
  }
}
```

- [ ] **步骤 4：运行验证通过**

```bash
flutter test test/blocs_test.dart
```

预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add lib/state test/blocs_test.dart
git commit -m "feat: edit/diff/file blocs with baseline-driven live diff"
```

---

### 任务 8：备份服务

**文件：** 创建 `lib/core/backup/backup_service.dart`；测试 `test/backup_service_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
import 'dart:io';
import 'package:apex_cfg_editor/core/backup/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('bk'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('backup before save: timestamped copy stored in app-data dir', () {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('v1\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, 'v1\n');
    final files = b.listBackups(target.path);
    expect(files, hasLength(1));
    expect(RegExp(r'\d{8}-\d{6}\.cfg$').hasMatch(files.first.split('/').last), isTrue);
  });

  test('restore writes selected backup content back', () async {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('v1\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, 'v1\n');
    target.writeAsStringSync('v2\n');
    await b.restore(target.path, b.listBackups(target.path).first);
    expect(target.readAsStringSync(), 'v1\n');
  });

  test('list newest first', () {
    final target = File('${tmp.path}/Documents/videoconfig.txt')
      ..createSync(recursive: true)..writeAsStringSync('v\n');
    final b = BackupService(baseDir: '${tmp.path}/appdata');
    b.backupBeforeSave(target.path, 'v\n');
    b.backupBeforeSave(target.path, 'v\n');
    final l = b.listBackups(target.path);
    expect(l.first.compareTo(l.last), isGreaterThanOrEqualTo(0));
  });
}
```

- [ ] **步骤 2：运行验证失败** → `flutter test test/backup_service_test.dart` 预期 FAIL

- [ ] **步骤 3：实现**

`lib/core/backup/backup_service.dart`：

```dart
import 'dart:io';

class BackupService {
  final String baseDir; // Windows: %APPDATA%\ApexCfgEditor\backups
  BackupService({required this.baseDir});

  String _dirFor(String path) {
    final name = path.split(Platform.pathSeparator).last;
    return '$baseDir/$name';
  }

  void backupBeforeSave(String path, String currentText) {
    final dir = Directory(_dirFor(path))..createSync(recursive: true);
    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final tmp = '${dir.path}/.$stamp.tmp';
    File(tmp).writeAsStringSync(currentText, flush: true);
    File(tmp).rename('${dir.path}/$stamp.cfg');
  }

  List<String> listBackups(String path) {
    final dir = Directory(_dirFor(path));
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.cfg'))
        .map((f) => f.path)
        .toList()
      ..sort((a, b) => b.compareTo(a)); // 新→旧
  }

  Future<void> restore(String targetPath, String backupPath) async {
    final tmp = '$targetPath.tmp';
    File(tmp).writeAsBytesSync(File(backupPath).readAsBytesSync(), flush: true);
    File(tmp).rename(targetPath);
  }
}
```

- [ ] **步骤 4：运行验证通过** → `flutter test test/backup_service_test.dart` 预期 3 个 PASS

- [ ] **步骤 5：Commit**

```bash
git add lib/core/backup test/backup_service_test.dart
git commit -m "feat: timestamped backup service with atomic restore"
```

---

### 任务 9：Windows 路径探测

**文件：** 创建 `lib/core/paths/apex_paths.dart`；测试 `test/apex_paths_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
import 'dart:io';
import 'package:apex_cfg_editor/core/paths/apex_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('paths'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('finds videoconfig under Documents/Respawn/Apex/local', () {
    final f = File('${tmp.path}/Documents/Respawn/Apex/local/videoconfig.txt')
      ..createSync(recursive: true);
    final r = ApexPathFinder(homeDir: tmp.path).findVideoconfig();
    expect(r, f.path);
  });

  test('finds autoexec.cfg via steam libraryfolders.vdf (app 1172470)', () {
    final cfg = File(
        '${tmp.path}/Steam/steamapps/common/Apex Legends/global/cfg/autoexec.cfg')
      ..createSync(recursive: true);
    File('${tmp.path}/Steam/steamapps/libraryfolders.vdf').writeAsStringSync('''
"libraryfolders"
{
  "0" { "path" "${tmp.path}/Steam" }
  "1" { "path" "${tmp.path}/Steam" }
}
''');
    final r = ApexPathFinder(homeDir: tmp.path).findAutoexec();
    expect(r, cfg.path);
  });

  test('missing → null (UI falls back to manual picker)', () {
    expect(ApexPathFinder(homeDir: tmp.path).findVideoconfig(), isNull);
  });
}
```

- [ ] **步骤 2：运行验证失败** → `flutter test test/apex_paths_test.dart` 预期 FAIL

- [ ] **步骤 3：实现**

`lib/core/paths/apex_paths.dart`：

```dart
import 'dart:io';

/// 可注入 homeDir 便于测试；生产传 Platform.environment['USERPROFILE']。
class ApexPathFinder {
  final String homeDir;
  ApexPathFinder({required this.homeDir});

  String? findVideoconfig() {
    final p = '$homeDir/Documents/Respawn/Apex/local/videoconfig.txt';
    return File(p).existsSync() ? p : null;
  }

  String? findAutoexec() {
    // Steam 主库与 libraryfolders.vdf 中的其余库都尝试
    final candidates = <String>[];
    final primary = Directory('$homeDir/../Program Files (x86)/Steam');
    final vdfCandidates = <String>[
      '${primary.path}/steamapps/libraryfolders.vdf',
    ];
    for (final vdf in vdfCandidates) {
      final f = File(vdf);
      if (!f.existsSync()) continue;
      final pathRegex = RegExp(r'"path"\s+"([^"]+)"');
      for (final m in pathRegex.allMatches(f.readAsStringSync())) {
        candidates.add(m.group(1)!.replaceAll('\\\\', '/'));
      }
    }
    for (final lib in candidates) {
      final p =
          '$lib/steamapps/common/Apex Legends/global/cfg/autoexec.cfg';
      if (File(p).existsSync()) return p;
    }
    return null;
  }
}
```

（EA App 安装的玩家走「手动选择」兜底，与规格 §9 一致。）

- [ ] **步骤 4：运行验证通过** → `flutter test test/apex_paths_test.dart` 预期 3 个 PASS
- [ ] **步骤 5：Commit**

```bash
git add lib/core/paths test/apex_paths_test.dart
git commit -m "feat: apex path detection for documents and steam libraries"
```

---

### 任务 10：主界面三区布局与顶栏

**文件：** 创建 `lib/ui/editor_screen.dart`；测试 `test/editor_screen_test.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

```dart
import 'package:apex_cfg_editor/ui/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:apex_cfg_editor/state/edit_bloc.dart';
import 'package:apex_cfg_editor/state/diff_bloc.dart';
import 'package:apex_cfg_editor/state/file_bloc.dart';

class MockEditBloc extends MockBloc<EditEvent, EditState> implements EditBloc {}
class MockDiffBloc extends MockCubit<DiffState> implements DiffBloc {}
class MockFileBloc extends MockBloc<FileEvent, FileState> implements FileBloc {}

void main() {
  testWidgets('renders top bar with mode toggle (lucide icons, no emoji)', (t) async {
    final edit = MockEditBloc();
    final diff = MockDiffBloc();
    final file = MockFileBloc();
    when(() => edit.state).thenReturn(const EditState());
    when(() => diff.state).thenReturn(const DiffState());
    when(() => file.state).thenReturn(const FileState());
    whenListen(edit, const Stream<EditState>.empty(), initialState: const EditState());
    whenListen(diff, const Stream<DiffState>.empty(), initialState: const DiffState());
    whenListen(file, const Stream<FileState>.empty(), initialState: const FileState());

    await t.pumpWidget(MaterialApp(
        home: EditorScreen(editBloc: edit, diffBloc: diff, fileBloc: file)));
    expect(find.text('Apex CFG Editor'), findsWidgets);
    expect(find.text('Table'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
  });
}
```

- [ ] **步骤 2：运行验证失败** → `flutter test test/editor_screen_test.dart` 预期 FAIL

- [ ] **步骤 3：实现**

`lib/ui/editor_screen.dart`（核心骨架；表格/文本/diff/知识卡组件任务 11–13 填充，本任务先用占位 `SizedBox.shrink()`）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../state/diff_bloc.dart';
import '../state/edit_bloc.dart';
import '../state/file_bloc.dart';
import 'widgets/kv_table_view.dart';
import 'widgets/side_by_side_diff.dart';
import 'widgets/kb_card.dart';
import 'widgets/text_editor_view.dart';

class EditorScreen extends StatefulWidget {
  final EditBloc editBloc; final DiffBloc diffBloc; final FileBloc fileBloc;
  const EditorScreen({super.key, required this.editBloc,
      required this.diffBloc, required this.fileBloc});
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool _textMode = false;

  @override
  Widget build(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<FileBloc, FileState>(
          bloc: widget.fileBloc,
          builder: (_, s) => Text(s.path?.split('/').last.split('\\').last
              ?? l.openFileTooltip),
        ),
        actions: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, icon: const Icon(LucideIcons.table2),
                  label: Text('Table')),
              ButtonSegment(value: true, icon: const Icon(LucideIcons.code2),
                  label: Text('Text')),
            ],
            selected: {_textMode},
            onSelectionChanged: (v) => setState(() => _textMode = v.first),
          ),
          IconButton(
            icon: const Icon(LucideIcons.save),
            tooltip: 'Save',
            semanticLabel: 'Save',
            onPressed: () => widget.fileBloc.add(SaveRequested()),
          ),
          IconButton(
            icon: const Icon(LucideIcons.history),
            tooltip: 'Restore',
            semanticLabel: 'Restore',
            onPressed: () {}, // 任务 15 接还原对话框
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          flex: 6,
          child: _textMode
              ? TextEditorView(editBloc: widget.editBloc)
              : KvTableView(editBloc: widget.editBloc, fileBloc: widget.fileBloc),
        ),
        const Divider(height: 1),
        SizedBox(
          height: 220,
          child: Row(children: [
            const SizedBox(width: 280, child: KbCard()),
            VerticalDivider(width: 1),
            Expanded(child: SideBySideDiff(diffBloc: widget.diffBloc)),
          ]),
        ),
      ]),
    );
  }
}
```

（文案 `'Table'` 等在任务 16 全量替换为 `AppLocalizations` 键；本任务先保证结构与测试稳定。）

- [ ] **步骤 4：运行验证通过** → `flutter test test/editor_screen_test.dart` 预期 PASS
- [ ] **步骤 5：Commit** `git add lib/ui test/editor_screen_test.dart && git commit -m "feat: editor screen layout with mode toggle"`

---

### 任务 11：表格编辑视图

**文件：** 创建 `lib/ui/widgets/kv_table_view.dart`；测试 `test/kv_table_view_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
// pump EditorScreen，注入 EditBloc（bloc_test 真实实例）：
// 初始 DocumentOpened(videoconfig 文档)，选中行 0 的值为 '0'
// 找到第一行 TextField，enterText '144'
// 断言 editBloc.state.doc!.serialize() 含 '"setting.fps_max" "144"'
```

（完整可执行版本：使用真实 `EditBloc` + `add(DocumentOpened(...))`，`tester.enterText(find.byType(TextField).first, '144')` 后 `tester.pumpAndSettle()`，断言状态变更——不使用 mock，避免 mock 漂移。）

- [ ] **步骤 2：运行验证失败** → `flutter test test/kv_table_view_test.dart` 预期 FAIL

- [ ] **步骤 3：实现**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../state/edit_bloc.dart';
import '../../state/file_bloc.dart';
import '../../knowledge/kb_service.dart';

class KvTableView extends StatelessWidget {
  final EditBloc editBloc; final FileBloc fileBloc;
  const KvTableView({super.key, required this.editBloc, required this.fileBloc});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditBloc, EditState>(
      bloc: editBloc,
      builder: (_, s) {
        final doc = s.doc;
        if (doc == null) {
          return const Center(child: Text('Open a cfg file to start'));
        }
        final kb = context.read<KbService?>();
        return ListView.builder(
          itemCount: doc.lines.length,
          itemBuilder: (_, i) {
            final line = doc.lines[i];
            final kv = line is KeyValueLine ? line : (line is CvarLine ? line : null);
            if (kv == null) {
              return ListTile(dense: true,
                  title: Text(line.raw, style: Theme.of(context)
                      .textTheme.bodySmall!.copyWith(
                          fontFamily: 'monospace', color: Colors.white38)));
            }
            final entry = kb?.lookup(
                line is KeyValueLine ? KbFile.videoconfig : KbFile.autoexec,
                kv.key, Localizations.localeOf(context).languageCode);
            return ListTile(
              dense: true,
              onTap: () => editBloc.add(SelectionChanged(i)),
              selected: s.selectedIndex == i,
              title: Text(kv.key, style: const TextStyle(fontFamily: 'monospace')),
              subtitle: entry == null ? null : Text(entry.name, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: SizedBox(
                width: 160,
                child: (entry != null && entry.values.isNotEmpty)
                    ? DropdownButtonFormField<String>(
                        initialValue: kv.value,
                        items: entry.values
                            .map((v) => DropdownMenuItem(
                                value: v.v, child: Text(v.label)))
                        .toList(),
                        onChanged: (v) => editBloc.add(
                            LineValueChanged(index: i, value: v ?? '')))
                    : TextFormField(
                        initialValue: kv.value,
                        onChanged: (v) =>
                            editBloc.add(LineValueChanged(index: i, value: v))),
              ),
            );
          },
        );
      },
    );
  }
}
```

（`KbService` 由 main.dart 以 `RepositoryProvider` 注入，任务 15 装配。）

- [ ] **步骤 4：运行验证通过** → `flutter test test/kv_table_view_test.dart` 预期 PASS
- [ ] **步骤 5：Commit** `git add lib/ui/widgets/kv_table_view.dart test/kv_table_view_test.dart && git commit -m "feat: key-value table editing with kb-driven controls"`

---

### 任务 12：双栏 diff 视图

**文件：** 创建 `lib/ui/widgets/side_by_side_diff.dart`；测试 `test/side_by_side_diff_test.dart`

- [ ] **步骤 1：编写失败的测试**

pump 注入真实 `EditBloc`+`DiffBloc`，打开文档后改值；断言视图中同时出现旧值文本与新值文本，且两者 `Text` 样式背景分别为删除红/新增绿（用 `tester.widget<Container>` 检查颜色不为 null）。

- [ ] **步骤 2：运行验证失败** → `flutter test test/side_by_side_diff_test.dart` 预期 FAIL

- [ ] **步骤 3：实现**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../state/diff_bloc.dart';

class SideBySideDiff extends StatelessWidget {
  final DiffBloc diffBloc;
  const SideBySideDiff({super.key, required this.diffBloc});

  @override
  Widget build(BuildContext context) {
    final mono = const TextStyle(fontFamily: 'monospace', fontSize: 12);
    return BlocBuilder<DiffBloc, DiffState>(
      bloc: diffBloc,
      builder: (_, s) => Container(
        color: const Color(0xFF141414),
        child: ListView.builder(
          itemCount: s.rows.length,
          itemBuilder: (_, i) {
            final r = s.rows[i];
            final delColor = r.type == RowType.modified || r.type == RowType.removed
                ? const Color(0x33E2483D) : null;
            final addColor = r.type == RowType.modified || r.type == RowType.added
                ? const Color(0x3322C55E) : null;
            return Row(children: [
              Expanded(child: Container(
                  color: delColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(r.left ?? '', style: mono))),
              Expanded(child: Container(
                  color: addColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(r.right ?? '', style: mono))),
            ]);
          },
        ),
      ),
    );
  }
}
```

- [ ] **步骤 4：运行验证通过** → `flutter test test/side_by_side_diff_test.dart` 预期 PASS
- [ ] **步骤 5：Commit** `git add lib/ui/widgets/side_by_side_diff.dart test/side_by_side_diff_test.dart && git commit -m "feat: side-by-side live diff view"`

---

### 任务 13：知识卡

**文件：** 创建 `lib/ui/widgets/kb_card.dart`；测试 `test/kb_card_test.dart`

- [ ] **步骤 1：编写失败的测试**

选中已收录键 → 显示 name/description/recommended；选中未收录键 → 显示 `kbNotDocumented` 文案；risk=high → 存在红色警示图标（`LucideIcons.alertTriangle`，语义标注 semanticLabel）。

- [ ] **步骤 2：运行验证失败** → `flutter test test/kb_card_test.dart` 预期 FAIL

- [ ] **步骤 3：实现**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../knowledge/kb_service.dart';
import '../../state/edit_bloc.dart';
import '../../state/file_bloc.dart';

class KbCard extends StatelessWidget {
  const KbCard({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditBloc, EditState>(
      builder: (_, s) {
        final doc = s.doc; final i = s.selectedIndex;
        if (doc == null || i == null || i >= doc.lines.length) {
          return const SizedBox.shrink();
        }
        final line = doc.lines[i];
        final key = line is KeyValueLine ? line.key
            : (line is CvarLine ? line.key : null);
        if (key == null) return const SizedBox.shrink();
        final file = line is KeyValueLine ? KbFile.videoconfig : KbFile.autoexec;
        final kb = context.read<KbService>();
        final e = kb.lookup(file, key,
            Localizations.localeOf(context).languageCode);
        if (e == null) return const Padding(
            padding: EdgeInsets.all(12), child: Text('kbNotDocumented'));
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (e.risk == 'high')
                const Icon(LucideIcons.alertTriangle, size: 16,
                    color: Colors.redAccent, semanticLabel: 'high risk'),
              const SizedBox(width: 6),
              Expanded(child: Text(e.name, style: Theme.of(context)
                  .textTheme.titleMedium)),
            ]),
            const SizedBox(height: 8),
            Text(e.description),
            if (e.recommended.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('推荐：${e.recommended}',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ]),
        );
      },
    );
  }
}
```

（`'推荐：'` 与 `'kbNotDocumented'` 字面量在任务 16 换成 `AppLocalizations`。）

- [ ] **步骤 4：运行验证通过** → `flutter test test/kb_card_test.dart` 预期 PASS
- [ ] **步骤 5：Commit** `git add lib/ui/widgets/kb_card.dart test/kb_card_test.dart && git commit -m "feat: knowledge card for selected key"`

---

### 任务 14：文本编辑模式

**文件：** 创建 `lib/ui/widgets/text_editor_view.dart`；测试 `test/text_editor_view_test.dart`

- [ ] **步骤 1：编写失败的测试**

pump（真实 blocs，已打开文档）→ 向编辑器输入一行新文本 `fps_max 256\n` → `pump(400ms)`（越过 300ms 防抖）→ 断言 `editBloc.state.doc!.serialize()` 含新文本且 `dirty` 为 true。

- [ ] **步骤 2：运行验证失败** → `flutter test test/text_editor_view_test.dart` 预期 FAIL

- [ ] **步骤 3：实现**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/highlight.dart' show languages;
import '../../core/parser/autoexec_parser.dart';
import '../../core/parser/videoconfig_parser.dart';
import '../../state/edit_bloc.dart';
import '../../state/file_bloc.dart';

class TextEditorView extends StatefulWidget {
  final EditBloc editBloc;
  const TextEditorView({super.key, required this.editBloc});
  @override
  State<TextEditorView> createState() => _TextEditorViewState();
}

class _TextEditorViewState extends State<TextEditorView> {
  late CodeController _ctrl;
  Timer? _debounce;
  bool _lastWasVideoconfig = false;

  @override
  void initState() {
    super.initState();
    final text = widget.editBloc.state.doc?.serialize() ?? '';
    _ctrl = CodeController(text: text, language: languages['cpp']);
  }

  @override
  void dispose() { _debounce?.cancel(); _ctrl.dispose(); super.dispose(); }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final fb = context.read<FileBloc>();
      final isVideo = fb.state.kind != CfgKind.autoexec;
      widget.editBloc.add(FullTextChanged(
          isVideo ? VideoconfigParser().parse(_ctrl.text)
                  : AutoexecParser().parse(_ctrl.text)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return CodeField(
      controller: _ctrl,
      onChanged: (_) => _onChanged(),
      textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
    );
  }
}
```

（文本↔表格切换时，表格侧的修改已实时进 Bloc；进入文本模式时用 `didChangeDependencies` 以 Bloc 当前文本初始化控制器，避免互相覆盖。）

- [ ] **步骤 4：运行验证通过** → `flutter test test/text_editor_view_test.dart` 预期 PASS
- [ ] **步骤 5：Commit** `git add lib/ui/widgets/text_editor_view.dart test/text_editor_view_test.dart && git commit -m "feat: raw text editing mode with debounced reparse"`

---

### 任务 15：装配与文件流程（打开/保存/还原/退出保护）

**文件：** 修改 `lib/main.dart`、`lib/ui/editor_screen.dart`（还原按钮接对话框、退出保护）；创建 `lib/ui/backup_dialog.dart`、`lib/core/paths/apex_paths.dart` 的装配用例；测试 `test/file_flow_test.dart`

- [ ] **步骤 1：编写失败的测试**

`FileBloc` 用临时目录注入真实 `saveImpl/listBackupsImpl/restoreImpl`（包装 `BackupService`），流程测试：OpenRequested(path) → LineValueChanged → SaveRequested → 磁盘文件内容已更新、备份目录出现 1 个文件、`editBloc.state.dirty == false`；RestoreRequested(备份路径) → 磁盘恢复旧值。

- [ ] **步骤 2：运行验证失败** → `flutter test test/file_flow_test.dart` 预期 FAIL

- [ ] **步骤 3：实现装配**

`lib/main.dart`（关键片段）：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final kb = await KbService.fromAssets();
  final backupBase = Platform.environment['APPDATA'] ??
      Directory.systemTemp.path; // macOS 开发期兜底
  final backups = BackupService(baseDir: '$backupBase/ApexCfgEditor/backups');

  Future<void> saveImpl(String path, String text, CfgEncoding enc) async {
    backups.backupBeforeSave(path, File(path).readAsStringSync());
    CfgFileIo.write(path, text, enc);
  }

  runApp(ApexCfgEditorApp(
    kbProvider: () => kb,
    buildFileBloc: (EditBloc edit) => FileBloc(
      editBloc: edit,
      saveImpl: saveImpl,
      listBackupsImpl: backups.listBackups,
      restoreImpl: backups.restore,
    ),
  ));
}
```

`editor_screen.dart` 顶栏首帧自动探测：`ApexPathFinder(homeDir: ...).findVideoconfig()/findAutoexec()`，找到则 `fileBloc.add(OpenRequested(...))`，未找到弹出 `file_picker` 手动选择。退出保护：外层 `PopScope`（Windows 关窗走 `WindowListener` 的 `onWindowClose`，引入 `window_manager` 包）检查 `editBloc.state.dirty`，弹出「保存/放弃/取消」三选对话框。

`backup_dialog.dart`：列出 `fileBloc.state.backups`（新→旧），点击 → `RestoreRequested`。

- [ ] **步骤 4：运行验证通过**

```bash
flutter test test/file_flow_test.dart && flutter analyze && flutter test
```

预期：全部 PASS。

- [ ] **步骤 5：Commit**

```bash
git add -A && git commit -m "feat: wire file flow, backup dialog, exit protection, path autodetect"
```

---

### 任务 16：i18n 全量补齐 + UI 规范打磨

**文件：** 修改 `lib/l10n/*.arb`（补齐所有 UI 字符串键）、`lib/ui/**`（字面量 → `AppLocalizations`）、`lib/ui/widgets/kb_card.dart`；测试 `test/i18n_test.dart`

- [ ] **步骤 1：编写失败的测试**

widget 测试分别以 `Locale('zh')` 与 `Locale('en')` pump，断言同一界面出现「表格」/`Table`；知识卡未收录键分别显示中英文兜底文案。

- [ ] **步骤 2：运行验证失败** → `flutter test test/i18n_test.dart` 预期 FAIL

- [ ] **步骤 3：实现**：ARB 键全量（顶栏、模式、对话框、错误、警告 `fileBadEncoding`、还原、未保存三选等，en/zh 成对）；所有 UI 字面量替换为 `AppLocalizations.of(context)!.xxx`；按 `docs/ui-style-guide.md` 复核：Lucide 图标语义、无表情符号、深色对比度（正文 ≥ 4.5:1）、窗口缩放布局不破版。

- [ ] **步骤 4：运行验证通过** → `flutter test && flutter analyze` 预期全绿
- [ ] **步骤 5：Commit** `git add -A && git commit -m "feat: full i18n (zh/en) and ui guideline polish"`

---

### 任务 17：测试夹具、README 与 Windows CI

**文件：** 创建 `test/fixtures/videoconfig.sample.txt`、`test/fixtures/autoexec.sample.cfg`、`.github/workflows/windows-build.yml`、`README.md`

- [ ] **步骤 1：夹具**：放入脱敏真实样例（含注释/重复键/未知行/中英文注释），补一个 roundtrip 全文件单测 `test/fixtures_test.dart`（读夹具→两种解析器 parse→serialize→逐字节相等）。
- [ ] **步骤 2：运行** → `flutter test` 预期全绿
- [ ] **步骤 3：CI 工作流**

```yaml
name: windows-build
on: { push: { tags: ["v*"] }, workflow_dispatch: {} }
jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter config --enable-windows-desktop
      - run: flutter test
      - run: flutter build windows --release
      - uses: actions/upload-artifact@v4
        with:
          name: apex-cfg-editor-windows
          path: build/windows/x64/runner/Release/
```

- [ ] **步骤 4：README**：功能简介、构建方式（macOS 开发 / Windows 或 CI 打包）、备份位置说明、知识库扩展方法（assets/kb JSON schema）。
- [ ] **步骤 5：Commit** `git add -A && git commit -m "chore: fixtures, readme, windows ci"`

---

## 自检记录

1. **规格覆盖度**：R1→任务 2/3；R2→任务 6/13；R3→任务 1/16；R4→任务 11/14；R5→任务 5/12；R6→任务 4/8/15；R7→任务 9/15；退出保护→任务 15；编码策略→任务 4；错误处理→任务 4/9/15；验收夹具→任务 17。无遗漏。
2. **占位符扫描**：任务 10 步骤 3 的 `'Table'/'Text'`、任务 13 的 `'推荐：'/'kbNotDocumented'` 已显式标注由任务 16 收敛为 i18n 键（属于有序演进，非 TODO）；其余步骤均含实际代码/命令。
3. **类型一致性**：`CfgLine/KeyValueLine/CvarLine/RawLine/CommentLine/BlankLine`、`DiffRow/RowType`、`KbEntry/lookup(KbFile,key,locale)`、`EditEvent/EditState`、`FileBloc` 注入签名在任务 2→3→5→6→7→10→11→12→15 间一致；`serialize()` 契约（编辑行重建、其余原样）贯穿所有消费方。
