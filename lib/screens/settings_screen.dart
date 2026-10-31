import 'emergency_card_screen.dart';
import '../widgets/morph_icon.dart';

import 'package:flutter/material.dart';

import '../models/detection_config.dart';
import '../services/app_controller.dart';
import '../services/motion_api.dart';
import 'account_screen.dart';
import '../widgets/app_design.dart';
import '../widgets/alert_sound_settings.dart';
import 'sms_setup_screen.dart';
import 'icon_licenses_screen.dart';
import 'start_monitoring_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller, this.cloudApi});
  final AppController controller;
  final MotionApi? cloudApi;
  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('settings'),
    padding: EdgeInsets.fromLTRB(
      24,
      4,
      24,
      24 + MediaQuery.paddingOf(context).bottom,
    ),
    children: [
      const PageHeading(
        index: '04 / THEO NHỊP CỦA BẠN',
        title: 'Tinh chỉnh.\nĐúng nhịp.',
        description: 'Thiết lập trải nghiệm phù hợp với bạn.',
      ),
      ActionButton(
        key: const Key('openCloudAccount'),
        label: 'TÀI KHOẢN & QUYỀN TRUY CẬP',
        icon: AppGlyph.user,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                AccountScreen(controller: controller, api: cloudApi),
          ),
        ),
      ),
      const SizedBox(height: 12),
      ActionButton(
        label: 'THẺ THÔNG TIN KHẨN CẤP',
        icon: AppGlyph.contact,
        outlined: true,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const EmergencyCardScreen()),
        ),
      ),
      const SizedBox(height: 12),
      ActionButton(
        key: const Key('openSmsSetup'),
        label: controller.realSmsEnabled
            ? 'SOS QUA SIM · ĐANG BẬT'
            : 'THIẾT LẬP SOS QUA SIM',
        icon: AppGlyph.message,
        outlined: true,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SmsSetupScreen(controller: controller),
          ),
        ),
      ),
      const SizedBox(height: 18),
      SurfacePanel(
        child: Row(
          children: [
            MorphIcon(AppGlyph.radio, color: context.colors.lime, size: 25),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phát hiện té ngã',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.realSmsEnabled
                        ? 'Bật / tắt phát hiện tự động'
                        : 'Thiết lập SOS qua SIM trước khi bật',
                    style: TextStyle(color: context.colors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Switch(
              key: const Key('masterMonitoringSwitch'),
              value:
                  (controller.realSmsEnabled || controller.canSimulate) &&
                  controller.monitoring,
              onChanged: (value) {
                if (controller.realSmsEnabled || controller.canSimulate) {
                  controller.setMonitoring(value);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          StartMonitoringScreen(controller: controller),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SurfacePanel(
        child: Material(
          type: MaterialType.transparency,
          child: SwitchListTile.adaptive(
            key: const Key('backgroundMonitoringSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Giám sát khi rời app'),
            subtitle: Text(
              !controller.monitoring
                  ? 'Cần bật Phát hiện té ngã để thu chuyển động.'
                  : 'Tắt: vẫn phát hiện và cảnh báo khi mở app. SOS đang xử lý không bị hủy.',
            ),
            value:
                (controller.realSmsEnabled || controller.canSimulate) &&
                controller.backgroundEnabled,
            onChanged: (value) {
              if (controller.realSmsEnabled || controller.canSimulate) {
                controller.setBackgroundMonitoring(value);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        StartMonitoringScreen(controller: controller),
                  ),
                );
              }
            },
          ),
        ),
      ),
      const SizedBox(height: 12),
      SurfacePanel(
        child: Material(
          type: MaterialType.transparency,
          child: SwitchListTile.adaptive(
            key: const Key('shakeSosSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Lắc mạnh để gọi SOS'),
            subtitle: Text(
              !controller.monitoring
                  ? 'Cần bật Phát hiện té ngã để thu chuyển động.'
                  : 'Lắc mạnh qua lại khoảng 2 giây: hiện đếm ngược, không bấm TÔI ỔN thì gửi SOS.',
            ),
            value:
                (controller.realSmsEnabled || controller.canSimulate) &&
                controller.shakeSosEnabled,
            onChanged: (value) {
              if (controller.realSmsEnabled || controller.canSimulate) {
                controller.setShakeSos(value);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        StartMonitoringScreen(controller: controller),
                  ),
                );
              }
            },
          ),
        ),
      ),
      const SectionLabel('ÂM THANH CẢNH BÁO'),
      AlertSoundSettings(device: controller.device),
      const SectionLabel('KHOẢNG THỜI GIAN XÁC NHẬN'),
      SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${controller.countdownSeconds}',
                  style: TextStyle(
                    fontSize: 52,
                    height: 1,
                    letterSpacing: -2,
                    color: context.colors.lime,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 6),
                  child: Text(
                    'giây',
                    style: TextStyle(color: context.colors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Thời gian để bạn xác nhận trước khi kích hoạt SOS.',
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            ),
            Slider(
              value: controller.countdownSeconds.toDouble(),
              min: 15,
              max: 30,
              divisions: 3,
              label: '${controller.countdownSeconds} giây',
              onChanged: (v) => controller.setCountdown(v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '15 GIÂY',
                  style: TextStyle(
                    fontSize: 9,
                    color: context.colors.muted,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '30 GIÂY',
                  style: TextStyle(
                    fontSize: 9,
                    color: context.colors.muted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SectionLabel('ĐỘ NHẠY CHUYỂN ĐỘNG'),
      SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in Sensitivity.values)
                  ChoiceChip(
                    label: Text(switch (item) {
                      Sensitivity.low => 'Thấp',
                      Sensitivity.medium => 'Trung bình',
                      Sensitivity.high => 'Cao',
                    }),
                    selected: controller.sensitivity == item,
                    selectedColor: context.colors.lime,
                    backgroundColor: context.colors.background,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: controller.sensitivity == item
                          ? context.colors.background
                          : context.colors.muted,
                    ),
                    checkmarkColor: context.colors.background,
                    side: BorderSide(
                      color: controller.sensitivity == item
                          ? context.colors.lime
                          : context.colors.line,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    onSelected: (_) => controller.setSensitivity(item),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Độ nhạy cao có thể tăng cảnh báo nhầm. Thuật toán mang tính hỗ trợ và có thể bỏ sót sự kiện.',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.muted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
      const SectionLabel('HIỂU ĐÚNG VỀ MOTION'),
      const NoteLine(
        'Ứng dụng hỗ trợ phát hiện chuyển động nghi ngờ té ngã, không chẩn đoán đột quỵ hoặc mất ý thức. Không phát hiện cảnh báo không có nghĩa là không có tai nạn.',
      ),
      const SizedBox(height: 16),
      NoteLine(
        controller.realSmsEnabled
            ? 'SOS qua SIM đang bật. Giám sát khi rời app là tùy chọn riêng. Liên hệ và lịch sử được lưu trên thiết bị.'
            : 'Chưa bật giám sát SOS. Hãy thiết lập liên hệ, SIM và quyền gửi SMS trước khi sử dụng.',
      ),
      const SizedBox(height: 26),
      TextButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const IconLicensesScreen()),
        ),
        icon: const MorphIcon(AppGlyph.info, size: 16),
        label: const Text('Giấy phép icon · morphicons / Lucide'),
      ),
      Text(
        'MOTION / CẢM BIẾN TÉ NGÃ\nTHIẾT KẾ CHO NHỮNG CHUYỂN ĐỘNG ĐỜI THƯỜNG.',
        style: TextStyle(
          fontSize: 9,
          height: 1.8,
          letterSpacing: 1.1,
          color: context.colors.muted,
        ),
      ),
    ],
  );
}
