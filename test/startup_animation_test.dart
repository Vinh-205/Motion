import 'support/signed_in_api.dart';

import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:cam_bien_te_nga/main.dart';
import 'package:cam_bien_te_nga/screens/alert_screen.dart';
import 'package:cam_bien_te_nga/screens/home_screen.dart';
import 'package:cam_bien_te_nga/services/app_appearance.dart';
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
  setUpAll(() async {
    final composition = await AssetLottie(
      'assets/animations/motion_startup.json',
    ).load();
    expect(composition.images, isEmpty);
    expect(composition.duration.inMilliseconds, inInclusiveRange(1800, 1900));
    if (const bool.fromEnvironment('MOTION_CAPTURE_PREVIEWS')) {
      final file = File('C:/Windows/Fonts/segoeui.ttf');
      if (await file.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(ByteData.sublistView(await file.readAsBytes())),
          );
        await loader.load();
      }
    }
  });

  testWidgets('Startup finishes once while sensors start immediately', (
    tester,
  ) async {
    final c = AppController(
      allowSimulation: true,
      sensors: _Sensors(),
      device: FakeDeviceSafetyBridge(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(
          controller: c,
          showLaunchAnimation: true,
          startupPresentation: Future.value(),
        ),
      ),
    );
    expect(c.sensors.running, true);
    expect(find.byKey(const Key('startupAnimation')), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byKey(const Key('startupAnimation')), findsNothing);
    expect(find.byKey(const Key('openStartMonitoring')), findsOneWidget);
    c.setForeground(false);
    c.setForeground(true);
    await tester.pump();
    expect(find.byKey(const Key('startupAnimation')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pending emergency interrupts the intro immediately', (
    tester,
  ) async {
    final bridge = FakeDeviceSafetyBridge();
    final c = AppController(
      allowSimulation: true,
      sensors: _Sensors(),
      device: bridge,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(
          controller: c,
          showLaunchAnimation: true,
          startupPresentation: Future.value(),
        ),
      ),
    );
    expect(find.byKey(const Key('startupAnimation')), findsOneWidget);
    c.simulate();
    await tester.pump();
    expect(find.byType(AlertScreen), findsOneWidget);
    expect(find.byKey(const Key('startupAnimation')), findsNothing);
    expect(bridge.sendRequests, 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion skips the intro', (tester) async {
    final c = AppController(
      allowSimulation: true,
      sensors: _Sensors(),
      device: FakeDeviceSafetyBridge(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: HomeScreen(
            controller: c,
            showLaunchAnimation: true,
            startupPresentation: Future.value(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('startupAnimation')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Slow first raster cannot consume the intro before it becomes visible',
    (tester) async {
      final ready = Completer<void>();
      final c = AppController(
        allowSimulation: true,
        sensors: _Sensors(),
        device: FakeDeviceSafetyBridge(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            controller: c,
            showLaunchAnimation: true,
            startupPresentation: ready.future,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const Key('startupAnimation')), findsOneWidget);
      ready.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const Key('startupAnimation')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.byKey(const Key('startupAnimation')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Startup renders in both appearances without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final appearance = AppAppearance()..value = mode;
      final c = AppController(
        allowSimulation: true,
        sensors: _Sensors(),
        device: FakeDeviceSafetyBridge(),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('startupPreview'),
          child: MyApp(
            api: signedInTestApi(),
            appearance: appearance,
            controller: c,
            showLaunchAnimation: true,
            startupPresentation: Future.value(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.byType(LottieBuilder), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('MOTION_CAPTURE_PREVIEWS')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('startupPreview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          await File('build/ui-preview/startup-${mode.name}.png')
              .writeAsBytes(bytes);
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
    }
  });
}
