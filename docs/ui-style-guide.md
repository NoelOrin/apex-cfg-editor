# UI 设计规范

> 本文档是本项目（Apex CFG 编辑器）的 UI 风格规范，对所有界面实现具有约束力。
> Flutter 实现层面：图标统一使用 `lucide_icons` 包；文案与图标语义须通过无障碍（semantics）标注。

## 图标与表达

- 所有界面图标统一使用 Lucide Icons。
- 界面内容全程禁止使用表情符号。
- 图标必须具备明确语义；复杂或抽象图标需要提供可访问名称或提示。

## 设计标准

- 以 Awwwards、FWA、CSS Design Awards 每日最佳网站为对标标准。
- 追求高完成度的视觉表现、交互质量、性能体验与工程实现。
- 页面必须在桌面端与移动端都保持稳定、精致、可读。

## 创意方向

- 将浏览器视作交互式艺术画布，而不是传统后台模板的容器。
- 鼓励先锋视觉风格、实验性排版和非线性布局。
- 动效应保持流畅，并具备物理感、节奏感和叙事性。
- 文字版式可以成为视觉主体，通过尺度对比、层级关系和空间构图形成冲击力。

## 沉浸式体验

- 融合代码逻辑、高级渲染、交互反馈与视觉语言，构建统一完整的页面世界。
- 优先打造令人惊艳的数字交互体验，同时避免装饰干扰核心信息。
- 每个动效、材质、颜色与排版决策都必须服务于整体氛围和用户行为。

## 酸性风格 v2（Acid / Y2K-Rave，v1.1.0 落地）

> 本节是「创意方向」在应用壳层的落地规范：酸性绿主色 × 白/黑双主题模式，
> 配合无边框窗口与自绘标题栏。实现入口：`lib/ui/theme/acid_theme.dart`
> （色板与主题构建）、`lib/ui/widgets/title_bar.dart`（自绘标题栏）、
> `lib/main.dart`（frameless 初始化与 themeMode 记忆）。

### 色板（集中定义于 AcidPalette ThemeExtension，禁止散落硬编码）

| 语义 | 暗色（默认） | 亮色 | 用途 |
| --- | --- | --- | --- |
| 主色 acid | `#AEEF00` | `#BFFF00` | Logo、主按钮、焦点描边、选中态、选中行薄涂 |
| onAcid | `#0A0B08` | `#0C0E08` | 酸绿之上的文字（高对比反黑） |
| 底色 bg | `#0A0B08` | `#F4F6F0` | 窗口/页面背景（近黑 / 纸白） |
| 面板 panel | `#121410` | `#FCFDF8` | 标题栏、卡片、对话框浮层 |
| 文字 text | `#E8F0E0` | `#0C0E08` | 主文字 |
| 次级文字 textMuted | `#8A9484` | `#5A6154` | 辅助说明、行号、标题栏文件名 |
| 铬银 chrome | `#C8CCD4` | `#C8CCD4` | 点缀、描边细节（按明暗配不同透明度） |
| 风险/警示 danger | `#FF7A00` | `#FF7A00` | 高风险警示、errorColor 语义（kb 卡片、diff 删除行） |

diff 语义色（`DiffColors` ThemeExtension，20%~25% 透明叠加）：

- 删除行 = 酸性橙红（暗 `0x40FF4D00` / 亮 `0x33FF7A00`）
- 新增行 = 酸性绿（暗 `0x40AEEF00` / 亮 `0x33BFFF00`）
- 删除/新增两种语义色必须保持可区分，不得同化。

### 字体

- 展示字体：**Chakra Petch**（Google Fonts 官方仓库，SIL OFL 1.1，
  许可证随包：`assets/fonts/OFL.txt`）。打包 Regular / SemiBold / Bold /
  Bold Italic 四个字重，family 名 `ChakraPetch`。
- 适用范围：标题、顶栏品牌名、大数字；全大写 + 斜体 + 紧字距
  （品牌名 `APEX CFG EDITOR` 为基准样式）。
- 中文经 `fontFamilyFallback` 回退系统字体（苹方 / 雅黑 / Noto Sans SC），
  不影响中文正文渲染。
- cfg 内容区（表格 / diff / 文本编辑器）一律维持 monospace。

### 质感细节（克制，不堆砌）

- 顶栏左侧斜切酸绿平行四边形 Logo 块（CustomPainter，无发光）。
- 选中行：酸绿 14% 薄涂 + 主题描边；主按钮：酸绿实心 + 反黑文字。
- 分隔线：高对比 1px 细线（dividerTheme 统一）。
- diff 面板底纹：24px 方格 CustomPainter，酸绿 3% 透明度（< 4% 上限）。
- 禁止：发光滥用、渐变彩虹、表情符号（沿用本文档全局规则）。

### 主题切换与窗口壳层

- 亮/暗双主题，`themeMode` 持久化于 settings.json 的 `themeMode` 字段
  （'light' / 'dark' / 'system'），启动恢复；默认暗色，非法值回退暗色。
- 切换入口：自绘标题栏 Lucide sun/moon 按钮（`ThemeModeScope` 注入）。
- 无边框窗口：`setAsFrameless()` + `WindowOptions(titleBarStyle: hidden)`
  兜底；根容器 1px 酸绿描边保证窗口边界在桌面上可见。
- 自绘标题栏（高 44）：斜切 Logo + 品牌名 + 拖拽区（拖动 + 双击最大化）
  + 业务按钮 + 主题切换 + 最小化/最大化/关闭；关闭必须经退出保护
  （ExitGuard 三选流程），禁止无提示丢数据退出。
