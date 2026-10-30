import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/services/fall_detector.dart';
import 'package:cam_bien_te_nga/models/detection_config.dart';
import 'package:cam_bien_te_nga/services/sensor_service.dart';

void main() {
  test('Vector magnitude includes all three axes', () {
    expect(const Vector3(3, 4, 12).magnitude, 13);
  });
  for (final sensitivity in Sensitivity.values) {
    test('Complete timed sequence triggers once: $sensitivity', () {
      final d = FallDetector(
        config: DetectionConfig.forSensitivity(sensitivity),
      );
      void sample(int ms, double a, double g) => d.update(
        at: Duration(milliseconds: ms),
        magnitude: a,
        rotation: g,
        gyroFresh: true,
      );
      sample(0, 9.81, 0);
      sample(50, 2, 0);
      expect(d.state, FallState.possibleFall);
      sample(150, 35, 6);
      expect(d.state, FallState.impactDetected);
      sample(250, 10, 6);
      expect(d.state, FallState.waitingForStillness);
      final still = d.config.stillness.inMilliseconds;
      for (int t = 300; t < 300 + still; t += 50) {
        sample(t, 9.81, 0.1);
      }
      expect(d.state, FallState.waitingForStillness);
      sample(300 + still, 9.81, 0.1);
      expect(d.state, FallState.fallSuspected);
      sample(350 + still, 9.81, 0);
      expect(d.state, FallState.fallSuspected);
    });
  }
  test('Single high acceleration is not a fall', () {
    final d = FallDetector();
    d.update(at: Duration.zero, magnitude: 40, rotation: 0, gyroFresh: true);
    for (int t = 50; t < 6000; t += 50) {
      d.update(
        at: Duration(milliseconds: t),
        magnitude: 9.81,
        rotation: 0,
        gyroFresh: true,
      );
      expect(d.state, isNot(FallState.fallSuspected));
    }
    expect(d.state, FallState.normal);
  });
  test('Impact without rotation cannot trigger', () {
    final d = FallDetector();
    d.update(at: Duration.zero, magnitude: 2, rotation: 0, gyroFresh: true);
    d.update(
      at: const Duration(milliseconds: 50),
      magnitude: 35,
      rotation: 0,
      gyroFresh: true,
    );
    for (int t = 100; t < 6000; t += 50) {
      d.update(
        at: Duration(milliseconds: t),
        magnitude: 9.81,
        rotation: 0,
        gyroFresh: true,
      );
      expect(d.state, isNot(FallState.fallSuspected));
    }
  });
  test('Missing gyro and sensor gap discard the sequence', () {
    final d = FallDetector();
    d.update(at: Duration.zero, magnitude: 2, rotation: 5, gyroFresh: true);
    d.update(
      at: const Duration(milliseconds: 50),
      magnitude: 35,
      rotation: 5,
      gyroFresh: false,
    );
    expect(d.state, FallState.normal);
    d.update(
      at: const Duration(milliseconds: 100),
      magnitude: 2,
      rotation: 5,
      gyroFresh: true,
    );
    d.update(
      at: const Duration(seconds: 3),
      magnitude: 9.81,
      rotation: 0,
      gyroFresh: true,
    );
    expect(d.state, FallState.normal);
  });
  test(
    'Repeated motion interrupts stillness; no fall before full quiet window',
    () {
      final d = FallDetector();
      void sample(int ms, double a, double g) => d.update(
        at: Duration(milliseconds: ms),
        magnitude: a,
        rotation: g,
        gyroFresh: true,
      );
      sample(0, 2, 0);
      sample(100, 30, 5);
      sample(200, 10, 5);
      for (int t = 250; t <= 6000; t += 50) {
        sample(t, t % 1000 == 0 ? 16 : 9.81, 0);
        expect(d.state, isNot(FallState.fallSuspected));
      }
    },
  );
  test('Sensitivity changes thresholds in the correct direction', () {
    expect(
      DetectionConfig.forSensitivity(Sensitivity.high).impact,
      lessThan(DetectionConfig.forSensitivity(Sensitivity.low).impact),
    );
  });
}
