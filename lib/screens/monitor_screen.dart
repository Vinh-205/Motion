import 'package:flutter/material.dart';

import '../models/detection_config.dart';
import '../services/app_controller.dart';
import '../services/fall_detector.dart';
import '../widgets/app_design.dart';
import '../widgets/morph_icon.dart';
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
          title: 'Giám sát',
          description: 'Trạng thái bảo vệ và nút SOS khẩn cấp.',
        ),
        if (c.nativeConfigured && !c.realSmsEnabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SurfacePanel(
              padding: const EdgeInsets.all(16),
              child: Text(
                'SOS thật chưa chạy. Vào Cài đặt để bật lại SOS qua SIM; hiện chưa gửi SMS tự động.',
                style: TextStyle(color: context.colors.orange),
              ),
            ),
          ),
        // Thẻ trạng thái: một dòng trạng thái, một dòng giải thích, một công tắc.
        SurfacePanel(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        letterSpacing: .6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  ready
                      ? c.detector.state.label
                      : (c.nativeSensorError.isNotEmpty
                                ? c.nativeSensorError
                                : c.sensors.error) ??
                            'Thiết lập SOS qua SIM để giám sát nền và gửi cảnh báo.',
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Giám sát chuyển động'),
                  subtitle: c.shakeSosEnabled
                      ? const Text('Kèm lắc mạnh để gọi SOS')
                      : null,
                  value: (c.realSmsEnabled || c.canSimulate) && c.monitoring,
                  onChanged: (value) => c.realSmsEnabled || c.canSimulate
                      ? c.setMonitoring(value)
                      : setup(),
                ),
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
        ActionButton(
          key: const Key('openStartMonitoring'),
          label: c.backgroundMonitoring
              ? 'QUẢN LÝ GIÁM SÁT NỀN'
              : 'BẮT ĐẦU GIÁM SÁT NỀN',
          icon: AppGlyph.shieldCheck,
          outlined: true,
          onPressed: setup,
        ),
        if (c.canSimulate) ...[
          const SizedBox(height: 10),
          ActionButton(
            key: const Key('simulateFall'),
            label: 'MÔ PHỎNG TÉ NGÃ',
            icon: AppGlyph.play,
            outlined: true,
            onPressed: c.simulate,
          ),
        ],
        const SectionLabel('Nâng cao'),
        // Số liệu kỹ thuật: thu gọn mặc định để màn chính gọn gàng.
        Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            key: const PageStorageKey('sensorDetails'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Chi tiết cảm biến'),
            subtitle: Text(
              magnitude == null
                  ? movement
                  : '${magnitude.toStringAsFixed(2)} m/s² · $movement',
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            ),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: signalAvailable
                      ? (deviation / 20).clamp(0.0, 1.0)
                      : 0,
                  minHeight: 5,
                  color: context.colors.lime,
                  backgroundColor: context.colors.line,
                ),
              ),
              const SizedBox(height: 8),
              const NoteLine('Đứng yên thường gần 9,81 m/s² vì có trọng lực.'),
              if (c.realSmsEnabled && c.monitoring) ...[
                const SizedBox(height: 8),
                NoteLine(
                  '${c.sensorMode == 'accelerometer' ? 'Chế độ gia tốc · không có gyroscope' : 'Gia tốc + con quay'} · ${c.sensorSampleHz.toStringAsFixed(0)} Hz thực tế (yêu cầu 100 Hz). Ngưỡng va chạm hiện tại ${c.impactThreshold.toStringAsFixed(1)} m/s².',
                ),
              ],
              const SizedBox(height: 12),
              SensorCard(
                title: 'Accelerometer',
                unit: 'm/s²',
                value: c.sensors.acceleration,
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
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (c.realSmsEnabled && c.monitoring)
          Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              key: const PageStorageKey('detectionDiagnostics'),
              tilePadding: EdgeInsets.zero,
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
          ),
        const SizedBox(height: 12),
        NoteLine(
          c.realSmsEnabled
              ? c.backgroundEnabled
                    ? 'SOS qua SIM đang bật và giám sát cả khi khóa màn hình. Đây không phải đánh giá sức khỏe.'
                    : 'Giám sát nền đã tắt: chỉ phát hiện khi app đang mở. SOS đang xử lý không bị hủy.'
              : 'Chưa bật SOS qua SIM. Số liệu cảm biến không có nghĩa là SOS đã hoạt động.',
        ),
      ],
    );
  }
}
