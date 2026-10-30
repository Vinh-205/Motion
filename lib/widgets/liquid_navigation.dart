import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_design.dart';
import 'morph_icon.dart';

class LiquidNavigation extends StatelessWidget {
  const LiquidNavigation({
    super.key,
    required this.index,
    required this.onChanged,
  });
  final int index;
  final ValueChanged<int> onChanged;
  static const labels = ['Theo dõi', 'Lịch sử', 'Liên hệ', 'Cài đặt'];
  static const icons = [
    AppGlyph.radar,
    AppGlyph.timeline,
    AppGlyph.users,
    AppGlyph.sliders,
  ];
  static const active = [
    AppGlyph.activity,
    AppGlyph.history,
    AppGlyph.contact,
    AppGlyph.settings,
  ];
  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 420);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: light ? .10 : .26),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            key: const Key('liquidNavigation'),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.colors.surface.withValues(alpha: light ? .86 : .88),
                  context.colors.surface.withValues(alpha: light ? .58 : .66),
                ],
              ),
              border: Border.all(
                color: light
                    ? Colors.white.withValues(alpha: .95)
                    : Colors.white.withValues(alpha: .16),
                width: 1.2,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, bounds) => Stack(
                children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    left: bounds.maxWidth / 4 * index,
                    top: 0,
                    bottom: 0,
                    width: bounds.maxWidth / 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.lime.withValues(
                              alpha: light ? .20 : .24,
                            ),
                            context.colors.lime.withValues(alpha: .08),
                          ],
                        ),
                        border: Border.all(
                          color: context.colors.lime.withValues(alpha: .28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.lime.withValues(alpha: .08),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: i == index,
                            button: true,
                            label: labels[i],
                            excludeSemantics: true,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(25),
                                onTap: () => onChanged(i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 4,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      MorphIcon(
                                        icons[i],
                                        alternate: active[i],
                                        active: i == index,
                                        size: 24,
                                        color: i == index
                                            ? context.colors.lime
                                            : context.colors.muted,
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          labels[i],
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: i == index
                                                ? FontWeight.w800
                                                : FontWeight.w500,
                                            color: i == index
                                                ? context.colors.ink
                                                : context.colors.muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
