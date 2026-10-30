import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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
  MotionApi({http.Client? client, FlutterSecureStorage? storage, Uri? baseUrl})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage(),
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
  String? _token;
  Map<String, dynamic>? user;
  bool restored = false;
  String? restoreError;
  bool _disposed = false;
  static const _tokenKey = 'motion.cloud.accessToken.v1';
  bool get signedIn => _token != null && user != null;
  String get role => user?['role'] as String? ?? 'member';
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
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
          .timeout(const Duration(seconds: 20));
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
    final token = result['accessToken'] as String;
    await _storage.write(key: _tokenKey, value: token);
    _token = token;
    user = result['user'] as Map<String, dynamic>;
    restoreError = null;
    _emit();
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
