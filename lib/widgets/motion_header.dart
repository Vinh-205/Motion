import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../services/app_appearance.dart';
import 'app_design.dart';
import 'motion_brand.dart';
import 'morph_icon.dart';

class MotionHeader extends StatelessWidget {
  const MotionHeader({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final armed = controller.realSmsEnabled && controller.monitoring;
    final label = armed
        ? 'ĐÃ BẬT SOS'
        : controller.canSimulate && !controller.realSmsEnabled
        ? 'KIỂM THỬ'
        : 'CHƯA BẬT SOS';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
      child: Row(
        children: [
          const MotionBrand(size: 35),
          const SizedBox(width: 10),
          Text(
            'MOTION',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: 17,
              letterSpacing: 3,
              fontWeight: FontWeight.w800,
              color: context.colors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Semantics(
                  liveRegion: true,
                  child: AnimatedContainer(
                    key: const Key('sosLiveStatus'),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: armed
                          ? context.colors.lime.withValues(alpha: .12)
                          : Colors.transparent,
                      border: Border.all(
                        color: armed
                            ? context.colors.lime.withValues(alpha: .35)
                            : context.colors.line,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: armed
                                ? context.colors.lime
                                : context.colors.muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: .7,
                            fontWeight: FontWeight.w700,
                            color: armed
                                ? context.colors.lime
                                : context.colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (AppearanceScope.of(context) case final appearance?)
            IconButton(
              key: const Key('toggleAppearance'),
              tooltip: appearance.isDark
                  ? 'Chuyển sang giao diện sáng'
                  : 'Chuyển sang giao diện tối',
              onPressed: appearance.toggle,
              icon: MorphIcon(
                AppGlyph.sun,
                alternate: AppGlyph.moon,
                active: appearance.isDark,
                size: 22,
                color: context.colors.ink,
              ),
            ),
        ],
      ),
    );
  }
}
