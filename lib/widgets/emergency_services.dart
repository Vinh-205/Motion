import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/device_safety_bridge.dart';
import 'app_design.dart';
import 'morph_icon.dart';

class EmergencyServices extends StatelessWidget {
  const EmergencyServices({super.key, required this.device});
  final DeviceSafetyBridge device;
  @override
  Widget build(BuildContext context) => SurfacePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gọi cơ quan khẩn cấp',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in [
              ('113', 'Cảnh sát phản ứng nhanh'),
              ('114', 'Cứu hỏa, Cứu nạn cứu hộ'),
              ('115', 'Cấp cứu y tế'),
            ])
              OutlinedButton(
                key: ValueKey('dial${item.$1}'),
                onPressed: () async {
                  try {
                    await device.command('dialEmergency', {'number': item.$1});
                  } on PlatformException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.message ?? 'Không mở được trình gọi điện.',
                          ),
                        ),
                      );
                    }
                  } on MissingPluginException {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Hãy cài bản Android mới để mở trình gọi điện.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MorphIcon(
                      AppGlyph.phone,
                      size: 17,
                      color: context.colors.lime,
                    ),
                    const SizedBox(width: 8),
                    Text('${item.$1} · ${item.$2}'),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Mở trình gọi điện để bạn xác nhận gọi. Không gửi SMS SOS tự động đến các số này.',
          style: TextStyle(
            color: context.colors.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
