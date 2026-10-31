import 'support/fake_device_safety.dart';
import 'package:cam_bien_te_nga/screens/alert_screen.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('alert countdown updates without an outer ListenableBuilder', (tester) async {
    var clock = DateTime(2026, 1, 1, 12);
    final c = AppController(now: () => clock, allowSimulation: true, device: FakeDeviceSafetyBridge());
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: AlertScreen(controller: c)),
    );
    c.simulate();
    await tester.pump();
    final first = find.textContaining('00:');
    final before = tester.widget<Text>(first.first).data;
    clock = clock.add(const Duration(seconds: 5));
    c.tick();
    await tester.pump();
    final after = tester.widget<Text>(find.textContaining('00:').first).data;
    expect(after, isNot(before));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
