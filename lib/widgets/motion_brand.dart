import 'package:flutter/material.dart';

import 'morph_icon.dart';

/// Matches the fixed charcoal/lime Android launcher mark in both themes.
class MotionBrand extends StatelessWidget {
  const MotionBrand({super.key, this.size = 38});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Motion',
    image: true,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF101412),
        borderRadius: BorderRadius.circular(size * 5 / 24),
      ),
      child: Center(
        child: MorphIcon(
          AppGlyph.orbit,
          size: size * .72,
          color: const Color(0xFFD4F58B),
        ),
      ),
    ),
  );
}
