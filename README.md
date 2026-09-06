# Apex CFG Editor

桌面端 Apex Legends 配置编辑器（Windows 优先，macOS 可跑测试开发调试）：把
`videoconfig.txt` 与 `autoexec.cfg` 的裸文本编辑升级为「表格 + 全文」双模式，
配行级 diff、内置知识库与自动备份，免手改引号键值、不怕改坏回不去。

## 功能

- **表格模式**：逐键编辑（KB 收录键带枚举下拉与推荐值提示）；文本模式全文
  monospace 编辑（300ms 防抖重解析），两种模式共享同一数据源。
- **行级并排 diff**：底部区域实时显示基线 vs 当前，删除红 / 新增绿。
- **知识库（zh/en）**：选中键显示名称、作用、推荐值与风险等级（high/medium
  带警示图标），未收录键仍可编辑。
- **编码安全**：自动探测 UTF-8 / GBK，按原编码写盘；无法解码的字节会警告
  而不是静默丢内容。
- **自动备份与还原**：每次保存前字节级备份旧文件；顶栏「还原」可回滚到
  任意历史备份。备份位置：`%APPDATA%\ApexCfgEditor\backups`。
- **退出保护**：有未保存修改时关闭窗口给出 保存 / 放弃 / 取消 三选。
- **i18n**：中文 / English 全量界面文案。

## 构建与运行

### macOS（开发调试）

本仓库只有 `windows/` runner（无 `macos/`），macOS 上 `flutter run -d macos`
**不可用**。日常开发回路是测试 + 静态分析（业务与 UI 逻辑都不依赖平台
通道，`flutter test` 环境下 window_manager 等原生通道调用被 try/catch
静默跳过，仅测试环境安全）：

```bash
flutter pub get
flutter analyze   # 0 issues
flutter test      # 全量单测 / widget 测试
```

如需真实运行 UI（原生窗口、关窗拦截、文件选择器），需要 Windows 机器
本地构建，或下载 CI 打包产物（见下节 GitHub Actions）。

### Windows（发布打包）

```powershell
flutter pub get
flutter config --enable-windows-desktop   # 首次构建前启用 Windows 桌面支持
flutter build windows --release
```

产物路径：`build\windows\x64\runner\Release\`（整个 Release 目录即免安装
运行包，含 `apex_cfg_editor.exe` 与同目录 DLL / data）。CI 上无签名步骤，
直接可用。

### GitHub Actions 自动打包

`.github/workflows/windows-build.yml` 在**推送 `v*` tag** 时触发（也可在
Actions 页面手动 `workflow_dispatch`），流程：windows-latest 上启用
Windows 桌面 → `flutter test` → `flutter build windows --release` → 把
Release 目录上传为 artifact `apex-cfg-editor-windows`。发布即：

```bash
git tag v1.0.0
git push origin v1.0.0
```

构建完成后到该次 run 的 Artifacts 里下载。

- 界面语言跟随系统 locale（zh / en），窗口最小尺寸 960x640。
- 生产环境自动探测 Apex 配置路径；未找到时用顶栏「打开文件」手动选择。

## 知识库扩展

知识库是四份纯 JSON（构建时打进 assets，无需改代码）：

```
assets/kb/zh/videoconfig.json   assets/kb/zh/autoexec.json
assets/kb/en/videoconfig.json   assets/kb/en/autoexec.json
```

新增/修改一个键的说明：

1. **改哪份**：键出现在 `videoconfig.txt`（`"setting.xxx"` 引号键）就改
   `videoconfig.json`；出现在 `autoexec.cfg`（裸 cvar 名）就改
   `autoexec.json`。两边的键都按规范化形态书写（无引号、无首尾空白）。
2. **en/zh 同步**：同一键必须同时出现在 zh 与 en 两份同名文件里，
   键集不一致会被 `test/kb_data_test.dart` 拦下。
3. **条目 schema**：

```json
"setting.mat_vsync_mode": {
  "name": "垂直同步模式",
  "description": "0 关闭 / 1·2·3·4 按刷新率分档开启。",
  "recommended": "0",
  "risk": "low",
  "values": [
    { "v": "0", "label": "关闭" },
    { "v": "2", "label": "120 Hz" }
  ]
}
```

   - `risk` 只允许 `low | medium | high`（high/medium 在 UI 带警示图标）。
   - `values` 是可选枚举，子项必须有非空 `v` 与 `label`；给了 `values`
     表格模式就会出现下拉。
4. **生效方式**：JSON 是 assets，需**重启应用**（开发期热重载不刷新
   assets）；发新版时随包带走。
5. **自检**：改完跑 `flutter test test/kb_data_test.dart`（zh/en parity、
   五字段完整、risk 枚举、values 子结构）。

## 开发注意事项

- **平台分工**：日常开发在任意平台跑 `flutter test` + `flutter analyze`
  （无平台依赖；仓库只有 windows/ runner，macOS 上无法 `flutter run`）；
  真实 UI 运行与打包（本地或 CI）只在 Windows 做。macOS 上
  `flutter build windows` 不可用，不要尝试。
- **编码红线**：`videoconfig.txt` 为 UTF-8、`autoexec.cfg` 常见 GBK，
  一律走 `CfgFileIo` 的探测/写回链路，不要用 `File.writeAsString` 直写，
  否则会把 GBK 文件写成 UTF-8 导致游戏内中文注释乱码。
- **serialize 契约**：只有编辑过的行才重建，未编辑行（含注释、空行、
  未知行、行内空格）逐字节原样写回。改动解析器必须让
  `test/fixtures_test.dart` 的全文件 roundtrip 守卫保持全绿。
- **夹具即验收**：`test/fixtures/` 下的三个样例是从真实配置脱敏而来
  （含注释、空行、重复键、多余空格、未知行、GBK 编码），改动解析/序列化
  行为时先想清楚是否破坏它们的逐字节一致性。
- **新增键不改代码**：知识库扩容只动 JSON（见上节）；解析、KB 查找
  （`setting.` 前缀双向尝试）的键规范化逻辑在 `lib/knowledge/kb_service.dart`。

## 测试

```bash
flutter analyze   # 0 issues
flutter test      # 全量单测 / widget 测试（含夹具 roundtrip 与 KB 数据校验）
```

## License

[MIT](LICENSE)
