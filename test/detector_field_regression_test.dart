import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/models/detection_config.dart';
import 'package:cam_bien_te_nga/services/fall_detector.dart';

void main() {
  test('First-sample impact is retained and sensitivity profiles differ', () {
    for (final peak in [20.0, 26.0, 35.0]) {
      for (final level in Sensitivity.values) {
        final d = FallDetector(config: DetectionConfig.forSensitivity(level));
        for (var at = 0; at <= 4000; at += 10) {
          d.update(
            at: Duration(milliseconds: at),
            magnitude: at == 0 ? peak : 9.81,
            rotation: at <= 300 ? 4 : 0,
            gyroFresh: true,
          );
        }
        final expected =
            peak == 35 ||
            (peak == 26 && level != Sensitivity.low) ||
            (peak == 20 && level == Sensitivity.high);
        expect(
          d.state == FallState.fallSuspected,
          expected,
          reason: '$peak $level',
        );
      }
    }
  });
  test(
    'High sensitivity caps adaptation and freezes a candidate threshold',
    () {
      final d = FallDetector(
        config: DetectionConfig.forSensitivity(Sensitivity.high),
      );
      for (var at = 0; at <= 30000; at += 10) {
        expect(
          d.update(
            at: Duration(milliseconds: at),
            magnitude: max(0.5, 9.81 + 19 * sin(at / 35)),
            rotation: 2,
            gyroFresh: true,
          ),
          isNot(FallState.fallSuspected),
        );
        expect(d.impactThreshold, inInclusiveRange(15, 17.25));
      }
      d.reset();
      for (var at = 0; at < 1000; at += 10) {
        d.update(
          at: Duration(milliseconds: at),
          magnitude: 9.81,
          rotation: 0,
          gyroFresh: true,
        );
      }
      d.update(
        at: const Duration(milliseconds: 1000),
        magnitude: 2,
        rotation: 0,
        gyroFresh: true,
      );
      final frozen = d.impactThreshold;
      for (var at = 1010; at <= 1400; at += 10) {
        d.update(
          at: Duration(milliseconds: at),
          magnitude: at % 20 == 0 ? 14 : 2,
          rotation: 2,
          gyroFresh: true,
        );
      }
      expect(d.impactThreshold, frozen);
    },
  );
  test('Long freefall plus strong impact no longer requires rotation', () {
    for (final level in Sensitivity.values) {
      final d = FallDetector(config: DetectionConfig.forSensitivity(level));
      final trigger = 170 + d.config.stillness.inMilliseconds;
      for (var at = 0; at <= trigger; at += 10) {
        final state = d.update(
          at: Duration(milliseconds: at),
          magnitude: at < 160
              ? 2
              : at == 160
              ? 35
              : 9.81,
          rotation: 0,
          gyroFresh: true,
        );
        expect(state == FallState.fallSuspected, at == trigger);
      }
      expect(d.triggerReason, contains('120 ms'));
      expect(d.triggerReason, contains('35.00'));
    }
  });
  test('Brief mild noise is tolerated; no warning before confirmation', () {
    final d = FallDetector(
      config: DetectionConfig.forSensitivity(Sensitivity.high),
    );
    d.update(at: Duration.zero, magnitude: 2, rotation: 0, gyroFresh: true);
    d.update(
      at: const Duration(milliseconds: 100),
      magnitude: 30,
      rotation: 5,
      gyroFresh: true,
    );
    d.update(
      at: const Duration(milliseconds: 200),
      magnitude: 9.81,
      rotation: 5,
      gyroFresh: true,
    );
    for (var at = 210; at <= 3400; at += 10) {
      d.update(
        at: Duration(milliseconds: at),
        magnitude: at % 1000 <= 30 ? 11.5 : 9.81,
        rotation: 0.1,
        gyroFresh: true,
      );
    }
    expect(d.state, FallState.fallSuspected);
    expect(d.triggerReason, contains('phần yên'));
  });
  test('Missing impact is explained rather than silently discarded', () {
    final d = FallDetector();
    d.update(at: Duration.zero, magnitude: 2, rotation: 0, gyroFresh: true);
    for (var at = 10; at <= 1600; at += 10) {
      d.update(
        at: Duration(milliseconds: at),
        magnitude: 9.81,
        rotation: 0,
        gyroFresh: true,
      );
    }
    expect(d.lastRejection, contains('va chạm'));
  });
}
