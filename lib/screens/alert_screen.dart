import '../widgets/morph_icon.dart';

import 'package:flutter/material.dart';

import '../models/fall_event.dart';
import '../services/app_controller.dart';
import '../widgets/app_design.dart';
import '../widgets/motion_orbit.dart';
import '../widgets/emergency_services.dart';

class AlertScreen extends StatelessWidget {
  const AlertScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final sos = c.sosActive;
    final color = sos ? context.colors.red : context.colors.orange;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                key: ValueKey(sos ? 'sosResult' : 'fallConfirmation'),
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      MorphIcon(
                        AppGlyph.warning,
                        alternate: AppGlyph.siren,
                        active: sos,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          sos
                              ? c.sosIsSimulation
                                    ? 'SOS / CHẾ ĐỘ MÔ PHỎNG'
                                    : 'SOS / SMS QUA SIM'
                              : 'MOTION / CẦN BẠN XÁC NHẬN',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    sos ? 'SOS ĐƯỢC KÍCH HOẠT' : 'NGHI NGỜ TÉ NGÃ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sos
                        ? 'Bạn không cần đối mặt một mình.'
                        : 'Bạn có ổn không?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, color: context.colors.ink),
                  ),
                  const SizedBox(height: 14),
                  MotionOrbit(
                    active: true,
                    color: color,
                    child: sos
                        ? Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                            child: MorphIcon(
                              AppGlyph.siren,
                              color: context.colors.background,
                              size: 54,
                            ),
                          )
                        : SizedBox(
                            width: 158,
                            height: 158,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      end:
                                          c.remainingSeconds /
                                          c.countdownSeconds,
                                    ),
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 450),
                                    builder: (context, value, _) =>
                                        CircularProgressIndicator(
                                          value: value,
                                          strokeWidth: 3,
                                          strokeCap: StrokeCap.round,
                                          color: color,
                                          backgroundColor: context.colors.line,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        child: Text(
                                          '00:${c.remainingSeconds.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 38,
                                            height: 1.1,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                            letterSpacing: -1.7,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'CÒN LẠI',
                                        style: TextStyle(
                                          fontSize: 8,
                                          letterSpacing: 1.6,
                                          color: context.colors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  if (sos) ...[
                    if (!c.sosIsSimulation && c.callDetail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SurfacePanel(child: Text(c.callDetail)),
                      ),
                    SurfacePanel(
                      child: Text(
                        c.sosMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ActionButton(
                      key: const Key('dismissSos'),
                      label: 'DỪNG ÂM SOS VÀ VỀ TRANG CHÍNH',
                      onPressed: c.dismissSos,
                    ),
                  ] else ...[
                    Text(
                      c.pendingSource == EventSource.demo
                          ? 'Đang trình diễn bằng dữ liệu mô phỏng'
                          : c.alertIsSimulation
                          ? 'SOS mô phỏng sẽ kích hoạt khi hết thời gian.'
                          : 'Hết thời gian sẽ gửi SMS đến ${c.contacts.length} liên hệ đã lưu và tiếp tục phát âm SOS.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ActionButton(
                      key: const Key('confirmSafe'),
                      label: 'TÔI ỔN',
                      icon: AppGlyph.check,
                      onPressed: c.confirmSafe,
                    ),
                    const SizedBox(height: 12),
                    ActionButton(
                      key: const Key('sendHelp'),
                      label: 'GỬI TRỢ GIÚP NGAY',
                      icon: AppGlyph.arrowUpRight,
                      color: context.colors.red,
                      onPressed: c.requestHelp,
                    ),
                  ],
                  const SizedBox(height: 24),
                  EmergencyServices(device: c.device),
                  const SizedBox(height: 18),
                  NoteLine(
                    (sos ? c.sosIsSimulation : c.alertIsSimulation)
                        ? 'Mô phỏng: không gửi SMS và không gọi điện. Hãy giữ ứng dụng mở trong lúc xác nhận.'
                        : 'SMS và cuộc gọi (nếu đã bật) được yêu cầu độc lập. Kết quả gửi SMS hoặc yêu cầu gọi không xác nhận người thân đã đọc hay bắt máy. Đóng SOS không kết thúc cuộc gọi đang diễn ra; dùng màn hình cuộc gọi của điện thoại.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
