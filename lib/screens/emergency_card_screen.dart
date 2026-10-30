import 'package:flutter/material.dart';

import '../services/device_safety_bridge.dart';
import '../widgets/app_design.dart';

/// The phone wearer's card is deliberately local and independent of cloud login.
class EmergencyCardScreen extends StatefulWidget {
  const EmergencyCardScreen({super.key});
  @override
  State<EmergencyCardScreen> createState() => _EmergencyCardScreenState();
}

class _EmergencyCardScreenState extends State<EmergencyCardScreen> {
  static const fields = {
    'name': 'Họ và tên',
    'conditions': 'Bệnh nền',
    'allergies': 'Dị ứng',
    'medications': 'Thuốc đang dùng',
    'bloodGroup': 'Nhóm máu (tự khai)',
    'heightCm': 'Chiều cao (cm)',
    'weightKg': 'Cân nặng (kg)',
    'contactName': 'Tên người liên hệ',
    'contactPhone': 'Số liên hệ khẩn cấp',
  };
  final form = GlobalKey<FormState>();
  late final inputs = {
    for (final key in fields.keys) key: TextEditingController(),
  };
  bool loading = true, saving = false, share = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await DeviceSafetyBridge.channel.invokeMapMethod<String, dynamic>(
            'getEmergencyCard',
          ) ??
          {};
      if (!mounted) return;
      for (final key in inputs.keys) {
        inputs[key]!.text = data[key] as String? ?? '';
      }
      share = data['showWhenLocked'] == true;
    } catch (_) {
      error =
          'Không đọc được thẻ trên thiết bị. Hãy thử lại; dữ liệu chưa bị xóa.';
    }
    if (mounted) setState(() => loading = false);
  }

  String? _validate(String key, String value) {
    if (key == 'name' && value.isEmpty) {
      return 'Nhập tên người mang điện thoại.';
    }
    if (key == 'contactPhone' &&
        value.isNotEmpty &&
        !validEmergencyPhone(value)) {
      return 'Nhập số điện thoại hợp lệ.';
    }
    if (['heightCm', 'weightKg'].contains(key) && value.isNotEmpty) {
      final n = double.tryParse(value.replaceAll(',', '.'));
      if (n == null ||
          !n.isFinite ||
          n <= 0 ||
          n > (key == 'heightCm' ? 300 : 650)) {
        return 'Giá trị không hợp lệ.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    for (final entry in inputs.entries) {
      final problem = _validate(entry.key, entry.value.text.trim());
      if (problem != null) {
        setState(() => error = '${fields[entry.key]}: $problem');
        return;
      }
    }
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await DeviceSafetyBridge.channel.invokeMethod<void>('saveEmergencyCard', {
        for (final entry in inputs.entries) entry.key: entry.value.text.trim(),
        'showWhenLocked': share,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thẻ trên điện thoại này.')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Không lưu được thẻ. Hãy thử lại.');
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thẻ trên điện thoại?'),
        content: const Text('Xóa toàn bộ thông tin và tắt hiển thị khi khóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await DeviceSafetyBridge.channel.invokeMethod<void>(
        'deleteEmergencyCard',
      );
      if (!mounted) return;
      setState(() {
        for (final value in inputs.values) {
          value.clear();
        }
        share = false;
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Không xóa được thẻ.');
    }
  }

  @override
  void dispose() {
    for (final value in inputs.values) {
      value.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thẻ thông tin khẩn cấp')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Một thẻ cho người mang điện thoại',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const NoteLine(
                  'Lưu trên máy, dùng được khi mất mạng. Không tải lên API, không tự đổi theo tài khoản đăng nhập. Đăng xuất không xóa thẻ; hãy xóa hoặc sửa khi đổi người dùng điện thoại. Thông tin tự khai, không thay thế hồ sơ y tế.',
                ),
                for (final entry in fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      key: Key('card_${entry.key}'),
                      controller: inputs[entry.key],
                      maxLength:
                          [
                            'conditions',
                            'allergies',
                            'medications',
                          ].contains(entry.key)
                          ? 500
                          : entry.key == 'contactPhone'
                          ? 20
                          : ['heightCm', 'weightKg'].contains(entry.key)
                          ? 8
                          : entry.key == 'bloodGroup'
                          ? 12
                          : 80,
                      maxLines:
                          [
                            'conditions',
                            'allergies',
                            'medications',
                          ].contains(entry.key)
                          ? 3
                          : 1,
                      keyboardType: ['heightCm', 'weightKg'].contains(entry.key)
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : entry.key == 'contactPhone'
                          ? TextInputType.phone
                          : TextInputType.text,
                      decoration: InputDecoration(labelText: entry.value),
                      validator: (raw) =>
                          _validate(entry.key, raw?.trim() ?? ''),
                    ),
                  ),
                SwitchListTile.adaptive(
                  key: const Key('shareEmergencyCard'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cho xem khi khóa màn hình sau SOS'),
                  subtitle: const Text(
                    'Bất kỳ ai cầm máy có thể đọc các trường đã lưu qua thông báo SOS. Không mở khóa tài khoản hay các ứng dụng khác.',
                  ),
                  value: share,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => share = value),
                ),
                const NoteLine(
                  'Để có cảnh báo khi khóa: bật giám sát nền, cấp SMS/cuộc gọi trong thiết lập SOS, cho phép thông báo và kiểm tra quyền cảnh báo toàn màn hình. Android hoặc chế độ pin của hãng có thể hạn chế hiển thị; thẻ không tự mở khóa điện thoại.',
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await DeviceSafetyBridge.channel.invokeMethod<void>(
                        'openFullScreenSettings',
                      );
                    } catch (_) {
                      if (mounted) {
                        setState(() => error = 'Không mở được cài đặt quyền.');
                      }
                    }
                  },
                  child: const Text('QUYỀN CẢNH BÁO TOÀN MÀN HÌNH'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await DeviceSafetyBridge.channel.invokeMethod<void>(
                        'openAppSettings',
                      );
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => error = 'Không mở được cài đặt thiết bị.',
                        );
                      }
                    }
                  },
                  child: const Text('CÀI ĐẶT THÔNG BÁO VÀ PIN'),
                ),
                if (error != null)
                  Text(error!, style: TextStyle(color: context.colors.red)),
                FilledButton(
                  key: const Key('saveEmergencyCard'),
                  onPressed: saving ? null : _save,
                  child: Text(saving ? 'ĐANG LƯU…' : 'LƯU THẺ'),
                ),
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          try {
                            await DeviceSafetyBridge.channel.invokeMethod<void>(
                              'openEmergencyCard',
                            );
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => error = 'Không mở được bản xem trước.',
                              );
                            }
                          }
                        },
                  child: const Text('XEM THẺ ĐÃ LƯU'),
                ),
                TextButton(
                  onPressed: saving ? null : _delete,
                  child: const Text('XÓA THẺ'),
                ),
              ],
            ),
          ),
  );
}
