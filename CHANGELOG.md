# Changelog

## [v1.2.0] - 2026-09-25

### 布局（左侧导航）

- 新增 Fluent 左侧栏：编辑器 / 知识库 / 变更对比 / 设置四个目的地，Win11 式选中态（强调条 + 浅色底）。
- 原底部「知识库 / 变更对比」矮条取消，改为侧栏切换的整页视图；编辑器恢复全高工作台。
- 文件操作（打开 / 保存 / 还原）与窗口控制仍留在标题栏。

### 界面（Fluent 毛玻璃）

- 标题栏与侧栏接入 Acrylic 毛玻璃；主题 `acrylicBackgroundColor` 半透明，叠出玻璃层次。
- 卡片统一 8px 圆角，模式切换与未保存徽章圆角化，描边对齐 Windows 11。

### 表格

- 表格模式隐藏 `bind_*` 键位绑定行（数量大且为 bind 指令），文本模式仍可查看/编辑。

## [v1.1.0] - 2026-09-24

### 路径探测（v3）

- 配置探测只认 `%USERPROFILE%\Saved Games\Respawn\Apex\local` 与用户指定的配置目录，不再扫描游戏安装目录 / EA 注册表 / 盘符。
- 用户指定目录可指向 local 本身、`Respawn/Apex/local` 的父级、或 `Respawn/Apex`；自动探测与自定义根无条件合并去重，Saved Games 优先。
- 「指定配置目录」仅在确实找到可打开配置后才写入记忆，避免选错污染。

### 备份与保存闭环

- 备份目录改为按目标路径哈希隔离（`文件名/路径哈希/`），不同路径的同名 `settings.cfg` 不再互相串号。
- 备份时间戳正则兼容毫秒，还原列表时间戳可正常显示；更换备份目录时自动迁移历史备份。
- 保存前检测外部改动（`fileChangedOnDisk`），避免覆盖游戏或其它工具刚写入的内容。
- 打开成功后先计算备份列表再更新文档状态，杜绝文档与路径错位。

### 退出与保存保护

- 「保存并退出」失败告警扩展为 `fileSaveFailed` / `fileBadBytesDirty` / `fileChangedOnDisk` 任一即中止退出。
- 保存按钮仅在已打开且有未保存修改时可点。

### 界面（Fluent + Windows 11）

- 色板对齐 Windows 11 Fluent 设计令牌：暗色 `#202020` / `#2B2B2B`，亮色 `#F3F3F3` / 白面板；文字、次级、描边、危险色均为 Win11 语义色。
- 强调色跟随系统（读注册表 `AccentColor`），无则回退 Win11 蓝（暗 `#4CC2FF` / 亮 `#0067C0`）。
- 字体栈切换为 Segoe UI Variable（Display/Text）+ 中文回退雅黑 / 苹方；diff 红绿改为 SystemFillColorCritical / Success 语义。

### 知识库

- `settings.cfg` 全部 40 键补齐中英 name / description / recommended / risk，描述中写明对应游戏内设置页位置（按键绑定、辅助功能字幕、视频高级低延迟、鼠标灵敏度与分倍镜、音频与语音、观战相机等）。
- 倍镜灵敏度下标映射标注为常见约定，提示以游戏内滑条顺序为准。

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
