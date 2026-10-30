import 'package:flutter/material.dart';

import '../services/motion_api.dart';
import '../services/app_controller.dart';
import '../widgets/morph_icon.dart';
import 'cloud_dashboard_screen.dart';

enum _AuthMode { login, register, forgot }

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.api, this.controller});
  final MotionApi? api;
  final AppController? controller;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final MotionApi api = widget.api ?? MotionApi();
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  final _name = TextEditingController(), _code = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  String? _challenge, _error, _notice;
  bool _busy = false, _obscure = true;
  @override
  void initState() {
    super.initState();
    if (!api.restored) api.restore();
  }

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _code]) {
      c.dispose();
    }
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_challenge == null) {
        final result = await api.request(
          'POST',
          switch (_mode) {
            _AuthMode.login => '/auth/login',
            _AuthMode.register => '/auth/register',
            _AuthMode.forgot => '/auth/forgot-password',
          },
          {
            'email': _email.text.trim(),
            if (_mode != _AuthMode.forgot) 'password': _password.text,
            if (_mode == _AuthMode.register) 'name': _name.text.trim(),
          },
        );
        if (mounted) {
          setState(() {
            _challenge = result['challengeId'] as String;
            _notice = result['message'] as String?;
            _code.clear();
            if (_mode == _AuthMode.forgot) _password.clear();
          });
        }
      } else if (_mode == _AuthMode.login) {
        await api.completeLogin(_challenge!, _code.text.trim());
        _password.clear();
        _code.clear();
      } else {
        await api.request(
          'POST',
          _mode == _AuthMode.register
              ? '/auth/verify-email'
              : '/auth/reset-password',
          {
            'challengeId': _challenge,
            'code': _code.text.trim(),
            if (_mode == _AuthMode.forgot) 'password': _password.text,
          },
        );
        if (mounted) {
          setState(() {
            _mode = _AuthMode.login;
            _challenge = null;
            _password.clear();
            _code.clear();
            _notice = 'Thành công. Hãy đăng nhập bằng mật khẩu và mã OTP mới.';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switch(_AuthMode mode) => setState(() {
    _mode = mode;
    _challenge = null;
    _error = null;
    _notice = null;
    _password.clear();
    _code.clear();
  });
  Future<void> _google() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await api.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: api,
    builder: (context, _) {
      if (!api.restored) {
        return Scaffold(
          appBar: AppBar(title: const Text('Tài khoản Motion')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (api.signedIn) {
        return CloudDashboardScreen(api: api, controller: widget.controller);
      }
      final title = _challenge != null
          ? (_mode == _AuthMode.forgot ? 'Đặt lại mật khẩu' : 'Nhập mã email')
          : switch (_mode) {
              _AuthMode.login => 'Chào bạn trở lại.',
              _AuthMode.register => 'Tạo tài khoản.',
              _AuthMode.forgot => 'Quên mật khẩu?',
            };
      return Scaffold(
        appBar: AppBar(title: const Text('MOTION / TÀI KHOẢN')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: MorphIcon(AppGlyph.shieldCheck, size: 52),
                ),
                const SizedBox(height: 24),
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 12),
                Text(
                  _challenge != null
                      ? 'Mã có hiệu lực 5 phút. Kiểm tra hộp thư đến và thư rác của ${_email.text.trim()}.'
                      : 'Quản lý liên hệ đám mây và Vòng an toàn. Giám sát và SOS qua SIM vẫn dùng độc lập trên điện thoại.',
                ),
                const SizedBox(height: 24),
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      if (_challenge == null) ...[
                        if (_mode == _AuthMode.register)
                          TextFormField(
                            controller: _name,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'Tên hiển thị',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Nhập tên của bạn'
                                : null,
                          ),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Email / tên đăng nhập',
                          ),
                          maxLength: 254,
                          validator: (v) =>
                              v != null &&
                                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(v.trim())
                              ? null
                              : 'Nhập email hợp lệ',
                        ),
                      ],
                      if (_challenge != null)
                        TextFormField(
                          controller: _code,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Mã OTP 6 số',
                          ),
                          validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                              ? null
                              : 'Nhập đủ 6 chữ số',
                        ),
                      if ((_challenge == null && _mode != _AuthMode.forgot) ||
                          (_challenge != null && _mode == _AuthMode.forgot))
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: _mode == _AuthMode.forgot
                                ? 'Mật khẩu mới'
                                : 'Mật khẩu',
                            suffixIcon: TextButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              child: Text(_obscure ? 'Hiện' : 'Ẩn'),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Nhập mật khẩu'
                              : v.length > 128 ||
                                    (_mode != _AuthMode.login && v.length < 10)
                              ? 'Dùng 10–128 ký tự'
                              : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_error ?? api.restoreError case final message?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_notice!),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _busy
                          ? 'Đang xử lý…'
                          : _challenge == null
                          ? 'TIẾP TỤC'
                          : 'XÁC NHẬN',
                    ),
                  ),
                ),
                if (_challenge != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _challenge = null;
                            _code.clear();
                            _notice = 'Bạn có thể xin mã mới sau 60 giây.';
                          }),
                    child: const Text('Quay lại / xin mã mới'),
                  ),
                if (_challenge == null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('googleSignIn'),
                    onPressed: _busy ? null : _google,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('TIẾP TỤC VỚI GOOGLE'),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _switch(
                            _mode == _AuthMode.register
                                ? _AuthMode.login
                                : _AuthMode.register,
                          ),
                    child: Text(
                      _mode == _AuthMode.register
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Tạo tài khoản bằng email',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _switch(
                            _mode == _AuthMode.forgot
                                ? _AuthMode.login
                                : _AuthMode.forgot,
                          ),
                    child: Text(
                      _mode == _AuthMode.forgot
                          ? 'Về đăng nhập'
                          : 'Quên mật khẩu',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Máy chủ: ${api.baseUrl.host}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
