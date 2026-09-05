# Apex CFG 编辑器 · 设计规格

- 日期：2026-09-06
- 状态：已确认（头脑风暴产出，待实现计划）
- 关联文档：[UI 设计规范](../../../docs/ui-style-guide.md)（UI 强约束）

## 1. 背景与目标

Apex 玩家经常手改两个配置文件：`videoconfig.txt`（画面设置）与 `autoexec.cfg`（游戏命令/键位）。键名晦涩、社区资料零散、改错无法回退。本项目做一个 Windows 桌面工具：

1. 用表格或文本两种方式读取并修改这两个 cfg 文件；
2. 对每个键值对直接给出内置的用途说明（名称/作用/推荐值/风险等级）；
3. 编辑时提供**实时双栏并排 diff**（原始内容 vs 当前编辑，git 冲突视图风格）；
4. 保存直接写回原文件，自动时间戳备份，任意版本一键还原。

**成功定义（验收标准）**：打开真实 Apex cfg → 改值 → 双栏 diff 实时亮红绿 → 保存 → 备份存在且可一键还原，全程不丢原始格式；界面符合 UI 设计规范。

## 2. 需求清单

| 编号 | 需求 |
|---|---|
| R1 | 支持 `videoconfig.txt` 与 `autoexec.cfg` 两种格式 |
| R2 | 键值对内置说明，未收录键有兜底文案 |
| R3 | 应用 UI 与知识库文案全部走 i18n 资源，首发中文 + 英文 |
| R4 | 主编辑区双模式：表格化编辑（默认）+ 原始文本编辑（带高亮、查找替换） |
| R5 | 实时双栏 diff：原始快照 vs 当前内容，行级红绿高亮 |
| R6 | 保存写回原文件；写前自动备份（时间戳）；备份列表一键还原 |
| R7 | Windows 上自动探测文件路径，失败退回手动选择并记住上次路径 |

### 非目标（YAGNI）

- 多套配置方案（画质/帧数预设）一键切换 —— 二期再议；
- 在线知识库/社区分享 —— 不做，知识库随应用打包；
- macOS/Linux/移动端版本 —— 不做；「桌面+移动端稳定」落成不同窗口尺寸与 DPI 缩放下的稳定性。

## 3. 平台与约束

- 目标平台：Windows 桌面（Flutter Windows）。开发机为 macOS，**Flutter 的 Windows 产物只能在 Windows 机器或 CI（如 GitHub Actions `windows-latest`）上构建**；日常开发与测试在 macOS 桌面端进行（业务逻辑与 UI 不依赖平台通道）。
- 项目名：`apex_cfg_editor`，组织标识用 Flutter 默认 `com.example`（本地工具，无分发签名需求）。
- 完全离线运行，除声明依赖外不引入网络能力。

### 依赖（方案二：成熟组件拼装）

| 用途 | 选型 |
|---|---|
| 状态管理 | `flutter_bloc` / Bloc |
| diff 引擎 | `diff_match_patch`（行级包装见 §5） |
| 文本编辑模式 | `flutter_code_editor`（高亮） |
| 图标 | `lucide_icons` |
| i18n | Flutter 官方 `flutter_localization` + `gen-l10n`（ARB） |
| 文件选择 | `file_picker`（兜底；自动探测用纯 Dart 路径规则，不走平台通道） |

cfg 解析器无现成包可用，由本项目实现（见 §4）。

## 4. 架构与数据模型

```
lib/
├─ l10n/                      # ARB 多语言资源（app_zh / app_en，可扩展）
├─ core/
│  ├─ parser/
│  │   videoconfig_parser.dart   # 「"setting.x" "值"」引号键值对
│  │   autoexec_parser.dart      # cvar 命令、bind、// 与 /* */ 注释
│  │   cfg_document.dart         # 统一文档模型与序列化
│  ├─ diff/line_diff.dart        # diff_match_patch 行级包装
│  ├─ backup/backup_service.dart # 时间戳备份/还原/原子写回
│  └─ paths/apex_paths.dart      # Windows 路径探测（接口抽象，可注入假实现）
├─ knowledge/
│   kb_service.dart              # 知识库加载与查询（assets/kb/<locale>/<file>.json）
├─ state/                        # Bloc
│   file_bloc.dart               # 打开/保存/还原/备份列表
│   edit_bloc.dart               # 文档状态 + 脏标记 + 原始快照
│   diff_bloc.dart               # 监听 edit_bloc，产出 diff 行块
└─ ui/
    editor_screen.dart
    widgets/ kv_table_view.dart、text_editor_view.dart、side_by_side_diff.dart、kb_card.dart
```

**单一数据源**：`CfgDocument` = 有序的行列表，每行是 `键值行` / `注释行` / `空行` / `原样行` 四类之一，同时持有原始文本。表格模式原地改值（保留缩进、注释、行序）；文本模式编辑后整体重新解析，认不出的行降级为 `原样行`。两种模式共享同一 Bloc 状态，切换不丢格式。

## 5. 解析与 diff 语义

### 解析规则

| | videoconfig.txt | autoexec.cfg |
|---|---|---|
| 有效行 | `"key" "value"` | `cvar value`、`bind "键" "动作"` |
| 注释 | 原样保留 | `//`、`/* */`，原样保留 |
| 未知行 | 降级为原样行，不丢弃 | 同左 |
| 重复键 | 全部保留；知识卡提示「游戏实际取最后一个值」 | 同左 |
| 解析器异常 | 永不抛出；最坏情况整文件按原样行处理，保存时一字不差写回 | 同左 |

