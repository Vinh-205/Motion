import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../widgets/app_design.dart';
import '../widgets/morph_icon.dart';
import 'contact_screen.dart';
import '../widgets/auto_call_settings.dart';

class SmsSetupScreen extends StatefulWidget {
  const SmsSetupScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<SmsSetupScreen> createState() => _SmsSetupScreenState();
}

class _SmsSetupScreenState extends State<SmsSetupScreen> {
  late final TextEditingController _owner = TextEditingController(
    text: widget.controller.ownerName,
  );
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _owner.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final c = widget.controller;
    if (!c.realSmsEnabled) {
      if (_owner.text.trim().isEmpty) {
        _form.currentState!.validate();
        setState(() => _error = 'Nhập tên để người thân nhận biết bạn.');
        return;
      }
      if (!_form.currentState!.validate()) return;
      if (c.contactPhone.isEmpty) {
        setState(
          () => _error = 'Hãy chọn và lưu người liên hệ khẩn cấp trước.',
        );
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bật SMS tự động?'),
          content: Text(
            'Sau ${c.countdownSeconds} giây không xác nhận, app sẽ tự gửi SMS đến tất cả ${c.contacts.length} liên hệ đã lưu và tiếp tục phát âm SOS. Nút SOS thủ công sẽ gửi ngay.\n\nSMS có thể tính phí cho từng người nhận và từng phần tin. Nếu không cấp quyền vị trí hoặc không lấy được vị trí, cảnh báo vẫn gửi. Kiểm tra kỹ danh sách người nhận trước khi bật.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ĐỂ SAU'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('BẬT SMS TỰ ĐỘNG'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    if (c.realSmsEnabled) {
      await c.disableRealSms();
      if (mounted && c.realSmsEnabled) _error = c.deviceError;
    } else {
      final error = await c.enableRealSms(_owner.text);
      if (mounted) _error = error;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return Scaffold(
        appBar: AppBar(
          title: const Text('SOS qua SIM'),
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: const MorphIcon(AppGlyph.arrowLeft),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const PageHeading(
                      title: 'Thiết lập SOS qua SIM',
                      description: 'Cảnh báo được gửi bằng SMS từ SIM mặc định trên điện thoại Android.',
                    ),
                    SurfacePanel(
                      child: Row(
                        children: [
                          MorphIcon(
                            AppGlyph.message,
                            alternate: AppGlyph.check,
                            active: c.realSmsEnabled,
                            color: context.colors.lime,
                            size: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.realSmsEnabled
                                      ? 'SMS QUA SIM ĐANG BẬT'
                                      : 'SMS QUA SIM ĐANG TẮT',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  c.contactPhone.isEmpty
                                      ? 'Chưa có người liên hệ.'
                                      : c.recipientSummary,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (c.realSmsEnabled && !c.monitoring)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: NoteLine(
                          'Giám sát tự động đang tắt. Bật công tắc Giám sát để phát hiện chuyển động; SOS thủ công vẫn có thể gửi SMS.',
                        ),
                      ),
                    if (c.realSmsEnabled && !c.notificationPermission)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: NoteLine(
                          'Chưa cho phép thông báo; bạn có thể không thấy nút TÔI ỔN trên màn hình khóa.',
                        ),
                      ),
                    const SizedBox(height: 16),
                    ActionButton(
                      key: const Key('setupContact'),
                      label: 'CHỌN NGƯỜI LIÊN HỆ',
                      icon: AppGlyph.bookUser,
                      outlined: true,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Người liên hệ'),
                              leading: IconButton(
                                tooltip: 'Quay lại',
                                icon: const MorphIcon(AppGlyph.arrowLeft),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            body: SafeArea(child: ContactScreen(controller: c)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AutoCallSettings(controller: c),
                    const SectionLabel('THÔNG TIN TRONG CẢNH BÁO'),
                    TextFormField(
                      key: const Key('ownerName'),
                      controller: _owner,
                      enabled: !c.realSmsEnabled && !_busy,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Tên của bạn',
                        prefixIcon: MorphIcon(AppGlyph.user),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nhập tên để người thân nhận biết bạn.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const SurfacePanel(
                      child: Text(
                        'Nội dung SMS gồm tên bạn, thời điểm nghi ngờ té ngã, việc chưa xác nhận và liên kết bản đồ nếu có. Vị trí ghi rõ thời điểm lấy và sai số. SMS không kết luận bạn đã bất tỉnh.',
                        style: TextStyle(fontSize: 13, height: 1.6),
                      ),
                    ),
                    const SectionLabel('QUYỀN TRÊN THIẾT BỊ'),
                    if (c.deviceModel.isNotEmpty)
                      NoteLine(
                        '${c.deviceModel} · Android ${c.androidVersion}',
                      ),
                    _PermissionLine(
                      glyph: AppGlyph.message,
                      label: 'Gửi SMS qua SIM',
                      granted: c.smsPermission,
                    ),
                    if (!c.smsPermission) ...[
                      const NoteLine(
                        'Chưa có quyền SMS: gọi điện được không có nghĩa tin nhắn đã gửi. Cấp quyền dưới đây trước khi bật SOS.',
                      ),
                      TextButton(
                        key: const Key('grantSmsPermission'),
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() {
                                  _busy = true;
                                  _error = null;
                                });
                                await c.requestSmsPermission();
                                if (!mounted) return;
                                setState(() {
                                  _busy = false;
                                  if (!c.smsPermission) _error = 'Chưa được cấp quyền SMS. Mở Cài đặt ứng dụng → Quyền → SMS. Nếu SMS bị khóa/không xuất hiện, trình cài đặt hoặc chính sách Android có thể đang hạn chế; app không thể tự cấp quyền.';
                                });
                              },
                        child: const Text('CẤP QUYỀN SMS'),
                      ),
                      TextButton(
                        key: const Key('smsAppSettings'),
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _error = null);
                                await c.openAppSettings();
                              },
                        child: const Text('MỞ CÀI ĐẶT QUYỀN SMS'),
                      ),
                    ],
                    if (c.sensorMode != 'full')
                      NoteLine(
                        c.sensorMode == 'accelerometer'
                            ? 'Máy không có gyroscope. Dùng chế độ gia tốc: giảm gia tốc → va chạm → ít chuyển động. Độ bao phủ thấp hơn; dữ liệu xoay không được giả lập.'
                            : 'Máy không có cảm biến gia tốc: vẫn có thể thiết lập SMS và SOS thủ công, không giám sát té ngã tự động.',
                      ),
                    _PermissionLine(
                      glyph: AppGlyph.mapPin,
                      label: 'Vị trí (không bắt buộc)',
                      granted: c.locationPermission,
                    ),
                    _PermissionLine(
                      glyph: AppGlyph.bell,
                      label: 'Thông báo và xác nhận an toàn',
                      granted: c.notificationPermission,
                    ),
                    if (_error != null ||
                        c.deviceError.isNotEmpty ||
                        c.nativeSensorError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: SurfacePanel(
                          child: Text(
                            _error ??
                                (c.nativeSensorError.isNotEmpty
                                    ? c.nativeSensorError
                                    : c.deviceError),
                            style: TextStyle(
                              color: context.colors.orange,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    ActionButton(
                      key: const Key('toggleRealSms'),
                      label: _busy
                          ? 'ĐANG THIẾT LẬP…'
                          : c.realSmsEnabled
                          ? 'TẮT SOS QUA SIM'
                          : 'BẬT SOS QUA SIM',
                      icon: c.realSmsEnabled
                          ? AppGlyph.pause
                          : AppGlyph.message,
                      color: c.realSmsEnabled
                          ? context.colors.orange
                          : context.colors.lime,
                      onPressed: _toggle,
                    ),
                    const SizedBox(height: 20),
                    const NoteLine(
                      'Giám sát nền dùng thông báo thường trực và có thể tăng mức dùng pin. Buộc dừng app, khởi động lại máy hoặc cơ chế tiết kiệm pin của hãng có thể làm gián đoạn; mở app và kiểm tra trạng thái trước khi sử dụng.',
                    ),
                    const SizedBox(height: 14),
                    const NoteLine(
                      'Cần điện thoại có SIM SMS mặc định, sóng và dịch vụ SMS hoạt động. Máy ảo chỉ dùng kiểm thử không gửi. Bản này chưa gọi điện đọc thông báo tự động.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PermissionLine extends StatelessWidget {
  const _PermissionLine({
    required this.glyph,
    required this.label,
    required this.granted,
  });
  final AppGlyph glyph;
  final String label;
  final bool granted;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        MorphIcon(glyph, color: context.colors.muted, size: 19),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        MorphIcon(
          AppGlyph.info,
          alternate: AppGlyph.circleCheck,
          active: granted,
          color: granted ? context.colors.lime : context.colors.muted,
          size: 19,
        ),
      ],
    ),
  );
}
