import 'dart:convert';

import 'package:cam_bien_te_nga/main.dart';
import 'package:cam_bien_te_nga/screens/cloud_dashboard_screen.dart';
import 'package:cam_bien_te_nga/screens/home_screen.dart';
import 'package:cam_bien_te_nga/services/app_controller.dart';
import 'package:cam_bien_te_nga/services/motion_api.dart';
import 'package:cam_bien_te_nga/services/sensor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  AppController controller() => AppController(
    allowSimulation: true,
    sensors: _Sensors(),
    device: FakeDeviceSafetyBridge(),
  );
  MotionApi client(String role) => MotionApi(
    client: MockClient(
      (request) async => http.Response(
        jsonEncode(
          request.url.path == '/auth/login/verify'
              ? {
                  'accessToken': 'test-token',
                  'user': {
                    'id': 'own',
                    'name': 'Test',
                    'email': 'test@example.org',
                    'role': role,
                  },
                }
              : request.url.path == '/users'
              ? {'items': []}
              : {'message': 'ok'},
        ),
        200,
        headers: {'content-type': 'application/json'},
      ),
    ),
  );

  testWidgets(
    'normal launch requires login and registration cannot reveal the app',
    (tester) async {
      final api = client('member');
      addTearDown(api.dispose);
      await tester.pumpWidget(MyApp(api: api, controller: controller()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Chào bạn trở lại.'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Tạo tài khoản bằng email'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Tạo tài khoản bằng email'));
      await tester.pump();
      expect(find.text('Tạo tài khoản.'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final role in ['member', 'staff', 'admin']) {
    testWidgets(
      '$role enters correct area and logout closes normal navigation',
      (tester) async {
        final api = client(role);
        addTearDown(api.dispose);
        await api.restore();
        await api.completeLogin('id', '123456');
        await tester.pumpWidget(MyApp(api: api, controller: controller()));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.byType(role == 'member' ? HomeScreen : CloudDashboardScreen),
          findsOneWidget,
        );
        await api.logout();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Chào bạn trở lại.'), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'SOS is accessible without login, confirmation returns to authentication',
    (tester) async {
      final api = client('member'), c = controller();
      addTearDown(api.dispose);
      await tester.pumpWidget(MyApp(api: api, controller: c));
      await tester.pump(const Duration(milliseconds: 500));
      c.simulate();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('NGHI NGỜ TÉ NGÃ'), findsOneWidget);
      expect(find.text('Chào bạn trở lại.'), findsNothing);
      c.confirmSafe();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Chào bạn trở lại.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
