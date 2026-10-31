import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cam_bien_te_nga/screens/emergency_card_screen.dart';
import 'package:cam_bien_te_nga/services/device_safety_bridge.dart';
import 'package:cam_bien_te_nga/services/motion_api.dart';
import 'package:cam_bien_te_nga/widgets/app_design.dart';
import 'package:cam_bien_te_nga/screens/monitor_screen.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real monitoring diagnostics at bottom render with a Material ancestor',
    (tester) async {
      final c = AppController()..realSmsEnabled = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: MonitorScreen(controller: c)),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const PageStorageKey('detectionDiagnostics')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const PageStorageKey('detectionDiagnostics')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const PageStorageKey('detectionDiagnostics')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  for (final status in [200, 401, 503]) {
    test('restore cached session before server validation: $status', () async {
      final payload = base64UrlEncode(
        utf8.encode(
          jsonEncode({
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          }),
        ),
      ).replaceAll('=', '');
      final user = {'id': 'a', 'name': 'Test', 'role': 'member'};
      FlutterSecureStorage.setMockInitialValues({
        'motion.cloud.accessToken.v1': 'header.$payload.signature',
        'motion.cloud.profile.v1': jsonEncode(user),
      });
      final reply = Completer<http.Response>();
      final ready = Completer<void>();
      final api = MotionApi(client: MockClient((_) => reply.future));
      addTearDown(api.dispose);
      api.addListener(() {
        if (api.restored && !ready.isCompleted) ready.complete();
      });
      final restoring = api.restore();
      await ready.future;
      expect(api.signedIn, true);
      reply.complete(
        http.Response(
          jsonEncode(status == 200 ? user : {'message': 'Not available'}),
          status,
        ),
      );
      await restoring;
      expect(api.signedIn, status != 401);
      if (status == 401) {
        expect(
          await const FlutterSecureStorage().read(
            key: 'motion.cloud.profile.v1',
          ),
          isNull,
        );
      }
    });
  }
  testWidgets(
    'card saves offline, restores fields, validates offscreen name and deletes',
    (tester) async {
      var data = <String, dynamic>{};
      var saves = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceSafetyBridge.channel, (call) async {
            switch (call.method) {
              case 'getEmergencyCard':
                return data;
              case 'saveEmergencyCard':
                saves++;
                data = Map<String, dynamic>.from(call.arguments as Map);
                return null;
              case 'deleteEmergencyCard':
                data = {};
                return null;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(DeviceSafetyBridge.channel, null),
      );
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: const EmergencyCardScreen(),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> reveal(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }

      await open();
      await reveal(find.byKey(const Key('saveEmergencyCard')));
      await tester.tap(find.byKey(const Key('saveEmergencyCard')));
      await tester.pumpAndSettle();
      expect(saves, 0);
      await tester.scrollUntilVisible(
        find.byKey(const Key('card_name')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const Key('card_name')), 'Người thử');
      await tester.enterText(
        find.byKey(const Key('card_conditions')),
        'Thông tin thử',
      );
      await reveal(find.byKey(const Key('saveEmergencyCard')));
      await tester.tap(find.byKey(const Key('saveEmergencyCard')));
      await tester.pumpAndSettle();
      expect(data['name'], 'Người thử');
      expect(data['showWhenLocked'], false);
      await tester.pumpWidget(const SizedBox());
      await open();
      expect(find.text('Người thử'), findsOneWidget);
      await reveal(find.text('XÓA THẺ'));
      await tester.tap(find.text('XÓA THẺ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('XÓA'));
      await tester.pumpAndSettle();
      expect(data, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
