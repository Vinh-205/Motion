import 'morph_icon.dart';

import 'package:flutter/material.dart';

import '../services/sensor_service.dart';
import 'app_design.dart';

class SensorCard extends StatelessWidget {
  const SensorCard({
    super.key,
    required this.title,
    required this.unit,
    required this.value,
  });
  final String title, unit;
  final Vector3? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MorphIcon(
                title == 'Accelerometer' ? AppGlyph.gauge : AppGlyph.rotate3d,
                alternate: title == 'Accelerometer'
                    ? AppGlyph.activity
                    : AppGlyph.rotateCw,
                active: value != null,
                size: 19,
                color: context.colors.lime,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                unit,
                style: TextStyle(color: context.colors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i == 2 ? 0 : 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ['X', 'Y', 'Z'][i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: [
                              context.colors.lime,
                              context.colors.orange,
                              const Color(0xFFA3B9FF),
                            ][i],
                          ),
                        ),
                        const SizedBox(height: 7),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value == null
                                ? '—'
                                : [
                                    value!.x,
                                    value!.y,
                                    value!.z,
                                  ][i].toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 22,
                              letterSpacing: -0.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
