import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/screens/settings_screen.dart';
import 'package:cam_bien_te_nga/widgets/app_design.dart';

import 'support/fake_device_safety.dart';

void main() {
  test('Background off preserves foreground detection, SMS arming and a pending alert', () async {
    final d = FakeDeviceSafetyBridge();
    d.data.addAll({
      'enabled': true,
      'running': true,
      'monitoring': true,
      'backgroundEnabled': true,
      'pending': true,
      'remainingMilliseconds': 30000,
      'deadline': DateTime.now()
          .add(const Duration(seconds: 30))
          .millisecondsSinceEpoch,
    });
    final c = AppController(device: d);
    await c.refreshDevice();
    expect(c.alertActive, true);
    await c.setBackgroundMonitoring(false);
    expect(c.backgroundMonitoring, false);
    expect(c.monitoring, true);
    expect(c.realSmsEnabled, true);
    expect(c.alertActive, true);
    expect(d.calls, isNot(contains('disableRealSms')));
    final restored = AppController(device: d);
    await restored.refreshDevice();
    expect(restored.backgroundEnabled, false);
    expect(restored.monitoring, true);
    c.dispose();
    restored.dispose();
  });
  testWidgets('Background switch is separate from the master switch', (
    tester,
  ) async {
    final d = FakeDeviceSafetyBridge();
    d.data.addAll({'enabled': true, 'running': true, 'monitoring': true});
    final c = AppController(device: d);
    addTearDown(c.dispose);
    await c.refreshDevice();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: c,
            builder: (_, _) => SettingsScreen(controller: c),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('backgroundMonitoringSwitch')),
      150,
    );
    await tester.tap(find.byKey(const Key('backgroundMonitoringSwitch')));
    await tester.pumpAndSettle();
    expect(c.backgroundEnabled, false);
    expect(c.monitoring, true);
    expect(c.realSmsEnabled, true);
    expect(d.sendRequests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
