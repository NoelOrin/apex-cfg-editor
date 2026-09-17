# Changelog

## [v1.0.0] - 2026-09-17

### 编辑器

- 支持 `settings.cfg`、`videoconfig.txt` 与 `autoexec.cfg` 的表格和全文双模式编辑。
- 明确区分 `settings.cfg`（操作设置，包括按键绑定、鼠标/控制器灵敏度及相关操作选项）、
  `videoconfig.txt`（游戏画质，包括分辨率、阴影、纹理与特效）和
  `autoexec.cfg`（启动命令）。
- 代码模式启用高对比语法高亮，区分注释、字符串、数字、关键字和命令标识。
- 支持 UTF-8 / GBK 编码探测、按原编码保存、原子写入和坏字节保护。
- 支持逐行实时 diff、内置中英文知识库、备份与一键还原。

### 路径探测

- 配置文件默认读取 `%USERPROFILE%\Saved Games\Respawn\Apex\local`，
  优先匹配 `settings.cfg`，并兼容同目录 `videoconfig.txt`。
- 游戏安装目录仅保留 EA App 检测，用于定位 `autoexec.cfg`。
- 不再自动扫描 Steam、Documents、OneDrive 等旧路径，仍支持手动选择文件或安装目录。

### 界面与窗口

- 使用 Fluent UI 与酸性风格双主题；正文字体优化为 `Microsoft YaHei UI`
  回退链，cfg 内容统一使用 Consolas。
- 无边框窗口支持四边与四角拖拽缩放、自绘标题栏、亮暗主题记忆和快速关闭。
- 编辑器工具头提供醒目的重新选择文件按钮，并修复失效目录导致选择器无法打开的问题。

### 应用能力

- 内置设置页、配置诊断、应用信息、更新检查和发行说明入口。
- 支持自动备份、退出保护、多安装选择以及缺失 `autoexec.cfg` 时创建注释模板。
- GitHub Release 提供 Windows 安装器和便携版 ZIP。
