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
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const EmergencyCardPreviewScreen(),
                          ),
                        ),
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

/// Xem thẻ đã lưu ngay trong ứng dụng. Màn khóa sau SOS vẫn dùng Activity native riêng;
/// xem từ trong app không phụ thuộc cách từng hãng máy xử lý Activity phụ.
class EmergencyCardPreviewScreen extends StatefulWidget {
  const EmergencyCardPreviewScreen({super.key});
  @override
  State<EmergencyCardPreviewScreen> createState() =>
      _EmergencyCardPreviewScreenState();
}

class _EmergencyCardPreviewScreenState
    extends State<EmergencyCardPreviewScreen> {
  Map<String, dynamic>? card;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await DeviceSafetyBridge.channel
          .invokeMapMethod<String, dynamic>('getEmergencyCard');
      if (mounted) setState(() => card = data ?? {});
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  String _field(String key) => (card?[key] as String? ?? '').trim();

  Widget _tile(BuildContext context, String title, String raw, String unit,
      {bool accent = false}) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent ? c.red.withValues(alpha: 0.14) : c.surface,
          borderRadius: BorderRadius.circular(16),
          border: accent ? null : Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: accent ? c.red : c.muted)),
            const SizedBox(height: 4),
            Text(raw.isEmpty ? '—' : '$raw$unit',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: accent ? c.red : c.ink)),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, List<(String, String)> rows) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rows[i].$1,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: c.muted)),
                    const SizedBox(height: 3),
                    rows[i].$2.isEmpty
                        ? Text('Chưa cung cấp',
                            style: TextStyle(
                                fontSize: 17,
                                fontStyle: FontStyle.italic,
                                color: c.muted))
                        : SelectableText(rows[i].$2,
                            style: TextStyle(fontSize: 17, color: c.ink)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('THẺ KHẨN CẤP')),
      body: SafeArea(
        child: failed
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Không đọc được thẻ. Dữ liệu chưa bị xóa.'),
                ),
              )
            : card == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                key: const Key('emergencyCardPreview'),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(_field('name').isEmpty ? 'Chưa có tên' : _field('name'),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: c.ink)),
                  const SizedBox(height: 4),
                  Text('Thông tin do người dùng tự khai, chưa được xác minh y tế.',
                      style: TextStyle(fontSize: 13, color: c.muted)),
                  const SizedBox(height: 18),
                  Row(
                    spacing: 8,
                    children: [
                      _tile(context, 'NHÓM MÁU', _field('bloodGroup'), '',
                          accent: true),
                      _tile(context, 'CHIỀU CAO', _field('heightCm'), ' cm'),
                      _tile(context, 'CÂN NẶNG', _field('weightKg'), ' kg'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _section(context, [
                    ('BỆNH NỀN', _field('conditions')),
                    ('DỊ ỨNG', _field('allergies')),
                    ('THUỐC ĐANG DÙNG', _field('medications')),
                  ]),
                  const SizedBox(height: 12),
                  _section(context, [
                    ('NGƯỜI LIÊN HỆ', _field('contactName')),
                    ('SỐ LIÊN HỆ', _field('contactPhone')),
                  ]),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ĐÓNG THẺ'),
                  ),
                ],
              ),
      ),
    );
  }
}
