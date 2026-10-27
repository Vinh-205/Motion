import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/services/fall_detector.dart';
import 'package:cam_bien_te_nga/models/detection_config.dart';

void main() {
  test('Repeated footfalls adapt threshold; stopping is safe, a stronger fall can still trigger', () {
    for (final gyro in [true, false]) {
      for (final thenFall in [true, false]) {
        final d = FallDetector(
          config: DetectionConfig.forSensitivity(Sensitivity.high),
        )..rotationAvailable = gyro;
        for (var at = 0; at < 20000; at += 10) {
          final phase = at % 400;
          final a = phase < 100
              ? 3.0
              : phase < 130
              ? 28.0
              : 9.81;
          expect(
            d.update(
              at: Duration(milliseconds: at),
              magnitude: a,
              rotation: 1.8,
              gyroFresh: gyro,
              accelerationDelta: 0.8,
            ),
            isNot(FallState.fallSuspected),
          );
        }
        expect(d.impactThreshold, greaterThan(20));
        for (var at = 20000; at <= 25000; at += 10) {
          final a = thenFall && at < 20100
              ? 2.0
              : thenFall && at == 20100
              ? 45.0
              : 9.81;
          final moving = thenFall && at >= 20100 && at <= 20300;
          final state = d.update(
            at: Duration(milliseconds: at),
            magnitude: a,
            rotation: moving ? 8 : 0,
            gyroFresh: gyro,
            accelerationDelta: moving ? 2 : 0,
          );
          expect(state == FallState.fallSuspected, thenFall && at >= 23310);
        }
      }
    }
  });
  for (final gyro in [true, false]) {
    for (final level in Sensitivity.values) {
      test(
        'Synthetic walking/running then sitting never triggers: $gyro $level',
        () {
          final d = FallDetector(config: DetectionConfig.forSensitivity(level))
            ..rotationAvailable = gyro;
          for (var at = 0; at <= 35000; at += 10) {
            final a = at < 15000
                ? 9.81 + 3 * sin(2 * pi * 2 * at / 1000)
                : at <= 30000
                ? 9.81 + 8 * sin(2 * pi * 3 * at / 1000)
                : 9.81;
            expect(
              d.update(
                at: Duration(milliseconds: at),
                magnitude: a,
                rotation: at <= 30000 ? 1.2 : 0,
                gyroFresh: gyro,
              ),
              isNot(FallState.fallSuspected),
            );
          }
        },
      );
      test('100 Hz fall sequence confirms after rest: $gyro $level', () {
        final d = FallDetector(config: DetectionConfig.forSensitivity(level))
          ..rotationAvailable = gyro;
        for (var at = 0; at <= 3310; at += 10) {
          final a = at < 100
              ? 2.0
              : at == 100
              ? 35.0
              : 9.81;
          final state = d.update(
            at: Duration(milliseconds: at),
            magnitude: a,
            rotation: at >= 100 && at <= 300 ? 8 : 0,
            gyroFresh: gyro,
            accelerationDelta: at >= 100 && at <= 300 ? 2 : 0,
          );
          expect(state == FallState.fallSuspected, at == 3310);
        }
      });
    }
  }
  test(
    'Accelerometer-only mode rejects a brief glitch and motion after impact',
    () {
      final d = FallDetector()..rotationAvailable = false;
      d.update(at: Duration.zero, magnitude: 2, rotation: 0, gyroFresh: false);
      d.update(
        at: const Duration(milliseconds: 10),
        magnitude: 35,
        rotation: 0,
        gyroFresh: false,
      );
      for (var at = 20; at <= 5000; at += 10) {
        expect(
          d.update(
            at: Duration(milliseconds: at),
            magnitude: 9.81,
            rotation: 0,
            gyroFresh: false,
          ),
          isNot(FallState.fallSuspected),
        );
      }
    },
  );
}
