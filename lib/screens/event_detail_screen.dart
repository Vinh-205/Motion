import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/fall_event.dart';
import '../services/app_controller.dart';
import '../widgets/app_design.dart';
import '../widgets/morph_icon.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    required this.controller,
  });
  final FallEvent event;
  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      // Status receipts can arrive while this page is open.
      final e = event.id.isEmpty
          ? event
          : controller.events.firstWhere(
              (e) => e.id == event.id,
              orElse: () => event,
            );
      final location = e.latitude != null && e.longitude != null;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết sự kiện'),
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
                  PageHeading(
                    index: e.simulated
                        ? 'LỊCH SỬ / MÔ PHỎNG'
                        : 'LỊCH SỬ / SOS QUA SIM',
                    title: e.sourceLabel,
                    description: formatTime(e.at),
                  ),
                  SurfacePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.outcomeLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: e.outcome == EventOutcome.safe
                                ? context.colors.lime
                                : context.colors.red,
                          ),
                        ),
                        if (e.detail.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(e.detail),
                        ],
                      ],
                    ),
                  ),
                  const SectionLabel('NGUYÊN NHÂN'),
                  Text(
                    e.reason.isEmpty
                        ? 'Sự kiện cũ chưa lưu thông tin nguyên nhân chi tiết.'
                        : e.reason,
                  ),
                  if (e.countdownSeconds != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        e.countdownSeconds == 0
                            ? 'SOS thủ công, không chờ đếm ngược.'
                            : 'Thời gian xác nhận: ${e.countdownSeconds} giây.',
                      ),
                    ),
                  if (e.sensitivity.isNotEmpty &&
                      e.source == EventSource.sensor)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Độ nhạy: ${switch (e.sensitivity) {
                          'low' => 'Thấp',
                          'high' => 'Cao',
                          _ => 'Trung bình',
                        }}.',
                      ),
                    ),
                  const SectionLabel('NGƯỜI LIÊN HỆ TẠI THỜI ĐIỂM ĐÓ'),
                  if (e.recipients.isNotEmpty) ...[
                    for (final r in e.recipients)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${r['name']}\n${r['phone']}'),
                            Text(
                              e.outcome != EventOutcome.sos
                                  ? 'Không gửi SMS.'
                                  : e.simulated
                                  ? 'Mô phỏng, không gửi SMS.'
                                  : '${r['detail'] ?? r['smsStatus']}',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else
                    Text(
                      e.recipientPhone.isEmpty
                          ? 'Sự kiện chưa lưu thông tin người nhận.'
                          : '${e.recipientName}\n${e.recipientPhone}',
                    ),
                  if (e.callStatus.isNotEmpty && e.callStatus != 'off') ...[
                    const SectionLabel('CUỘC GỌI SOS'),
                    Text(e.callPhone),
                    Text(
                      e.outcome != EventOutcome.sos
                          ? 'Chưa thực hiện cuộc gọi; cảnh báo đã được hủy.'
                          : e.callDetail.isEmpty
                          ? 'Chưa xác nhận kết quả yêu cầu gọi.'
                          : e.callDetail,
                    ),
                  ],
                  const SectionLabel('VỊ TRÍ ĐƯỢC GHI NHẬN'),
                  Text(
                    location
                        ? '${e.latitude!.toStringAsFixed(6)}, ${e.longitude!.toStringAsFixed(6)}'
                        : e.simulated
                        ? 'Mô phỏng không ghi vị trí.'
                        : 'Không có vị trí được lưu cho sự kiện này.',
                  ),
                  if (location) ...[
                    if (e.locationAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Lấy lúc ${formatTime(e.locationAt!)}'),
                      ),
                    if (e.locationAccuracy != null)
                      Text('Sai số khoảng ${e.locationAccuracy!.round()} m.'),
                    const SizedBox(height: 16),
                    ActionButton(
                      label: 'SAO CHÉP LIÊN KẾT BẢN ĐỒ',
                      icon: AppGlyph.mapPin,
                      outlined: true,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                'https://maps.google.com/?q=${e.latitude},${e.longitude}',
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép liên kết bản đồ.'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  NoteLine(
                    e.simulated ? 'Mô phỏng không gửi SMS hoặc gọi điện.' : 'Báo phát SMS không có nghĩa người nhận đã đọc tin hoặc đang trợ giúp. Vị trí là lần đo được ghi lại, không phải vị trí trực tiếp.',
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
