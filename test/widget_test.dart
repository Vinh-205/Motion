import 'support/fake_device_safety.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/services/sensor_service.dart';
import 'package:cam_bien_te_nga/screens/home_screen.dart';
import 'package:cam_bien_te_nga/widgets/app_design.dart';

class FakeSensors extends SensorService {
  @override
  void start() {
    running = true;
  }

  @override
  void stop() {
    running = false;
  }
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    140,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 200));
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('Demo -> safe -> demo -> SOS -> history; four tabs in order', (
    tester,
  ) async {
    final c = AppController(
      allowSimulation: true,
      sensors: FakeSensors(),
      device: FakeDeviceSafetyBridge(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(controller: c),
      ),
    );
    expect(find.text('CHỜ DỮ LIỆU CẢM BIẾN'), findsOneWidget);
    await reveal(tester, find.byKey(const Key('simulateFall')));
    await tester.tap(find.byKey(const Key('simulateFall')));
    await tester.pump();
    expect(find.text('NGHI NGỜ TÉ NGÃ'), findsOneWidget);
    await reveal(tester, find.byKey(const Key('confirmSafe')));
    await tester.tap(find.byKey(const Key('confirmSafe')));
    await tester.pump();
    await reveal(tester, find.byKey(const Key('simulateFall')));
    await tester.tap(find.byKey(const Key('simulateFall')));
    await tester.pump();
    await reveal(tester, find.byKey(const Key('sendHelp')));
    await tester.tap(find.byKey(const Key('sendHelp')));
    await tester.pump();
    expect(find.text('SOS ĐƯỢC KÍCH HOẠT'), findsOneWidget);
    await reveal(tester, find.byKey(const Key('dismissSos')));
    await tester.tap(find.byKey(const Key('dismissSos')));
    await tester.pump();
    await tester.tap(find.text('Lịch sử').last);
    await tester.pump(const Duration(milliseconds: 500));
    await reveal(tester, find.text('SOS mô phỏng đã kích hoạt'));
    expect(find.text('SOS mô phỏng đã kích hoạt'), findsOneWidget);
    await reveal(tester, find.text('Người dùng xác nhận an toàn'));
    expect(find.text('Người dùng xác nhận an toàn'), findsOneWidget);
    await tester.tap(find.text('Liên hệ').last);
    await tester.pump(const Duration(milliseconds: 500));
    await reveal(tester, find.byKey(const Key('contactName')));
    await tester.enterText(find.byKey(const Key('contactName')), 'Người thân');
    await reveal(tester, find.byKey(const Key('contactPhone')));
    await tester.enterText(find.byKey(const Key('contactPhone')), 'bad');
    await reveal(tester, find.byKey(const Key('saveContact')));
    await tester.tap(find.byKey(const Key('saveContact')));
    await tester.pump();
    expect(
      find.text('Nhập 9–15 chữ số, có thể bắt đầu bằng +.'),
      findsOneWidget,
    );
    await reveal(tester, find.byKey(const Key('contactPhone')));
    await tester.enterText(find.byKey(const Key('contactPhone')), '0901234567');
    await reveal(tester, find.byKey(const Key('saveContact')));
    await tester.tap(find.byKey(const Key('saveContact')));
    await tester.pump();
    expect(c.contactName, 'Người thân');
    await tester.tap(find.text('Cài đặt').last);
    await tester.pump(const Duration(milliseconds: 500));
    await reveal(tester, find.text('Cao'));
    await tester.tap(find.text('Cao'));
    await tester.pump();
    expect(c.detector.config.impact, 15);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Large text on narrow display scrolls without overflow on every tab and alert',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController(
        allowSimulation: true,
        sensors: FakeSensors(),
        device: FakeDeviceSafetyBridge(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: HomeScreen(controller: c),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final label in ['Lịch sử', 'Liên hệ', 'Cài đặt', 'Theo dõi']) {
        await tester.tap(find.text(label).last);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull, reason: label);
      }
      c.simulate();
      await tester.pump();
      expect(tester.takeException(), isNull);
      c.confirmSafe();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Contact draft survives tab changes and reduced motion still permits navigation',
    (tester) async {
      final c = AppController(
        allowSimulation: true,
        sensors: FakeSensors(),
        device: FakeDeviceSafetyBridge(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: HomeScreen(controller: c),
        ),
      );
      await tester.tap(find.text('Liên hệ').last);
      await tester.pump();
      await reveal(tester, find.byKey(const Key('contactName')));
      await tester.enterText(find.byKey(const Key('contactName')), 'Bản nháp');
      await tester.tap(find.text('Theo dõi').last);
      await tester.pump();
      await tester.tap(find.text('Liên hệ').last);
      await tester.pump();
      expect(find.text('Bản nháp'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
