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

  test('miss → null（UI 层走 kbNotDocumented 兜底）', () {
    final kb = KbService(data: {'zh': zh, 'en': {}});
    expect(kb.lookup(KbFile.autoexec, 'mat_queue_mode', 'zh'), isNull);
  });

  test('locale fallback zh→en→miss', () {
    final kb = KbService(data: {'en': zh});
    expect(kb.lookup(KbFile.autoexec, 'fps_max', 'zh')!.name, '帧率上限');
  });
}
