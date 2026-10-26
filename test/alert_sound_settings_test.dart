import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/widgets/alert_sound_settings.dart';
import 'package:cam_bien_te_nga/widgets/app_design.dart';

import 'support/fake_device_safety.dart';

void main() {
  testWidgets(
    'Picker cancel preserves selection; chosen title restores on reopening',
    (tester) async {
      final device = FakeDeviceSafetyBridge()..soundTitle = 'Âm cũ';
      Widget page() => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: AlertSoundSettings(device: device)),
      );
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.text('Âm cũ'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chooseAlertSound')));
      await tester.pump();
      expect(find.text('Âm cũ'), findsOneWidget);
      device.nextSoundTitle = 'Âm mới';
      await tester.tap(find.byKey(const Key('chooseAlertSound')));
      await tester.pump();
      expect(find.text('Âm mới'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.text('Âm mới'), findsOneWidget);
      expect(device.sendRequests, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Preview can stop early and stops when the page is removed without sending SMS',
    (tester) async {
      final device = FakeDeviceSafetyBridge();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          home: Scaffold(body: AlertSoundSettings(device: device)),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('previewAlertSound')));
      await tester.pump();
      expect(find.text('DỪNG NGHE THỬ'), findsOneWidget);
      await tester.tap(find.byKey(const Key('previewAlertSound')));
      await tester.pump();
      expect(device.previewRequests, [true, false]);
      await tester.tap(find.byKey(const Key('previewAlertSound')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(device.previewRequests, [true, false, true, false]);
      expect(device.sendRequests, 0);
    },
  );
  testWidgets('Rejected preview shows the error and never claims playback', (
    tester,
  ) async {
    final device = FakeDeviceSafetyBridge()..rejectSoundPreview = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AlertSoundSettings(device: device)),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('previewAlertSound')));
    await tester.pump();
    expect(find.text('Cảnh báo đang phát.'), findsOneWidget);
    expect(find.text('DỪNG NGHE THỬ'), findsNothing);
    expect(device.previewRequests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
