# Apex CFG Editor

桌面端 Apex Legends 配置编辑器（Windows 优先，macOS 可开发调试）：把
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

```bash
flutter pub get
flutter run -d macos              # macOS 开发调试（无原生窗口通道时优雅降级）
flutter build windows --release   # Windows 发布包（CI 同样适用）
```

- 界面语言跟随系统 locale（zh / en），窗口最小尺寸 960x640。
- 生产环境自动探测 Apex 配置路径；未找到时用顶栏「打开文件」手动选择。

## 知识库扩展

在 `assets/kb/{en,zh}/videoconfig.json`（或 `autoexec.json`）里按
`"键名": { "name": ..., "description": ..., "recommended": ..., "risk":
"low|medium|high", "values": [{ "v": ..., "label": ... }] }` 的 schema
追加条目即可（构建时打进 assets，无需改代码）。

## 测试

```bash
flutter analyze   # 0 issues
flutter test      # 全量单测 / widget 测试
```
