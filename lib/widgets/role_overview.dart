import 'package:flutter/material.dart';

import 'app_design.dart';
import 'motion_brand.dart';

/// Thẻ hồ sơ gọn ở đầu màn tài khoản; màu theo giao diện sáng/tối.
class RoleOverview extends StatelessWidget {
  const RoleOverview({
    super.key,
    required this.role,
    required this.label,
    required this.name,
    required this.email,
  });
  final String role, label, name, email;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('roleOverview'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.line.withValues(alpha: 0.65)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const MotionBrand(size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: context.colors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: context.colors.lime,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    email,
                    style: TextStyle(color: context.colors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          switch (role) {
            'admin' =>
              'Quản lý tài khoản, cấp quyền và phân công người hỗ trợ.',
            'staff' =>
              'Theo dõi lịch hẹn và hỗ trợ những người được phân công.',
            _ => 'Thông tin của bạn, liên hệ tin cậy và lịch hẹn xác nhận an toàn.',
          },
          style: TextStyle(
            color: context.colors.muted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}
