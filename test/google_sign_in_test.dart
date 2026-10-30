import 'dart:convert';

import 'package:cam_bien_te_nga/services/motion_api.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('Google callback is bound to the starting flow and client PKCE proof', () async {
    String? challenge;
    final api = MotionApi(
      googleBrowser: (url) async {
        expect(Uri.parse(url).host, 'accounts.google.com');
        return 'com.vihx.motion://oauth/google?flowId=flow-id&ticket=${'t' * 43}';
      },
      client: MockClient((request) async {
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path == '/auth/google/start') {
          challenge = data['codeChallenge'] as String;
          expect(data['linkAccount'], false);
          return http.Response(
            jsonEncode({
              'flowId': 'flow-id',
              'authorizationUrl': 'https://accounts.google.com/o/oauth2/v2/auth?state=server-state',
            }),
            200,
          );
        }
        expect(request.url.path, '/auth/google/exchange');
        final verifier = data['codeVerifier'] as String;
        expect(
          base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes)
              .replaceAll('=', ''),
          challenge,
        );
        expect(data['ticket'], 't' * 43);
        return http.Response(
          jsonEncode({
            'accessToken': 'test-motion-jwt',
            'user': {'id': 'own', 'role': 'member', 'name': 'Google Test'},
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    await api.signInWithGoogle();
    expect(api.signedIn, true);
    expect(api.role, 'member');
    expect(
      await const FlutterSecureStorage().read(
        key: 'motion.cloud.accessToken.v1',
      ),
      'test-motion-jwt',
    );
  });
  for (final callback in [
    'com.vihx.motion://oauth/google?flowId=different-flow&ticket=${'t' * 43}',
    'https://untrusted.example/google?flowId=flow-id&ticket=${'t' * 43}',
    'com.vihx.motion://oauth/google?flowId=flow-id&error=account_exists',
    'com.vihx.motion://oauth/google?flowId=flow-id',
  ]) {
    test(
      'invalid/cancelled Google callback never creates a session: $callback',
      () async {
        var requests = 0;
        final api = MotionApi(
          googleBrowser: (_) async => callback,
          client: MockClient((request) async {
            requests++;
            return http.Response(
              jsonEncode({
                'flowId': 'flow-id',
                'authorizationUrl':
                    'https://accounts.google.com/o/oauth2/v2/auth',
              }),
              200,
            );
          }),
        );
        addTearDown(api.dispose);
        await expectLater(api.signInWithGoogle(), throwsA(isA<ApiFailure>()));
        expect(api.signedIn, false);
        expect(requests, 1);
      },
    );
  }
  test('untrusted authorization URL is never opened in the browser', () async {
    var opened = false;
    final api = MotionApi(
      googleBrowser: (_) async {
        opened = true;
        return '';
      },
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'flowId': 'id',
            'authorizationUrl': 'https://untrusted.example/login',
          }),
          200,
        ),
      ),
    );
    addTearDown(api.dispose);
    await expectLater(api.signInWithGoogle(), throwsA(isA<ApiFailure>()));
    expect(opened, false);
    expect(api.signedIn, false);
  });
}
