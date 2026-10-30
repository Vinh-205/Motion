import 'dart:convert';

import 'package:cam_bien_te_nga/screens/account_screen.dart';
import 'package:cam_bien_te_nga/screens/cloud_dashboard_screen.dart';
import 'package:cam_bien_te_nga/services/motion_api.dart';
import 'package:cam_bien_te_nga/widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> sampleUser(String role) => {
  'id': 'own-user',
  'name': 'Người kiểm thử',
  'email': 'test@example.org',
  'role': role,
  'verified': true,
  'active': true,
  'assignedStaffId': null,
  'createdAt': 1000000,
};
http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('API refuses localhost and cleartext endpoints', () {
    for (final url in [
      'http://motion-api.vihx.online',
      'https://localhost',
      'https://127.0.0.1',
      'https://10.0.2.2',
    ]) {
      expect(() => MotionApi(baseUrl: Uri.parse(url)), throwsArgumentError);
    }
  });
  test(
    'session stored securely, authorization attached, 401 clears restored user',
    () async {
      var revoked = false;
      final api = MotionApi(
        client: MockClient((request) async {
          if (request.url.path == '/auth/login/verify') {
            return jsonResponse({
              'accessToken': 'test-token',
              'user': sampleUser('member'),
            });
          }
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(request.followRedirects, isFalse);
          return revoked
              ? jsonResponse({'message': 'Phiên đã thu hồi'}, 401)
              : jsonResponse(sampleUser('member'));
        }),
      );
      addTearDown(api.dispose);
      await api.completeLogin('challenge', '123456');
      expect(api.signedIn, isTrue);
      expect(
        await const FlutterSecureStorage().read(
          key: 'motion.cloud.accessToken.v1',
        ),
        'test-token',
      );
      expect((await api.request('GET', '/me'))['role'], 'member');
      revoked = true;
      await expectLater(api.request('GET', '/me'), throwsA(isA<ApiFailure>()));
      expect(api.signedIn, isFalse);
      expect(
        await const FlutterSecureStorage().read(
          key: 'motion.cloud.accessToken.v1',
        ),
        isNull,
      );
    },
  );
  test('unavailable API never fabricates login or reports success', () async {
    final api = MotionApi(
      client: MockClient(
        (_) async => http.Response('<html>Unavailable</html>', 503),
      ),
    );
    addTearDown(api.dispose);
    await expectLater(
      api.completeLogin('id', '123456'),
      throwsA(isA<ApiFailure>()),
    );
    expect(api.signedIn, isFalse);
  });
  testWidgets(
    'password login requires email OTP before entering member dashboard',
    (tester) async {
      final api = MotionApi(
        client: MockClient((r) async {
          if (r.url.path == '/auth/login') {
            expect(jsonDecode(r.body), {
              'email': 'test@example.org',
              'password': 'long-password',
            });
            return jsonResponse({
              'challengeId': 'challenge',
              'expiresIn': 300,
              'message': 'Đã gửi mã',
            });
          }
          if (r.url.path == '/auth/login/verify') {
            return jsonResponse({
              'accessToken': 'test-token',
              'user': sampleUser('member'),
            });
          }
          return jsonResponse({'items': []});
        }),
      );
      addTearDown(api.dispose);
      await api.restore();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          home: AccountScreen(api: api),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.org',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'long-password');
      await tester.tap(find.text('TIẾP TỤC'));
      await tester.pumpAndSettle();
      expect(api.signedIn, isFalse);
      expect(find.text('Mã OTP 6 số'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('XÁC NHẬN'));
      await tester.pumpAndSettle();
      expect(find.text('Người dùng'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('MỞ VÒNG AN TOÀN'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('MỞ VÒNG AN TOÀN'), findsOneWidget);
      expect(find.text('TẠO TÀI KHOẢN'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final role in ['admin', 'staff', 'member']) {
    testWidgets(
      '$role dashboard and CRUD list fit narrow display with large text',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = MotionApi(
          client: MockClient((r) async {
            if (r.url.path == '/auth/login/verify') {
              return jsonResponse({
                'accessToken': 'test-token',
                'user': sampleUser(role),
              });
            }
            if (r.url.path == '/users') {
              return jsonResponse({
                'items': [
                  sampleUser(role),
                  {
                    ...sampleUser('member'),
                    'id': 'assigned',
                    'name':
                        'Một người dùng có tên rất dài để kiểm tra xuống dòng',
                  },
                ],
              });
            }
            return jsonResponse({'items': []});
          }),
        );
        addTearDown(api.dispose);
        await api.restore();
        await api.completeLogin('id', '123456');
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: AccountScreen(api: api),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(roleLabel(role)), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('MỞ VÒNG AN TOÀN'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('MỞ VÒNG AN TOÀN'));
        await tester.pumpAndSettle();
        expect(find.text('Tạo lịch hẹn'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Tạo lịch hẹn'));
        await tester.pumpAndSettle();
        expect(find.text('Nội dung hẹn'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'cloud contacts can be created, edited and deleted from Flutter',
    (tester) async {
      final rows = <Map<String, dynamic>>[];
      final api = MotionApi(
        client: MockClient((request) async {
          if (request.url.path == '/auth/login/verify') {
            return jsonResponse({
              'accessToken': 'test-token',
              'user': sampleUser('member'),
            });
          }
          final data = request.body.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(request.body) as Map<String, dynamic>;
          if (request.method == 'POST') {
            rows.add({
              ...data,
              'id': 'contact-id',
              'ownerId': 'own-user',
              'relationship': '',
              'createdAt': 1000000,
              'updatedAt': 1000000,
            });
            return jsonResponse(rows.last);
          }
          if (request.method == 'PATCH') {
            rows.single.addAll(data);
            return jsonResponse(rows.single);
          }
          if (request.method == 'DELETE') {
            rows.clear();
            return jsonResponse({'message': 'Đã xóa'});
          }
          return jsonResponse({'items': rows});
        }),
      );
      addTearDown(api.dispose);
      await api.restore();
      await api.completeLogin('id', '123456');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          home: CloudRecordsScreen(
            api: api,
            resource: 'contacts',
            title: 'Liên hệ đám mây',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm liên hệ'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Người thân');
      await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
      await tester.tap(find.text('LƯU'));
      await tester.pumpAndSettle();
      expect(find.text('Người thân'), findsOneWidget);
      expect(rows.single['phone'], '0912345678');
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Đã đổi tên');
      await tester.tap(find.text('LƯU'));
      await tester.pumpAndSettle();
      expect(find.text('Đã đổi tên'), findsOneWidget);
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();
      expect(rows, isEmpty);
      expect(find.textContaining('Chưa có dữ liệu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
