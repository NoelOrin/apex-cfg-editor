import 'package:apex_cfg_editor/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders the Apex CFG Editor title', (WidgetTester tester) async {
    await tester.pumpWidget(const ApexCfgEditorApp());

    expect(find.text('Apex CFG Editor'), findsOneWidget);
  });
}
