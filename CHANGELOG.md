# Changelog

## [v1.0.0] - 2026-09-17

### 编辑器

- 仅支持 `settings.cfg`（操作设置，包括按键绑定、鼠标/控制器灵敏度及相关操作选项）与
  `videoconfig.txt`（游戏画质，包括分辨率、阴影、纹理与特效）的表格和全文双模式编辑。
- 明确区分两类配置：`settings.cfg` 负责操作设置、`videoconfig.txt` 负责游戏画质，用途不同。
- 代码模式启用高对比语法高亮，区分注释、字符串、数字、关键字和命令标识。
- 支持 UTF-8 / GBK 编码探测、按原编码保存、原子写入和坏字节保护。
- 支持逐行实时 diff、内置中英文知识库、备份与一键还原。

### 文件类型限制

- 编辑器只打开并编辑 `settings.cfg` 与 `videoconfig.txt`；其它文件（含 `autoexec.cfg`）在手动选择时会被拒绝并提示，启动时也不会被自动打开。
- 文件对话框默认指向 EA 默认 `local` 目录，且仅接受这两份文件名。

### 路径探测

- 配置文件默认读取 `%USERPROFILE%\Saved Games\Respawn\Apex\local`，
  优先匹配 `settings.cfg`，并兼容同目录 `videoconfig.txt`。
- 游戏安装目录仅保留 EA App 检测，用于定位 `Respawn/Apex/local/` 下的 `settings.cfg` 与 `videoconfig.txt`。
- 不再自动扫描 Steam、Documents、OneDrive 等旧路径，仍支持手动选择文件或安装目录。

### 界面与窗口

- 使用 Fluent UI 与酸性风格双主题；正文字体优化为 `Microsoft YaHei UI`
  回退链，cfg 内容统一使用 Consolas。
- 无边框窗口支持四边与四角拖拽缩放、自绘标题栏、亮暗主题记忆和快速关闭。
- 修复「重新选择文件」在 Windows 上点击无反应：文件选择器的初始目录改为严格校验“存在且为目录”，
  失效（如记忆成文件路径、目录被移动/删除）时自动回退 EA 默认 local 目录（%USERPROFILE%\\
  Saved Games\\Respawn\\Apex\\local），仍失败再回退系统默认库，保证对话框始终弹出。

### 应用能力

- 内置设置页、配置诊断、应用信息、更新检查和发行说明入口。
- 支持自动备份、退出保护、多安装选择。
- GitHub Release 提供 Windows 安装器和便携版 ZIP。

### 知识库

- 为 `settings.cfg` 补齐中英双语知识库描述：独立配置项（灵敏度、瞄准分档、音频、
  语音、界面布局、低延迟等）逐键说明，键位绑定 `bind_US_standard` /
  `bind_held_US_standard` 扩展为含完整动作中英对照表（武器槽、消耗品、移动、
  技能、标点、语音等），打开 settings.cfg 即可看清每个按键绑定的动作。
- 知识库按文件域隔离：`settings.cfg` 用操作设置域、`videoconfig.txt` 用画质域、
  `autoexec.cfg` 用启动命令域，避免同名键（如 `name`）跨文件互相覆盖。
- 知识卡片与键值表格均随当前打开文件类型切换对应描述域，重新选择 cfg
  文件后立即刷新说明。
