import '../widgets/morph_icon.dart';

import 'package:flutter/material.dart';

import '../models/fall_event.dart';
import '../services/app_controller.dart';
import '../widgets/app_design.dart';
import 'event_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final events = controller.events;
    final safe = events.where((e) => e.outcome == EventOutcome.safe).length;
    return ListView(
      key: const PageStorageKey('history'),
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        const PageHeading(
          title: 'Lịch sử sự kiện',
          description: 'Các lần cảnh báo, xác nhận an toàn và SOS đã gửi.',
        ),
        SurfacePanel(
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '${events.length}'.padLeft(2, '0'),
                  label: 'SỰ KIỆN',
                ),
              ),
              Container(height: 52, width: 1, color: context.colors.line),
              const SizedBox(width: 25),
              Expanded(
                child: _Metric(
                  value: '$safe'.padLeft(2, '0'),
                  label: 'XÁC NHẬN AN TOÀN',
                ),
              ),
            ],
          ),
        ),
        const SectionLabel('DÒNG THỜI GIAN', trailing: 'MỚI NHẤT TRƯỚC'),
        if (events.isEmpty)
          SurfacePanel(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(23),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.line),
                  ),
                  child: MorphIcon(
                    AppGlyph.timeline,
                    size: 40,
                    color: context.colors.lime,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Một khởi đầu yên bình.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  'Chưa có sự kiện SOS được ghi nhận.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.muted),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        for (var i = 0; i < events.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color:
                              (events[i].outcome == EventOutcome.safe
                                      ? context.colors.lime
                                      : context.colors.red)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: MorphIcon(
                          events[i].outcome == EventOutcome.safe
                              ? AppGlyph.check
                              : AppGlyph.siren,
                          color: events[i].outcome == EventOutcome.safe
                              ? context.colors.lime
                              : context.colors.red,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          events[i].sourceLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '#${events.length - i}',
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Text(
                    events[i].outcomeLabel,
                    style: TextStyle(
                      color: events[i].outcome == EventOutcome.safe
                          ? context.colors.lime
                          : context.colors.red,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    formatTime(events[i].at),
                    style: TextStyle(color: context.colors.muted, fontSize: 11),
                  ),
                  if (events[i].outcome == EventOutcome.sos)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        events[i].simulated
                            ? 'Đã ghi nhận · chưa gửi ra ngoài'
                            : events[i].detail,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.muted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: ValueKey('eventDetail$i'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EventDetailScreen(
                          event: events[i],
                          controller: controller,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('XEM CHI TIẾT'),
                        const SizedBox(width: 8),
                        MorphIcon(
                          AppGlyph.arrowUpRight,
                          size: 17,
                          color: context.colors.lime,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),
        const NoteLine(
          'Lịch sử SMS lưu trên thiết bị Android, tối đa 200 mục. Báo phát không xác nhận người thân đã đọc tin.',
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 40,
          letterSpacing: -1.5,
          color: context.colors.lime,
          height: 1.1,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: context.colors.muted,
          letterSpacing: 1,
        ),
      ),
    ],
  );
}
