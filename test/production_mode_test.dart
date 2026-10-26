import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/screens/home_screen.dart';
import 'package:cam_bien_te_nga/screens/start_monitoring_screen.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/services/sensor_service.dart';
import 'package:cam_bien_te_nga/widgets/app_design.dart';

import 'support/fake_device_safety.dart';

class _Sensors extends SensorService {
  @override
  void start() {
    running = true;
  }

  @override
  void stop() {
    running = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Production never replaces an unavailable SMS service with a simulated SOS',
    () async {
      final device = FakeDeviceSafetyBridge();
      final c = AppController(device: device);
      c.simulate();
      c.requestHelp();
      expect(c.canSimulate, false);
      expect(c.alertActive, false);
      expect(c.sosActive, false);
      expect(c.events, isEmpty);
      expect(c.deviceError, contains('chưa sẵn sàng'));
      expect(device.sendRequests, 0);
      await c.saveContact('Người nhận', '0901234567');
      await c.enableRealSms('Người dùng');
      c.requestHelp();
      await Future<void>.delayed(Duration.zero);
      expect(device.sendRequests, 1);
      expect(c.sosIsSimulation, false);
      c.dispose();
    },
  );
  testWidgets(
    'Fresh install shows setup, no demo button and no armed monitoring indicator',
    (tester) async {
      final c = AppController(
        sensors: _Sensors(),
        device: FakeDeviceSafetyBridge(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: HomeScreen(controller: c),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('CHƯA BẬT SOS'), findsOneWidget);
      expect(find.text('CHƯA THIẾT LẬP SOS'), findsOneWidget);
      expect(find.byKey(const Key('simulateFall')), findsNothing);
      expect(find.text('MÔ PHỎNG'), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, false);
      await tester.scrollUntilVisible(
        find.byKey(const Key('manualSos')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('manualSos'))),
        alignment: .5,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('manualSos')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(StartMonitoringScreen), findsOneWidget);
      expect(c.sosActive, false);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
