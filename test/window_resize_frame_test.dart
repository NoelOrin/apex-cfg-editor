import 'package:apex_cfg_editor/ui/widgets/window_resize_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  testWidgets('supported platform enables all drag-to-resize edges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WindowResizeFrame(
          supportedOverride: true,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final area = tester.widget<DragToResizeArea>(find.byType(DragToResizeArea));
    expect(area.enableResizeEdges, isNull);
    expect(area.resizeEdgeSize, 6);
  });

  testWidgets('unsupported platform disables resize edges', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WindowResizeFrame(
          supportedOverride: false,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final area = tester.widget<DragToResizeArea>(find.byType(DragToResizeArea));
    expect(area.enableResizeEdges, isEmpty);
  });
}