### 实时 diff

- 基线 = 打开文件时的原始全文快照；比较对象 = 当前编辑内容。
- `diff_bloc` 对两者跑 `diff_match_patch` 行模式，包装为四类行块：不变 / 修改 / 新增 / 删除；双栏视图左右对齐渲染，红=删除/旧值，绿=新增/新值。
- 表格模式改值即时刷新；文本模式输入 300ms 防抖后刷新。
- 保存成功后基线刷新为已保存内容，diff 归零。

## 6. 知识库

- 位置：`assets/kb/<locale>/videoconfig.json`、`assets/kb/<locale>/autoexec.json`，随应用打包；缺失语言回落英文，回落文案走 i18n。
- 键名标准化：去引号、转小写后精确匹配（videoconfig 的 `setting.*` 带前缀收录，autoexec 用裸 cvar 名）。
- 条目 schema：

```json
{
  "setting.fps_max": {
    "name": "帧率上限",
    "description": "限制游戏最大帧率，0 表示不限制。",
    "recommended": "0 或显示器刷新率",
    "risk": "low",
    "values": [{ "v": "0", "label": "不限制" }, { "v": "144", "label": "144 帧" }]
  }
}
```

- `values` 驱动表格模式的下拉控件；`risk: high` 的条目在说明卡中红色警示。
- 未收录键：说明卡显示当前语言的「未收录」文案，编辑不受影响。
- 首发覆盖：videoconfig 常用键全量；autoexec 收录社区常用 cvar（帧数优化/键位/网络）约 60–100 条，其余走兜底。

## 7. 文件安全（保存 / 备份 / 编码）

- **备份**：每次保存前，先把磁盘上的当前文件复制到 `%APPDATA%\ApexCfgEditor\backups\<文件名>\<yyyyMMdd-HHmmss>.cfg`。
- **写回**：写临时文件后原子替换（rename），避免写一半崩溃损坏 cfg。
- **编码**：打开时探测——UTF-8 BOM 或有效 UTF-8 按 UTF-8，否则按 Windows ANSI（GBK）；写回沿用原编码。出现无法映射的坏字节时提示「此文件编码异常」，未编辑的行按原始字节写回，避免二次损坏。
- **还原**：备份列表按时间戳倒序，选择任意版本写回原路径并重新加载为新的基线。
- **退出保护**：有未保存修改时关闭窗口，拦截并弹出「保存 / 放弃 / 取消」。

## 8. UI 设计

遵循 [docs/ui-style-guide.md](../../../docs/ui-style-guide.md)：Lucide 图标（`lucide_icons`）、全程无表情符号、图标带语义标注；深色沉浸式界面，以文字版式为主体；动效流畅有物理感，但不得干扰 diff 主信息。

主界面布局（可折叠分区，适配不同窗口尺寸/DPI）：

- **顶栏**：当前文件（含路径来源标识）、模式切换（表格/文本）、保存、还原、语言切换；
- **左·编辑区**（约 60% 宽）：表格模式每行 = 键名 | 值控件（枚举下拉/数字输入/文本）| 简述；文本模式为高亮编辑器；
- **右·知识卡**：当前选中键的名称/作用/推荐值/风险；
- **底·实时 diff**（约 40% 高）：双栏并排（左原始/右当前），行级红绿高亮，滚动联动。

## 9. 错误处理

原则：**用户的 cfg 数据永远不丢。**

| 场景 | 处理 |
|---|---|
| 读取失败（不存在/被占用） | 多语言报错 + 引导手动选择 |
| 写入失败（只读/被锁） | 报错，编辑内容保留在界面 |
| 路径探测失败 | 静默退回 file_picker，记住上次路径 |
| 解析失败行 | 降级原样行，保存时原样写回 |
| 编码坏字节 | 提示编码异常；未编辑行按原始字节写回 |
| 游戏更新增删键 | 知识库兜底文案，功能不阻断 |

## 10. 测试策略

在 macOS 上可完成全部单测/组件测试：

| 层 | 覆盖 |
|---|---|
| 解析器单测 | 正常键值、注释、重复键、畸形行、编码（UTF-8/GBK/BOM）、roundtrip（解析→序列化→逐字节一致） |
| diff 单测 | 增/删/改/行移动对齐、空文件、全文件替换 |
| 备份单测 | 时间戳命名、原子替换、任意版本还原 |
| 知识库单测 | 命中、未收录、语言回退 |
| Bloc 测试 | 打开→编辑→diff 更新→保存→基线刷新 状态迁移 |
| Widget 测试 | 表格改值触发 diff 高亮、双模式切换不丢格式 |
| 路径探测 | Windows 逻辑接口抽象 + 假实现；真机验收在 Windows |

测试夹具：仓库内置脱敏的真实 `videoconfig.txt` / `autoexec.cfg` 样例。

## 11. 里程碑（供实现计划展开）

1. **M1 地基**：Flutter 脚手架（含 Windows target）、Bloc/gen-l10n/lucide 接入、两个解析器 + roundtrip 单测；
2. **M2 核心体验**：表格编辑 + 实时双栏 diff + 知识卡（中文知识库）；
3. **M3 完整功能**：文本模式、路径探测 + 手动选择、备份/还原、编码策略、英文 i18n；
4. **M4 打磨发布**：UI 按规范打磨（动效/排版）、空态与错误态、Windows CI 打包。
