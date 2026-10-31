import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../widgets/app_design.dart';
import '../widgets/morph_icon.dart';
import 'sms_setup_screen.dart';

class StartMonitoringScreen extends StatefulWidget {
  const StartMonitoringScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<StartMonitoringScreen> createState() => _StartMonitoringScreenState();
}

class _StartMonitoringScreenState extends State<StartMonitoringScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller.refreshDevice();
  }

  Future<void> _start() async {
    if (_busy) return;
    final c = widget.controller;
    if (!c.realSmsEnabled) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => SmsSetupScreen(controller: c)),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (c.backgroundReady) {
        await c.leaveToHome();
      } else {
        await c.startBackgroundMonitoring();
        if (mounted && !c.notificationPermission) {
          _error = 'Hãy cho phép thông báo để thấy cảnh báo và nút TÔI ỔN khi ở ngoài app.';
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bắt đầu giám sát'),
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
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const PageHeading(
                    index: 'MOTION / BẢO VỆ TRONG NỀN',
                    title: 'Bạn tiếp tục.\nMotion lắng nghe.',
                    description: 'Bật giám sát rồi về Home hoặc khóa màn hình.',
                  ),
                  SurfacePanel(
                    child: Column(
                      children: [
                        MorphIcon(
                          AppGlyph.shield,
                          alternate: AppGlyph.shieldCheck,
                          active: c.backgroundReady,
                          size: 44,
                          color: c.backgroundReady
                              ? context.colors.lime
                              : context.colors.muted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          c.backgroundReady
                              ? 'GIÁM SÁT NỀN ĐANG SẴN SÀNG'
                              : c.realSmsEnabled &&
                                    c.monitoring &&
                                    !c.backgroundEnabled
                              ? 'CHỈ GIÁM SÁT KHI MỞ APP'
                              : c.backgroundMonitoring
                              ? 'ĐANG KIỂM TRA ĐIỀU KIỆN'
                              : 'CHƯA BẬT GIÁM SÁT NỀN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colors.lime,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Giám sát nền bật: tiếp tục khi rời app. Tắt giám sát nền: vẫn phát hiện khi mở app; không hủy SOS đang xử lý.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_error != null ||
                      c.deviceError.isNotEmpty ||
                      c.nativeSensorError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error ??
                            (c.nativeSensorError.isNotEmpty
                                ? c.nativeSensorError
                                : c.deviceError),
                        style: TextStyle(color: context.colors.orange),
                      ),
                    ),
                  ActionButton(
                    key: const Key('startBackgroundMonitoring'),
                    label: _busy
                        ? 'ĐANG XỬ LÝ…'
                        : !c.realSmsEnabled
                        ? 'THIẾT LẬP VÀ BẬT SOS QUA SIM'
                        : c.backgroundReady
                        ? 'VỀ HOME · GIỮ GIÁM SÁT'
                        : c.backgroundMonitoring
                        ? 'KIỂM TRA LẠI GIÁM SÁT'
                        : 'BẮT ĐẦU GIÁM SÁT',
                    icon: c.backgroundReady
                        ? AppGlyph.arrowUpRight
                        : AppGlyph.shieldCheck,
                    onPressed: _start,
                  ),
                  if (c.realSmsEnabled && c.backgroundEnabled && c.monitoring)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ActionButton(
                        key: const Key('stopBackgroundMonitoring'),
                        label: 'TẮT GIÁM SÁT NỀN',
                        color: context.colors.orange,
                        outlined: true,
                        icon: AppGlyph.pause,
                        onPressed: () async {
                          if (!_busy) await c.setBackgroundMonitoring(false);
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    key: const Key('monitoringDetails'),
                    title: const Text('Kiểm tra và cài đặt thiết bị'),
                    trailing: const MorphIcon(AppGlyph.settings, size: 21),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      const SectionLabel('KIỂM TRA TRƯỚC KHI RỜI APP'),
                      if (c.deviceModel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: NoteLine(
                            '${c.deviceModel} · Android ${c.androidVersion}',
                          ),
                        ),
                      _Check(
                        label: 'Người liên hệ khẩn cấp',
                        detail: c.contactPhone.isEmpty
                            ? 'Chọn và lưu trong thiết lập SOS.'
                            : c.contactName,
                        ready: c.contactPhone.isNotEmpty,
                      ),
                      _Check(
                        label: 'Cảm biến gia tốc và xoay',
                        detail: c.sensorMode == 'accelerometer'
                            ? 'Không có gyroscope. Giám sát giới hạn bằng gia tốc; kiểm tra tín hiệu trong Theo dõi.'
                            : !c.hasRequiredSensors
                            ? 'Không có cảm biến gia tốc. Chỉ dùng SOS thủ công.'
                            : c.backgroundMonitoring
                            ? (c.nativeSensorReady
                                  ? 'Đang nhận dữ liệu trong dịch vụ nền.'
                                  : 'Đang chờ dữ liệu cảm biến mới.')
                            : 'Kiểm tra khả năng cảm biến trên thiết bị.',
                        ready: c.backgroundMonitoring
                            ? c.nativeSensorReady
                            : c.hasRequiredSensors,
                      ),
                      _Check(
                        label: 'SMS qua SIM',
                        detail: !c.smsPermission
                            ? 'Chưa có quyền SMS. Mở thiết lập SOS để cấp quyền; cuộc gọi không thay thế tin nhắn.'
                            : c.simReady
                            ? 'Có SIM SMS mặc định; cần sóng và dịch vụ SMS.'
                            : 'Chọn SIM SMS mặc định trên điện thoại thật.',
                        ready:
                            c.realSmsEnabled && c.smsPermission && c.simReady,
                      ),
                      _Check(
                        label: 'Thông báo khẩn',
                        detail: 'Có nút TÔI ỔN và MỞ CẢNH BÁO.',
                        ready: c.notificationPermission,
                      ),
                      _Check(
                        label: 'Âm lượng báo thức',
                        detail: c.alarmVolume > 0
                            ? 'Nghe thử âm trong Cài đặt trước khi sử dụng.'
                            : 'Tăng âm lượng báo thức trong cài đặt điện thoại.',
                        ready: c.alarmVolume > 0,
                      ),
                      const SectionLabel('HIỂN THỊ KHI CÓ CẢNH BÁO'),
                      _Check(
                        label: 'Cảnh báo toàn màn hình',
                        detail: c.fullScreenAllowed
                            ? 'Android quyết định mở màn hình hoặc hiện thông báo nổi.'
                            : 'Chưa cho phép. Vẫn có âm thanh, đếm ngược và SMS.',
                        ready: c.fullScreenAllowed,
                      ),
                      ActionButton(
                        key: const Key('fullScreenSettings'),
                        label: 'CÀI ĐẶT CẢNH BÁO TOÀN MÀN HÌNH',
                        icon: AppGlyph.bell,
                        outlined: true,
                        onPressed: c.openFullScreenSettings,
                      ),
                      const SizedBox(height: 12),
                      _Check(
                        label: 'Giới hạn pin',
                        detail: c.batteryUnrestricted
                            ? 'Đã bỏ tối ưu pin của Android; vẫn cần kiểm tra cài đặt riêng của hãng.'
                            : 'Mở cài đặt ứng dụng → Pin, cho phép chạy nền / Không hạn chế nếu có.',
                        ready: c.batteryUnrestricted,
                      ),
                      if (!c.batteryUnrestricted) ...[
                        ActionButton(
                          key: const Key('batteryExemption'),
                          label: 'CHO PHÉP CHẠY NỀN KHÔNG GIỚI HẠN PIN',
                          icon: AppGlyph.settings,
                          onPressed: c.requestBatteryExemption,
                        ),
                        const SizedBox(height: 10),
                      ],
                      ActionButton(
                        key: const Key('monitoringAppSettings'),
                        label: 'CÀI ĐẶT THÔNG BÁO VÀ PIN',
                        icon: AppGlyph.settings,
                        outlined: true,
                        onPressed: c.openAppSettings,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const NoteLine(
                    'Nghi ngờ té ngã → âm thanh và rung → đếm ngược → SMS nếu không xác nhận. SMS không phụ thuộc việc mở được giao diện. Android có thể chỉ hiện thông báo nổi khi bạn đang dùng máy.',
                  ),
                  const SizedBox(height: 12),
                  const NoteLine(
                    'Không buộc dừng ứng dụng. Sau khi khởi động lại điện thoại, hãy mở Motion và bật lại giám sát. SOS qua SIM cần điện thoại thật; máy ảo không gửi SMS.',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Check extends StatelessWidget {
  const _Check({
    required this.label,
    required this.detail,
    required this.ready,
  });
  final String label, detail;
  final bool ready;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MorphIcon(
          AppGlyph.info,
          alternate: AppGlyph.circleCheck,
          active: ready,
          color: ready ? context.colors.lime : context.colors.orange,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                detail,
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
