import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/screens/contact_screen.dart';
import 'package:cam_bien_te_nga/screens/sms_setup_screen.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/widgets/app_design.dart';

import 'support/fake_device_safety.dart';

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    140,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets('Picking a contact fills the form but needs an explicit Save', (
    tester,
  ) async {
    final device = FakeDeviceSafetyBridge()
      ..selectedContact = {'name': 'Người thân', 'phone': '+84 (901) 234-567'};
    final c = AppController(allowSimulation: true, device: device);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: ContactScreen(controller: c)),
      ),
    );
    await reveal(tester, find.byKey(const Key('pickContact')));
    await tester.tap(find.byKey(const Key('pickContact')));
    await tester.pump();
    expect(c.contactPhone, isEmpty);
    await reveal(tester, find.byKey(const Key('contactPhone')));
    expect(find.text('+84901234567'), findsOneWidget);
    await reveal(tester, find.byKey(const Key('saveContact')));
    await tester.tap(find.byKey(const Key('saveContact')));
    await tester.pump();
    expect(c.contactName, 'Người thân');
    expect(c.contactPhone, '+84901234567');
    expect(device.sendRequests, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Cancelling the picker preserves the contact draft', (
    tester,
  ) async {
    final device = FakeDeviceSafetyBridge();
    final c = AppController(allowSimulation: true, device: device);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: ContactScreen(controller: c)),
      ),
    );
    await reveal(tester, find.byKey(const Key('contactName')));
    await tester.enterText(find.byKey(const Key('contactName')), 'Bản nháp');
    // Scroll back upward to the earlier chooser without changing the draft.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pump();
    await reveal(tester, find.byKey(const Key('pickContact')));
    await tester.tap(find.byKey(const Key('pickContact')));
    await tester.pump();
    await reveal(tester, find.byKey(const Key('contactName')));
    expect(find.text('Bản nháp'), findsOneWidget);
    expect(c.contactPhone, isEmpty);
    expect(device.sendRequests, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'SMS setup handles large text and declining consent never enables real SMS',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final device = FakeDeviceSafetyBridge();
      final c = AppController(allowSimulation: true, device: device);
      addTearDown(c.dispose);
      await c.saveContact('Người thân', '0901234567');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: SmsSetupScreen(controller: c),
        ),
      );
      await reveal(tester, find.byKey(const Key('ownerName')));
      await tester.enterText(find.byKey(const Key('ownerName')), 'Người dùng');
      await reveal(tester, find.byKey(const Key('toggleRealSms')));
      await tester.tap(find.byKey(const Key('toggleRealSms')));
      await tester.pumpAndSettle();
      expect(find.text('Bật SMS tự động?'), findsOneWidget);
      await tester.tap(find.text('ĐỂ SAU'));
      await tester.pumpAndSettle();
      expect(device.calls, isNot(contains('enableRealSms')));
      expect(device.sendRequests, 0);
      expect(c.realSmsEnabled, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
