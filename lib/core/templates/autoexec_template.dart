/// autoexec.cfg 创建模板：全部行为注释状态——玩家首次没有 autoexec.cfg
/// 时由编辑器写入此模板，不主动改变任何游戏行为；示例行去掉行首 `//`
/// 并重启游戏后才生效。中英双语注释。
const autoexecTemplate = '''
// Apex Legends autoexec.cfg
// 由 Apex CFG 编辑器创建 / Created by Apex CFG Editor.
//
// 使用说明 / How to use:
//   去掉行首的 // 并重启游戏，该行配置即生效。
//   Remove the leading // and restart the game to apply that line.
//
// ---- 帧数优化示例 / Performance examples ----
// fps_max 240
// fps_max_menu 120
// mat_vsync 0
// r_fullscreen 1
''';
