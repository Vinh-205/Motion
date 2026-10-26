import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/models/fall_event.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/services/device_safety_bridge.dart';

import 'support/fake_device_safety.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Local countdown sound starts and stops on safe confirmation', () {
    final bridge = FakeDeviceSafetyBridge();
    final c = AppController(allowSimulation: true, device: bridge);
    c.simulate();
    expect(bridge.soundRequests, [true]);
    c.confirmSafe();
    expect(bridge.soundRequests, [true, false]);
    expect(bridge.sendRequests, 0);
    c.dispose();
  });
  test('Local sound continues at SOS timeout and stops on disposal without sending SMS', () {
    var time = DateTime(2026, 10, 23);
    final bridge = FakeDeviceSafetyBridge();
    final c = AppController(
      allowSimulation: true,
      device: bridge,
      now: () => time,
    );
    c.simulate();
    time = time.add(const Duration(seconds: 31));
    c.tick();
    expect(bridge.soundRequests, [true, true]);
    expect(c.sosIsSimulation, true);
    expect(bridge.sendRequests, 0);
    c.dispose();
    expect(bridge.soundRequests.last, false);
  });
  test('Normalize selected contact numbers; reject invalid and premium short numbers', () {
    expect(normalizePhone('+84 (901) 234-567'), '+84901234567');
    expect(validEmergencyPhone('+84 (901) 234-567'), true);
    for (final value in [
      '115',
      '112',
      '',
      'abc0901234567',
      '0901234567;123',
      '++84901234567',
    ]) {
      expect(validEmergencyPhone(value), false);
    }
  });
  test(
    'Saved contacts restore and failed saves do not replace the recipient',
    () async {
      final bridge = FakeDeviceSafetyBridge();
      final first = AppController(allowSimulation: true, device: bridge);
      expect(
        await first.saveContact(' Người thân ', '+84 (901) 234-567'),
        true,
      );
      first.dispose();
      final second = AppController(allowSimulation: true, device: bridge);
      await second.refreshDevice();
      expect(second.contactName, 'Người thân');
      expect(second.contactPhone, '+84901234567');
      bridge.saveSucceeds = false;
      expect(await second.saveContact('Khác', '0901111111'), false);
      expect(second.contactPhone, '+84901234567');
      second.dispose();
    },
  );
  test('Demo timeout never requests SMS even when real SMS is armed', () async {
    var time = DateTime(2026, 10, 22, 15);
    final bridge = FakeDeviceSafetyBridge();
    final c = AppController(
      allowSimulation: true,
      device: bridge,
      now: () => time,
    );
    addTearDown(c.dispose);
    await c.saveContact('Người thân', '0901234567');
    expect(await c.enableRealSms('Người dùng'), isNull);
    c.simulate();
    await Future<void>.delayed(Duration.zero);
    expect(c.pendingSource, EventSource.demo);
    time = time.add(const Duration(seconds: 31));
    c.tick();
    expect(c.sosIsSimulation, true);
    expect(bridge.sendRequests, 0);
    expect(bridge.calls, isNot(contains('manualSos')));
    c.dismissSos();
    await Future<void>.delayed(Duration.zero);
    expect(bridge.calls, contains('endDemo'));
  });
  test('Repeated manual SOS creates just one native send request', () async {
    final bridge = FakeDeviceSafetyBridge();
    final c = AppController(allowSimulation: true, device: bridge);
    addTearDown(c.dispose);
    await c.saveContact('Người thân', '0901234567');
    await c.enableRealSms('Người dùng');
    c.requestHelp();
    c.requestHelp();
    c.requestHelp();
    await Future<void>.delayed(Duration.zero);
    expect(bridge.sendRequests, 1);
    expect(c.sosIsSimulation, false);
    expect(c.events.single.outcomeLabel, 'Đang xử lý SMS');
  });
  test('Native countdown remains native when Flutter resumes late', () async {
    var time = DateTime(2026, 10, 22, 15);
    final bridge = FakeDeviceSafetyBridge();
    final c = AppController(
      allowSimulation: true,
      device: bridge,
      now: () => time,
    );
    addTearDown(c.dispose);
    await c.saveContact('Người thân', '0901234567');
    await c.enableRealSms('Người dùng');
    bridge.data.addAll({
      'pending': true,
      'remainingMilliseconds': 1000,
      'deadline': time.add(const Duration(seconds: 1)).millisecondsSinceEpoch,
      'eventAt': time.millisecondsSinceEpoch,
    });
    await c.refreshDevice();
    time = time.add(const Duration(minutes: 2));
    c.tick();
    expect(
      bridge.sendRequests,
      0,
      reason: 'Flutter must not race the Android deadline owner.',
    );
    c.confirmSafe();
    await Future<void>.delayed(Duration.zero);
    expect(bridge.calls, contains('confirmSafe'));
    expect(bridge.sendRequests, 0);
  });
  test('Denied setup leaves real SMS off', () async {
    final bridge = FakeDeviceSafetyBridge()
      ..enableError = 'Quyền SMS bị từ chối.';
    final c = AppController(allowSimulation: true, device: bridge);
    addTearDown(c.dispose);
    expect(await c.enableRealSms('Người dùng'), contains('từ chối'));
    expect(c.realSmsEnabled, false);
    expect(bridge.sendRequests, 0);
  });
}
