import 'support/fake_device_safety.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/services/sensor_service.dart';
import 'package:cam_bien_te_nga/models/fall_event.dart';

class FakeSensors extends SensorService {
  int starts = 0, stops = 0;
  @override
  void start() {
    starts++;
    running = true;
  }

  @override
  void stop() {
    stops++;
    running = false;
  }
}

void main() {
  late AppController c;
  late DateTime clock;
  late FakeSensors sensors;
  setUp(() {
    clock = DateTime(2026, 10, 7, 15);
    sensors = FakeSensors();
    c = AppController(
      allowSimulation: true,
      sensors: sensors,
      now: () => clock,
      device: FakeDeviceSafetyBridge(),
    );
  });
  tearDown(() => c.dispose());
  test('Safe cancels deadline; no later SOS or duplicate event', () {
    c.simulate();
    c.simulate();
    expect(c.remainingSeconds, 30);
    c.confirmSafe();
    c.confirmSafe();
    clock = clock.add(const Duration(minutes: 1));
    c.tick();
    expect(c.events.length, 1);
    expect(c.events.single.outcome, EventOutcome.safe);
    expect(c.sosActive, false);
  });
  test('Deadline activates SOS exactly once', () {
    c.setCountdown(15);
    c.simulate();
    clock = clock.add(const Duration(seconds: 14));
    c.tick();
    expect(c.remainingSeconds, 1);
    expect(c.sosActive, false);
    clock = clock.add(const Duration(seconds: 1));
    c.tick();
    c.tick();
    c.requestHelp();
    expect(c.sosActive, true);
    expect(c.events.length, 1);
    expect(c.events.single.source, EventSource.demo);
    expect(c.sosMessage, contains('chưa gửi SMS'));
    c.confirmSafe();
    expect(c.events.length, 1);
    c.dismissSos();
    expect(c.sosActive, false);
  });
  test('Manual SOS works with monitoring off and saves the contact', () async {
    c.setMonitoring(false);
    await c.saveContact('An', '0901234567');
    c.requestHelp();
    expect(c.events.single.source, EventSource.manual);
    expect(c.sosMessage, contains('An'));
    expect(c.sosMessage, contains('0901234567'));
  });
  test('Resume uses elapsed deadline; lifecycle stops sensor sampling', () {
    c.start();
    c.simulate();
    c.setForeground(false);
    expect(sensors.running, false);
    clock = clock.add(const Duration(seconds: 45));
    c.setForeground(true);
    expect(sensors.running, true);
    expect(c.sosActive, true);
  });
  test('Real readings are not replaced by demo values', () {
    sensors.acceleration = const Vector3(1, 2, 3);
    c.simulate();
    expect(sensors.acceleration!.x, 1);
    expect(c.pendingSource, EventSource.demo);
  });
}
