import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Cloud accounts are independent of the on-device emergency service.
/// An expired cloud session must never stop an active SOS or sensor monitoring.
class MotionApi extends ChangeNotifier {
  MotionApi({
    http.Client? client,
    FlutterSecureStorage? storage,
    Uri? baseUrl,
    Future<String> Function(String url)? googleBrowser,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       _googleBrowser = googleBrowser ?? _openGoogleBrowser,
       baseUrl =
           baseUrl ??
           Uri.parse(
             const String.fromEnvironment(
               'MOTION_API_URL',
               defaultValue: 'https://motion-api.vihx.online',
             ),
           ) {
    if (this.baseUrl.scheme != 'https' ||
        this.baseUrl.host.isEmpty ||
        this.baseUrl.userInfo.isNotEmpty ||
        this.baseUrl.hasQuery ||
        this.baseUrl.hasFragment ||
        [
          'localhost',
          '127.0.0.1',
          '10.0.2.2',
          '::1',
        ].contains(this.baseUrl.host)) {
      throw ArgumentError('Motion API requires a public HTTPS URL.');
    }
  }
  final Uri baseUrl;
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final Future<String> Function(String url) _googleBrowser;
  bool _googleBusy = false;
  static Future<String> _openGoogleBrowser(String url) =>
      FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'com.vihx.motion',
      );
  String? _token;
  Map<String, dynamic>? user;
  bool restored = false;
  String? restoreError;
  bool _disposed = false;
  Future<void>? _restoring;
  static const _tokenKey = 'motion.cloud.accessToken.v1';
  bool get signedIn => _token != null && user != null;
  String get role => user?['role'] as String? ?? 'member';
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() => _restoring ??= _restoreOnce();
  Future<void> _restoreOnce() async {
    try {
      _token = await _storage.read(key: _tokenKey);
      if (_token != null) user = await request('GET', '/me');
    } on ApiFailure catch (e) {
      if (e.status != 401) restoreError = e.message;
    } catch (_) {
      restoreError = 'Không đọc được phiên đăng nhập. Hãy đăng nhập lại.';
    } finally {
      restored = true;
      _emit();
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    try {
      final uri = baseUrl.resolve(path);
      final response = await _client
          .send(
            http.Request(method, uri)
              ..followRedirects = false
              ..headers.addAll({
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                if (_token != null) 'Authorization': 'Bearer $_token',
              })
              ..body = data == null ? '' : jsonEncode(data),
          )
          .timeout(const Duration(seconds: 90));
      final text = await response.stream.bytesToString().timeout(
        const Duration(seconds: 20),
      );
      Map<String, dynamic> result;
      try {
        result = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        throw const ApiFailure(
          'API chưa sẵn sàng hoặc trả về dữ liệu không hợp lệ.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 && _token != null) {
          _token = null;
          user = null;
          await _storage.delete(key: _tokenKey);
          _emit();
        }
        throw ApiFailure(
          result['message'] as String? ?? 'Yêu cầu không thành công.',
          response.statusCode,
        );
      }
      return result;
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure('Kết nối quá hạn. Kiểm tra mạng và thử lại.');
    } catch (_) {
      throw const ApiFailure(
        'Không kết nối được máy chủ Motion. SOS trên thiết bị vẫn hoạt động.',
      );
    }
  }

  Future<void> completeLogin(String challengeId, String code) async {
    final result = await request('POST', '/auth/login/verify', {
      'challengeId': challengeId,
      'code': code,
    });
    await _acceptSession(result);
  }

  Future<void> _acceptSession(Map<String, dynamic> result) async {
    final token = result['accessToken'] as String;
    await _storage.write(key: _tokenKey, value: token);
    _token = token;
    user = result['user'] as Map<String, dynamic>;
    restoreError = null;
    _emit();
  }

  Future<void> signInWithGoogle({bool linkAccount = false}) async {
    if (_googleBusy) {
      throw const ApiFailure(
        'Đang có một phiên Google. Hãy hoàn tất hoặc đóng phiên trước.',
      );
    }
    _googleBusy = true;
    try {
      final random = Random.secure();
      final verifier = base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      ).replaceAll('=', '');
      final challenge = base64UrlEncode(
        sha256.convert(ascii.encode(verifier)).bytes,
      ).replaceAll('=', '');
      final flow = await request('POST', '/auth/google/start', {
        'codeChallenge': challenge,
        'linkAccount': linkAccount,
      });
      final authorization = Uri.parse(flow['authorizationUrl'] as String);
      if (authorization.scheme != 'https' ||
          authorization.host != 'accounts.google.com' ||
          authorization.path != '/o/oauth2/v2/auth' ||
          authorization.userInfo.isNotEmpty) {
        throw const ApiFailure('Địa chỉ đăng nhập Google không hợp lệ.');
      }
      final callback = Uri.parse(
        await _googleBrowser(authorization.toString()),
      );
      if (callback.scheme != 'com.vihx.motion' ||
          callback.host != 'oauth' ||
          callback.path != '/google' ||
          callback.queryParameters['flowId'] != flow['flowId']) {
        throw const ApiFailure(
          'Phiên Google không khớp. Hãy thử đăng nhập lại.',
        );
      }
      final error = callback.queryParameters['error'];
      if (error != null) {
        throw ApiFailure(switch (error) {
          'cancelled' => 'Bạn đã hủy đăng nhập Google.',
          'account_exists' => 'Email này đã có tài khoản Motion. Hãy đăng nhập bằng email, rồi chọn Liên kết Google trong tài khoản.',
          'email_mismatch' => 'Chọn tài khoản Google có cùng email với tài khoản Motion đang đăng nhập.',
          'already_linked' =>
            'Tài khoản Google đã được liên kết với người dùng khác.',
          'account_disabled' =>
            'Tài khoản không còn hoạt động. Hãy liên hệ quản trị viên.',
          'authorization_expired' =>
            'Phiên liên kết đã hết hạn. Hãy đăng nhập lại bằng email trước.',
          _ => 'Chưa đăng nhập được Google. Hãy thử lại hoặc dùng email.',
        });
      }
      final ticket = callback.queryParameters['ticket'];
      if (ticket == null || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(ticket)) {
        throw const ApiFailure('Google chưa trả về mã đăng nhập hợp lệ.');
      }
      final result = await request('POST', '/auth/google/exchange', {
        'flowId': flow['flowId'],
        'ticket': ticket,
        'codeVerifier': verifier,
      });
      await _acceptSession(result);
    } on ApiFailure {
      rethrow;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED' || e.code == 'CANCELLED') {
        throw const ApiFailure('Bạn đã hủy đăng nhập Google.');
      }
      throw const ApiFailure(
        'Không mở được trình đăng nhập Google. Hãy dùng email hoặc thử lại.',
      );
    } finally {
      _googleBusy = false;
    }
  }

  Future<List<Map<String, dynamic>>> list(String path) async =>
      ((await request('GET', path))['items'] as List)
          .cast<Map<String, dynamic>>();
  Future<void> updateName(String name) async {
    user = await request('PATCH', '/me', {'name': name});
    _emit();
  }

  Future<void> logout() async {
    // Keep the token if server revocation fails, so the user can retry explicitly.
    await request('POST', '/auth/logout');
    await clearSession();
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    _token = null;
    user = null;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}
