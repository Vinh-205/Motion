import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cam_bien_te_nga/services/shake_detector.dart';

List<int> _run(int ms, List<double> Function(int t) f) {
  final d = ShakeDetector();
  final hits = <int>[];
  for (var t = 0; t <= ms; t += 10) {
    final v = f(t);
    if (d.update(at: Duration(milliseconds: t), x: v[0], y: v[1], z: v[2])) {
      hits.add(t);
    }
  }
  return hits;
}

void main() {
  test('Vigorous side-to-side shake triggers within 2 seconds', () {
    final hits = _run(
      4000,
      (t) => t < 1000
          ? [0, 9.81, 0]
          : [25 * sin(2 * pi * 3.5 * (t - 1000) / 1000), 9.81, 0],
    );
    expect(hits.length, 1);
    expect(hits.first - 1000, lessThanOrEqualTo(2000));
  });
  test('Continuous shaking respects the 10 second cooldown', () {
    final hits = _run(
      15000,
      (t) => t < 500 ? [0, 9.81, 0] : [28 * sin(2 * pi * 4 * t / 1000), 9.81, 0],
    );
    expect(hits.length, 2);
    expect(hits[1] - hits[0], greaterThanOrEqualTo(10000));
  });
  test('Gentle shaking, running, jumping and walking do not trigger', () {
    expect(_run(8000, (t) => [10 * sin(2 * pi * 3 * t / 1000), 9.81, 0]), isEmpty);
    expect(
      _run(20000, (t) {
        final ph = t % 333;
        return [1.5 * sin(t / 50), ph < 30 ? 32.0 : ph < 150 ? 0.5 : 9.81, 0];
      }),
      isEmpty,
    );
    expect(
      _run(20000, (t) {
        final ph = t % 500;
        return [0, ph < 120 ? 3.0 : ph < 150 ? 26.0 : 9.81, 0];
      }),
      isEmpty,
    );
    expect(_run(20000, (t) => [0, 9.81 + 3 * sin(2 * pi * 2 * t / 1000), 0]), isEmpty);
  });
  test('A dropped phone that bounces does not count as shaking', () {
    expect(
      _run(8000, (t) {
        if (t < 1000) return [0, 9.81, 0];
        if (t < 1450) return [0.3, 0.5, 0.2];
        if (t == 1450) return [5, 60, 8];
        if (t == 1800) return [3, 28, 2];
        if (t == 2150) return [2, 21, 1];
        if (t < 2500) return [1.5 * sin(t / 10), 9.81 + 4 * sin(t / 15), 0];
        return [0, 9.81, 0];
      }),
      isEmpty,
    );
  });
}
