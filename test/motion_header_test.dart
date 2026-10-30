import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/widgets/app_design.dart';
import 'package:cam_bien_te_nga/widgets/motion_header.dart';

void main() {
  testWidgets('SOS header follows configuration and master monitoring', (
    tester,
  ) async {
    final controller = AppController();
    Future<void> render() => tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: MotionHeader(controller: controller)),
      ),
    );
    await render();
    expect(find.text('CHƯA BẬT SOS'), findsOneWidget);
    controller.realSmsEnabled = true;
    await render();
    expect(find.text('ĐÃ BẬT SOS'), findsOneWidget);
    controller.backgroundEnabled = false;
    await render();
    expect(find.text('ĐÃ BẬT SOS'), findsOneWidget);
    controller.monitoring = false;
    await render();
    expect(find.text('CHƯA BẬT SOS'), findsOneWidget);
    expect(find.byKey(const Key('openCloudAccount')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
