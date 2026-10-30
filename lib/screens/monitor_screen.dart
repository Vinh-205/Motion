import '../widgets/morph_icon.dart';

import 'package:flutter/material.dart';

import '../models/detection_config.dart';
import '../services/app_controller.dart';
import '../services/fall_detector.dart';
import '../widgets/app_design.dart';
import '../widgets/motion_orbit.dart';
import '../widgets/sensor_card.dart';
import 'start_monitoring_screen.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    void setup() => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StartMonitoringScreen(controller: c),
      ),
    );
    final ready =
        c.sensorReady &&
        c.monitoring &&
        c.foreground &&
        (c.realSmsEnabled || c.canSimulate) &&
        (!c.realSmsEnabled ||
            (c.nativeSensorReady && c.nativeSensorError.isEmpty));
    final checking = c.detector.state != FallState.normal;
    final status = !c.realSmsEnabled && !c.canSimulate
        ? c.nativeConfigured
              ? 'DỊCH VỤ ĐÃ DỪNG'
              : 'CHƯA THIẾT LẬP SOS'
        : !c.monitoring
        ? 'ĐÃ TẮT GIÁM SÁT'
        : !c.foreground
        ? 'TẠM DỪNG'
        : !ready
        ? 'CHỜ DỮ LIỆU CẢM BIẾN'
        : checking
        ? 'ĐANG KIỂM TRA'
        : 'ĐANG GIÁM SÁT';
    final color = !ready
        ? context.colors.muted
        : checking
        ? context.colors.orange
        : context.colors.lime;
    final magnitude = c.sensors.acceleration?.magnitude;
    final deviation = magnitude == null
        ? 0.0
        : (magnitude - DetectionConfig.gravity).abs();
    final signalAvailable =
        c.foreground &&
        c.sensors.accelerationAt != null &&
        c.now().difference(c.sensors.accelerationAt!).inMilliseconds < 2000;
    final movement = !signalAvailable
        ? 'Chưa có dữ liệu mới'
        : deviation < 1.3
        ? 'Yên tĩnh'
        : deviation < 4
        ? 'Chuyển động'
        : 'Chuyển động mạnh';
    return ListView(
      key: const PageStorageKey('monitor'),
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        const PageHeading(
          index: '01 / CHUYỂN ĐỘNG & AN TOÀN',
          title: 'Vững vàng.\nMỗi chuyển động.',
          description: 'Lắng nghe chuyển động. Chủ động an tâm.',
        ),
        ActionButton(
          key: const Key('openStartMonitoring'),
          label: c.backgroundMonitoring
              ? 'QUẢN LÝ GIÁM SÁT NỀN'
              : 'BẮT ĐẦU GIÁM SÁT NỀN',
          icon: AppGlyph.shieldCheck,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => StartMonitoringScreen(controller: c),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (c.nativeConfigured && !c.realSmsEnabled)
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: SurfacePanel(
              child: Text(
                'SOS thật chưa chạy. Vào Cài đặt để bật lại SOS qua SIM; hiện chưa gửi SMS tự động.',
                style: TextStyle(color: context.colors.orange),
              ),
            ),
          ),
        SurfacePanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  MorphIcon(AppGlyph.arrowUpRight, size: 17, color: color),
                ],
              ),
              MotionOrbit(active: ready, color: color),
              const SizedBox(height: 12),
              Text(
                !c.realSmsEnabled && !c.canSimulate
                    ? 'Bắt đầu bảo vệ.'
                    : !c.monitoring
                    ? 'Một nhịp nghỉ.'
                    : ready
                    ? checking
                          ? 'Đang lắng nghe.'
                          : 'Nhịp sống ổn định.'
                    : 'Đang kết nối.',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ready
                    ? c.detector.state.label
                    : (c.nativeSensorError.isNotEmpty
                              ? c.nativeSensorError
                              : c.sensors.error) ??
                          'Thiết lập SOS qua SIM để giám sát nền và gửi cảnh báo.',
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Giám sát chuyển động',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  Switch(
                    value: (c.realSmsEnabled || c.canSimulate) && c.monitoring,
                    onChanged: (value) => c.realSmsEnabled || c.canSimulate
                        ? c.setMonitoring(value)
                        : setup(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ActionButton(
          key: const Key('manualSos'),
          label: c.realSmsEnabled
              ? 'GỬI SOS QUA SIM'
              : c.canSimulate
              ? 'SOS KHẨN CẤP'
              : 'THIẾT LẬP ĐỂ GỬI SOS',
          icon: AppGlyph.siren,
          color: context.colors.red,
          onPressed: c.realSmsEnabled || c.canSimulate ? c.requestHelp : setup,
        ),
        const SizedBox(height: 10),
        if (c.canSimulate)
          ActionButton(
            key: const Key('simulateFall'),
            label: 'MÔ PHỎNG TÉ NGÃ',
            icon: AppGlyph.play,
            outlined: true,
            onPressed: c.simulate,
          ),
        const SectionLabel('DÒNG CHUYỂN ĐỘNG', trailing: 'm/s²'),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      magnitude?.toStringAsFixed(2) ?? '—',
                      style: const TextStyle(
                        fontSize: 49,
                        height: 1.1,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      movement,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: context.colors.lime,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                'Tổng gia tốc',
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    end: signalAvailable ? (deviation / 20).clamp(0.0, 1.0) : 0,
                  ),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    color: context.colors.lime,
                    backgroundColor: context.colors.line,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Đứng yên thường gần 9,81 m/s² vì có trọng lực.',
                style: TextStyle(color: context.colors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SectionLabel('TÍN HIỆU CẢM BIẾN', trailing: 'XYZ'),
        if (c.realSmsEnabled && c.monitoring)
          NoteLine(
            '${c.sensorMode == 'accelerometer' ? 'Chế độ gia tốc · không có gyroscope' : 'Gia tốc + con quay'} · ${c.sensorSampleHz.toStringAsFixed(0)} Hz thực tế (yêu cầu 100 Hz). ${c.detector.state.label}',
          ),
        SensorCard(
          title: 'Accelerometer',
          unit: 'm/s²',
          value: c.sensors.acceleration,
        ),
        if (c.realSmsEnabled && c.monitoring)
          NoteLine(
            'Ngưỡng va chạm hiện tại: ${c.impactThreshold.toStringAsFixed(1)} m/s² · điều chỉnh theo nền dao động 2 giây, vẫn cần đủ chuỗi và nằm yên 3 giây.',
          ),
        SensorCard(
          title: 'Gyroscope',
          unit: 'rad/s',
          value: c.sensors.rotation,
        ),
        if (!c.hasGyroscope || c.sensors.rotationWarning != null)
          const NoteLine(
            'Không có dữ liệu con quay khả dụng. Dấu — không phải 0 rad/s. Máy dùng chế độ gia tốc nếu được hỗ trợ.',
          ),
        if (c.realSmsEnabled && c.monitoring)
          ExpansionTile(
            key: const Key('detectionDiagnostics'),
            title: const Text('Tình trạng phát hiện'),
            trailing: const MorphIcon(AppGlyph.info, size: 20),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NoteLine(
                  c.detectionDetail.isEmpty
                      ? 'Đang chờ dữ liệu.'
                      : c.detectionDetail,
                ),
              ),
              if (c.lastDetectionRejection.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NoteLine(
                    'Lần gần nhất chưa đạt: ${c.lastDetectionRejection}',
                  ),
                ),
            ],
          ),
        const SizedBox(height: 6),
        NoteLine(
          c.realSmsEnabled
              ? c.backgroundEnabled
                    ? 'SOS qua SIM đang bật. Giám sát khi khóa màn hình nếu phát hiện tự động đang bật. Trạng thái không phải đánh giá sức khỏe.'
                    : 'Giám sát nền đã tắt. Vẫn phát hiện khi app mở nếu công tắc Phát hiện té ngã đang bật; SOS đang xử lý không bị hủy.'
              : 'Chưa bật SOS qua SIM. Các chỉ số cảm biến hiện tại không có nghĩa là giám sát SOS đã hoạt động.',
        ),
      ],
    );
  }
}
