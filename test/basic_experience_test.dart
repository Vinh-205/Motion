import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/main.dart';
import 'package:cam_bien_te_nga/services/app_appearance.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/services/device_safety_bridge.dart';
import 'package:cam_bien_te_nga/services/sensor_service.dart';
import 'package:cam_bien_te_nga/screens/alert_screen.dart';
import 'package:cam_bien_te_nga/screens/start_monitoring_screen.dart';
import 'package:cam_bien_te_nga/screens/history_screen.dart';
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

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('MOTION_CAPTURE_PREVIEWS')) return;
  await tester.pump(const Duration(seconds: 1));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('previewBoundary')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    final file = File('build/ui-preview/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('MOTION_CAPTURE_PREVIEWS')) {
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (await font.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          );
        await loader.load();
      }
    }
  });
  String mode = 'light';
  setUp(() {
    mode = 'light';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceSafetyBridge.channel, (call) async {
          if (call.method == 'getAppearance') return mode;
          if (call.method == 'setAppearance') {
            mode = (call.arguments as Map)['mode'] as String;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceSafetyBridge.channel, null),
  );

  testWidgets(
    'Light and dark switch recolors the app and restores the saved choice',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final appearance = AppAppearance();
      final c = AppController(
        allowSimulation: true,
        sensors: _Sensors(),
        device: FakeDeviceSafetyBridge(),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('previewBoundary'),
          child: MyApp(appearance: appearance, controller: c),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      BuildContext page() =>
          tester.element(find.byKey(const Key('openStartMonitoring')));
      expect(Theme.of(page()).brightness, Brightness.light);
      expect(page().colors.background, AppPalette.light.background);
      await _capture(tester, 'basic-light');
      await tester.tap(find.byKey(const Key('toggleAppearance')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(Theme.of(page()).brightness, Brightness.dark);
      expect(page().colors.ink, AppPalette.dark.ink);
      expect(mode, 'dark');
      await _capture(tester, 'basic-dark');
      final restored = AppAppearance();
      await restored.load();
      expect(restored.isDark, true);
      restored.dispose();
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Start page is compact and a pending alert replaces open setup routes',
    (tester) async {
      final c = AppController(
        allowSimulation: true,
        sensors: _Sensors(),
        device: FakeDeviceSafetyBridge(),
      );
      final appearance = AppAppearance();
      await tester.pumpWidget(MyApp(appearance: appearance, controller: c));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const Key('openStartMonitoring')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(StartMonitoringScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('startBackgroundMonitoring')),
        120,
      );
      expect(
        find.byKey(const Key('startBackgroundMonitoring')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('fullScreenSettings')).hitTestable(),
        findsNothing,
      );
      c.simulate();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AlertScreen), findsOneWidget);
      expect(find.byType(StartMonitoringScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  test('Only a live, ready native service can leave the app monitoring in background', () async {
    final bridge = FakeDeviceSafetyBridge();
    final c = AppController(
      allowSimulation: true,
      sensors: _Sensors(),
      device: bridge,
    );
    await c.leaveToHome();
    expect(bridge.calls, isNot(contains('leaveToHome')));
    bridge.data.addAll({
      'enabled': true,
      'running': true,
      'monitoring': true,
      'sensorReady': true,
      'smsPermission': true,
      'notificationPermission': true,
      'simReady': true,
      'hasRequiredSensors': true,
    });
    await c.refreshDevice();
    expect(c.backgroundReady, true);
    c.setForeground(false);
    expect(c.backgroundMonitoring, true);
    await c.leaveToHome();
    expect(bridge.calls, contains('leaveToHome'));
    bridge.data['running'] = false;
    await c.refreshDevice();
    expect(c.backgroundReady, false);
    c.dispose();
  });

  testWidgets(
    'History detail shows saved facts and updates an arriving SMS receipt',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = FakeDeviceSafetyBridge();
      final event = <String, dynamic>{
        'id': 'saved-1',
        'at': DateTime(2026, 10, 23, 12).millisecondsSinceEpoch,
        'source': 'sensor',
        'outcome': 'sos',
        'smsStatus': 'sending',
        'reason': 'Chuỗi chuyển động nghi ngờ đã hoàn tất.',
        'recipientName': 'Liên hệ thử nghiệm',
        'recipientPhone': '0901234567',
        'countdownSeconds': 30,
        'sensitivity': 'medium',
        'latitude': 10.0,
        'longitude': 106.0,
        'locationAccuracy': 25.0,
        'locationAt': DateTime(2026, 10, 23, 11, 59).millisecondsSinceEpoch,
      };
      bridge.data['events'] = [event];
      final c = AppController(
        allowSimulation: true,
        sensors: _Sensors(),
        device: bridge,
      );
      await c.refreshDevice();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('previewBoundary'),
          child: MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light),
            home: Scaffold(body: HistoryScreen(controller: c)),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('eventDetail0')),
        160,
      );
      await tester.tap(find.byKey(const ValueKey('eventDetail0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Chi tiết sự kiện'), findsOneWidget);
      expect(find.text('Liên hệ thử nghiệm\n0901234567'), findsOneWidget);
      expect(
        find.text('Chuỗi chuyển động nghi ngờ đã hoàn tất.'),
        findsOneWidget,
      );
      event['smsStatus'] = 'delivered';
      await c.refreshDevice();
      await tester.pump();
      expect(find.text('SMS được nhà mạng báo phát'), findsOneWidget);
      await _capture(tester, 'basic-event-detail');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
