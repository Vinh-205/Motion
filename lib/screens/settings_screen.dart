import 'package:flutter/material.dart';

import '../models/detection_config.dart';
import '../services/app_controller.dart';
import '../services/motion_api.dart';
import '../widgets/alert_sound_settings.dart';
import '../widgets/app_design.dart';
import '../widgets/morph_icon.dart';
import 'account_screen.dart';
import 'emergency_card_screen.dart';
import 'icon_licenses_screen.dart';
import 'sms_setup_screen.dart';
import 'start_monitoring_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller, this.cloudApi});
  final AppController controller;
  final MotionApi? cloudApi;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final available = c.realSmsEnabled || c.canSimulate;
    void openStart() => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StartMonitoringScreen(controller: c),
      ),
    );
    return ListView(
      key: const PageStorageKey('settings'),
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        const PageHeading(
          title: 'Cài đặt & quyền',
          description: 'Giám sát, cảnh báo và tài khoản trên thiết bị này.',
        ),
        const SectionLabel('Giám sát'),
        SurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  key: const Key('masterMonitoringSwitch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Phát hiện té ngã'),
                  subtitle: Text(
                    c.realSmsEnabled || c.canSimulate
                        ? 'Tự nhận biết chuyển động nghi ngờ té ngã.'
                        : 'Thiết lập SOS qua SIM trước khi bật.',
                  ),
                  value: available && c.monitoring,
                  onChanged: (value) =>
                      available ? c.setMonitoring(value) : openStart(),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  key: const Key('backgroundMonitoringSwitch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Giám sát khi rời app'),
                  subtitle: Text(
                    !c.monitoring
                        ? 'Cần bật Phát hiện té ngã để thu chuyển động.'
                        : 'Tắt: chỉ phát hiện khi app đang mở. SOS đang xử lý không bị hủy.',
                  ),
                  value: available && c.backgroundEnabled,
                  onChanged: (value) =>
                      available ? c.setBackgroundMonitoring(value) : openStart(),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  key: const Key('shakeSosSwitch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lắc mạnh để gọi SOS'),
                  subtitle: Text(
                    !c.monitoring
                        ? 'Cần bật Phát hiện té ngã để thu chuyển động.'
                        : 'Lắc mạnh qua lại khoảng 2 giây: hiện đếm ngược, không bấm TÔI ỔN thì gửi SOS.',
                  ),
                  value: available && c.shakeSosEnabled,
                  onChanged: (value) =>
                      available ? c.setShakeSos(value) : openStart(),
                ),
              ],
            ),
          ),
        ),
        const SectionLabel('Cảnh báo'),
        SurfacePanel(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Thời gian xác nhận',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${c.countdownSeconds} giây',
                    style: TextStyle(
                      color: context.colors.lime,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Thời gian để bấm TÔI ỔN trước khi gửi SOS.',
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
              Slider(
                value: c.countdownSeconds.toDouble(),
                min: 15,
                max: 30,
                divisions: 3,
                label: '${c.countdownSeconds} giây',
                onChanged: (v) => c.setCountdown(v.round()),
              ),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Text(
                'Độ nhạy phát hiện té ngã',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
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
                      selected: c.sensitivity == item,
                      selectedColor: context.colors.lime,
                      backgroundColor: context.colors.background,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: c.sensitivity == item
                            ? context.colors.background
                            : context.colors.muted,
                      ),
                      checkmarkColor: context.colors.background,
                      side: BorderSide(
                        color: c.sensitivity == item
                            ? context.colors.lime
                            : context.colors.line,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      onSelected: (_) => c.setSensitivity(item),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Độ nhạy cao bắt được cú ngã nhẹ hơn nhưng dễ báo nhầm hơn.',
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AlertSoundSettings(device: c.device),
        const SectionLabel('SOS & tài khoản'),
        ActionButton(
          key: const Key('openSmsSetup'),
          label: c.realSmsEnabled
              ? 'SOS QUA SIM · ĐANG BẬT'
              : 'THIẾT LẬP SOS QUA SIM',
          icon: AppGlyph.message,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SmsSetupScreen(controller: c),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ActionButton(
          label: 'THẺ THÔNG TIN KHẨN CẤP',
          icon: AppGlyph.contact,
          outlined: true,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const EmergencyCardScreen(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ActionButton(
          key: const Key('openCloudAccount'),
          label: 'TÀI KHOẢN & QUYỀN TRUY CẬP',
          icon: AppGlyph.user,
          outlined: true,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AccountScreen(controller: c, api: cloudApi),
            ),
          ),
        ),
        const SectionLabel('Về Motion'),
        const NoteLine(
          'Motion hỗ trợ phát hiện chuyển động nghi ngờ té ngã, không chẩn đoán đột quỵ hay mất ý thức. Không có cảnh báo không có nghĩa là không có tai nạn.',
        ),
        const SizedBox(height: 10),
        NoteLine(
          c.realSmsEnabled
              ? 'SOS qua SIM đang bật. Liên hệ và lịch sử được lưu trên thiết bị.'
              : 'Chưa bật SOS. Hãy thêm liên hệ, chọn SIM và cấp quyền gửi SMS trước khi sử dụng.',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const IconLicensesScreen(),
              ),
            ),
            icon: const MorphIcon(AppGlyph.info, size: 16),
            label: const Text('Giấy phép icon · morphicons / Lucide'),
          ),
        ),
      ],
    );
  }
}
