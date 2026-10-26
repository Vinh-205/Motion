import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/widgets/auto_call_settings.dart';

import 'support/fake_device_safety.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Automatic calling requires explicit consent and does not call while configuring',
    (tester) async {
      final device = FakeDeviceSafetyBridge();
      final c = AppController(device: device);
      await c.saveContact('Người nhận', '0901234567');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AutoCallSettings(controller: c)),
        ),
      );
      await tester.tap(find.byKey(const Key('toggleAutoCall')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ĐỂ SAU'));
      await tester.pumpAndSettle();
      expect(device.calls, isNot(contains('setAutoCall')));
      await tester.tap(find.byKey(const Key('toggleAutoCall')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BẬT TỰ GỌI'));
      await tester.pumpAndSettle();
      expect(c.autoCallEnabled, true);
      expect(device.sendRequests, 0);
      expect(device.calls, isNot(contains('manualSos')));
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  test(
    'Denied call permission leaves SMS armed and priority survives restoration',
    () async {
      final device = FakeDeviceSafetyBridge();
      final c = AppController(device: device);
      await c.saveContact('A', '0901111111');
      await c.saveContact('B', '0902222222');
      await c.setCallPriority(c.contacts.last.id);
      expect(c.contacts.first.name, 'B');
      await c.enableRealSms('Người dùng');
      device.callEnableError = 'Chưa được cấp quyền gọi.';
      expect(await c.setAutoCall(true), contains('quyền gọi'));
      expect(c.autoCallEnabled, false);
      expect(c.realSmsEnabled, true);
      c.requestHelp();
      await Future<void>.delayed(Duration.zero);
      expect(device.sendRequests, 1);
      final restored = AppController(device: device);
      await restored.refreshDevice();
      expect(restored.contacts.first.phone, '0902222222');
      c.dispose();
      restored.dispose();
    },
  );
}
