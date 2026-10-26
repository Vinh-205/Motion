import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/widgets/emergency_services.dart';

import 'support/fake_device_safety.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Legacy contact migrates; add, edit, delete persist; equivalent phone duplicates are rejected', () async {
    final device = FakeDeviceSafetyBridge();
    device.data.addAll({
      'contactName': 'Người thân cũ',
      'contactPhone': '0901234567',
    });
    final c = AppController(allowSimulation: true, device: device);
    await c.refreshDevice();
    expect(c.contacts.single.name, 'Người thân cũ');
    expect(await c.saveContact('Trùng', '+84 901 234 567'), false);
    expect(await c.saveContact('Người thứ hai', '0902222222'), true);
    expect(c.contacts.length, 2);
    final second = c.contacts.last.id;
    expect(await c.saveContact('Đổi tên', '0902222222', id: second), true);
    expect(c.contacts.last.name, 'Đổi tên');
    device.saveSucceeds = false;
    expect(await c.removeContact(second), false);
    expect(c.contacts.length, 2);
    device.saveSucceeds = true;
    expect(await c.removeContact(second), true);
    final restored = AppController(allowSimulation: true, device: device);
    await restored.refreshDevice();
    expect(restored.contacts.single.phone, '0901234567');
    expect(device.sendRequests, 0);
    c.dispose();
    restored.dispose();
  });
  test(
    'Cannot remove the last recipient while SMS monitoring is armed',
    () async {
      final device = FakeDeviceSafetyBridge();
      final c = AppController(allowSimulation: true, device: device);
      await c.saveContact('Người nhận', '0901234567');
      await c.enableRealSms('Người dùng');
      expect(await c.removeContact(c.contacts.single.id), false);
      expect(c.contacts.length, 1);
      c.dispose();
    },
  );
  testWidgets('Emergency buttons request the dialer only, never SMS', (
    tester,
  ) async {
    final device = FakeDeviceSafetyBridge();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EmergencyServices(device: device)),
      ),
    );
    for (final number in ['113', '114', '115']) {
      await tester.tap(find.byKey(ValueKey('dial$number')));
      await tester.pump();
    }
    expect(device.calls.where((c) => c == 'dialEmergency').length, 3);
    expect(device.sendRequests, 0);
    expect(device.calls, isNot(contains('manualSos')));
    await tester.pumpWidget(const SizedBox());
  });
}
