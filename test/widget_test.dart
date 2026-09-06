import 'package:apex_cfg_editor/knowledge/kb_service.dart';
import 'package:apex_cfg_editor/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders the Apex CFG Editor title', (WidgetTester tester) async {
    // 装配壳烟测：注入空知识库并关闭自动探测，隔离宿主环境。
    await tester.pumpWidget(ApexCfgEditorApp(
      kb: const KbService(data: {}),
      autoDetect: false,
    ));
    await tester.pump();

    expect(find.text('Apex CFG Editor'), findsOneWidget);
  });
}
