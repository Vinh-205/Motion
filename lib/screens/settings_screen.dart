import '../widgets/morph_icon.dart';

import 'package:flutter/material.dart';

import '../models/detection_config.dart';
import '../services/app_controller.dart';
import '../widgets/app_design.dart';
import '../widgets/alert_sound_settings.dart';
import 'sms_setup_screen.dart';
import 'icon_licenses_screen.dart';
import 'start_monitoring_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('settings'),
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
    children: [
      const PageHeading(
        index: '04 / THEO NHỊP CỦA BẠN',
        title: 'Tinh chỉnh.\nĐúng nhịp.',
        description: 'Thiết lập trải nghiệm phù hợp với bạn.',
      ),
      ActionButton(
        label: 'BẮT ĐẦU GIÁM SÁT NỀN',
        icon: AppGlyph.shieldCheck,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => StartMonitoringScreen(controller: controller),
          ),
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
                    'Bật giám sát',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.realSmsEnabled
                        ? 'Tiếp tục khi khóa màn hình'
                        : 'Thiết lập SOS qua SIM trước khi bật',
                    style: TextStyle(color: context.colors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Switch(
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
            ? 'SOS qua SIM đang dùng dịch vụ giám sát nền. Liên hệ và lịch sử SMS được lưu trên thiết bị.'
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
