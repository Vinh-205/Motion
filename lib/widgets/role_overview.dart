import 'package:flutter/material.dart';

import 'motion_brand.dart';

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
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFF101412),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFF354036)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const MotionBrand(size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFD4F58B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          name,
          style: const TextStyle(
            color: Color(0xFFF2F3E9),
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          email,
          style: const TextStyle(color: Color(0xFFA4B0A2), fontSize: 12),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: Color(0xFF354036), height: 1),
        ),
        Text(
          switch (role) {
            'admin' =>
              'Quản lý tài khoản, cấp quyền và phân công người hỗ trợ.',
            'staff' =>
              'Theo dõi lịch hẹn và hỗ trợ những người được phân công.',
            _ => 'Thông tin của bạn, liên hệ tin cậy và lịch hẹn xác nhận an toàn.',
          },
          style: const TextStyle(
            color: Color(0xFFF2F3E9),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
