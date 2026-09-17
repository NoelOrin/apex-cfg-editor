import 'package:apex_cfg_editor/knowledge/kb_service.dart';
import 'package:flutter_test/flutter_test.dart';

const zh = {
  'setting.fps_max': {
    'name': '帧率上限',
    'description': '限制游戏最大帧率，0 表示不限制。',
    'recommended': '0 或显示器刷新率',
    'risk': 'low',
    'values': [
      {'v': '0', 'label': '不限制'},
      {'v': '144', 'label': '144 帧'},
    ],
  },
  'bind': {
    'name': '键位绑定',
    'description': '把某个按键绑定到命令。',
    'recommended': '',
    'risk': 'medium',
    'values': [],
  },
};

void main() {
  test('normalize: quotes/case/whitespace-insensitive lookup', () {
    final kb = KbService(data: {'zh': zh, 'en': {}});
    final e = kb.lookup(KbFile.autoexec, '  FPS_MAX ', 'zh');
    expect(e!.name, '帧率上限');
  });

  test('miss → null（UI 层保持留空）', () {
    final kb = KbService(data: {'zh': zh, 'en': {}});
    expect(kb.lookup(KbFile.autoexec, 'mat_queue_mode', 'zh'), isNull);
  });

  test('locale fallback zh→en→miss', () {
    final kb = KbService(data: {'en': zh});
    expect(kb.lookup(KbFile.autoexec, 'fps_max', 'zh')!.name, '帧率上限');
  });

  test('settings domain resolves settings.cfg descriptions', () {
    const settings = {
      'mouse_sensitivity': {
        'name': '鼠标灵敏度',
        'description': '游戏内鼠标灵敏度倍率。',
        'recommended': '按个人习惯设置',
        'risk': 'low',
        'values': [],
      },
    };
    final kb = KbService(
      data: {'zh': settings, 'en': {}},
    );

    expect(
      kb.lookup(KbFile.settings, 'mouse_sensitivity', 'zh')!.description,
      '游戏内鼠标灵敏度倍率。',
    );
  });
}
