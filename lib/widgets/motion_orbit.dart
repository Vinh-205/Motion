import 'morph_icon.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_design.dart';

/// Decorative motion identity, not a representation of sensor measurements.
class MotionOrbit extends StatefulWidget {
  const MotionOrbit({
    super.key,
    required this.active,
    required this.color,
    this.child,
  });
  final bool active;
  final Color color;
  final Widget? child;
  @override
  State<MotionOrbit> createState() => _MotionOrbitState();
}

class _MotionOrbitState extends State<MotionOrbit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant MotionOrbit oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      height: 210,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _OrbitPainter(
                _motion,
                widget.color,
                widget.active,
                context.colors.line,
              ),
            ),
          ),
          widget.child ??
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.12),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.6),
                  ),
                ),
                child: MorphIcon(
                  AppGlyph.pause,
                  alternate: AppGlyph.shield,
                  active: widget.active,
                  color: widget.color,
                  size: 39,
                ),
              ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Text(
              'MOTION / FIELD',
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 8,
                letterSpacing: 1.8,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Text(
              'XYZ · 3 AXES',
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 8,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.motion, this.color, this.active, this.lineColor)
    : super(repaint: motion);
  final Animation<double> motion;
  final Color color;
  final bool active;
  final Color lineColor;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 4);
    final radius = math.min(size.width * 0.39, 93.0);
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), line);
    canvas.drawLine(
      Offset(center.dx, 4),
      Offset(center.dx, size.height - 17),
      line,
    );
    canvas.drawCircle(center, radius, line);
    canvas.drawCircle(center, radius * 0.72, line);
    for (var i = 0; i < 48; i++) {
      final angle = i * math.pi / 24;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (radius - (i % 4 == 0 ? 7 : 3)),
        center + direction * radius,
        line,
      );
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(motion.value * math.pi * 2);
    final glow = Paint()
      ..color = color.withValues(alpha: active ? 0.7 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final ellipse = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 2.5,
      height: radius * 0.95,
    );
    canvas.rotate(-0.55);
    canvas.drawOval(ellipse, glow);
    canvas.rotate(1.1);
    canvas.drawOval(ellipse, glow..color = color.withValues(alpha: 0.2));
    canvas.drawCircle(Offset(radius * 1.25, 0), 4, Paint()..color = color);
    canvas.restore();
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 5),
      -math.pi / 2,
      math.pi * 0.35,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.active != active ||
      oldDelegate.motion != motion;
}
