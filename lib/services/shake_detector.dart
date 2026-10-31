import 'dart:collection';

/// Lắc mạnh qua lại để gọi SOS (bản Dart của ShakeDetector.kt).
///
/// Đếm các đỉnh gia tốc động (đã trừ trọng lực) đổi chiều liên tiếp trên cùng
/// một trục. Chạy bộ, nhảy hay té ngã chỉ tạo đỉnh mạnh một chiều nên không
/// kích hoạt.
class ShakeDetector {
  ShakeDetector({
    this.peakThreshold = 18,
    this.neededPeaks = 6,
    this.window = const Duration(seconds: 2),
    this.minGap = const Duration(milliseconds: 80),
    this.cooldown = const Duration(seconds: 10),
  });
  final double peakThreshold;
  final int neededPeaks;
  final Duration window, minGap, cooldown;
  final _gravity = List<double>.filled(3, 0);
  bool _gravityReady = false;
  final _peaks = Queue<Duration>();
  int _lastAxis = -1, _lastSign = 0;
  Duration? _lastPeakAt, _lastTriggerAt, _last;

  void reset() {
    _gravityReady = false;
    _peaks.clear();
    _lastAxis = -1;
    _lastSign = 0;
    _last = null;
  }

  bool update({
    required Duration at,
    required double x,
    required double y,
    required double z,
  }) {
    final values = [x, y, z];
    if (values.any((v) => !v.isFinite)) {
      reset();
      return false;
    }
    final gap = _last == null ? Duration.zero : at - _last!;
    _last = at;
    if (!_gravityReady ||
        gap.isNegative ||
        gap > const Duration(milliseconds: 400)) {
      for (var i = 0; i < 3; i++) {
        _gravity[i] = values[i];
      }
      _gravityReady = true;
      _peaks.clear();
      _lastSign = 0;
      _lastAxis = -1;
      return false;
    }
    // Lọc thông thấp ~0,5 s để ước lượng trọng lực; phần còn lại là chuyển động của tay.
    for (var i = 0; i < 3; i++) {
      _gravity[i] += 0.02 * (values[i] - _gravity[i]);
    }
    var axis = 0;
    var best = 0.0;
    for (var i = 0; i < 3; i++) {
      final d = values[i] - _gravity[i];
      if (d.abs() > best.abs()) {
        best = d;
        axis = i;
      }
    }
    while (_peaks.isNotEmpty && at - _peaks.first > window) {
      _peaks.removeFirst();
    }
    if (_peaks.isEmpty) {
      _lastSign = 0;
      _lastAxis = -1;
    }
    if (best.abs() >= peakThreshold &&
        (_lastPeakAt == null || at - _lastPeakAt! >= minGap)) {
      final sign = best > 0 ? 1 : -1;
      if (_lastSign == 0 || (axis == _lastAxis && sign != _lastSign)) {
        _peaks.add(at);
        _lastSign = sign;
        _lastAxis = axis;
        _lastPeakAt = at;
      } else if (axis != _lastAxis) {
        _peaks
          ..clear()
          ..add(at);
        _lastSign = sign;
        _lastAxis = axis;
        _lastPeakAt = at;
      }
    }
    if (_peaks.length >= neededPeaks &&
        (_lastTriggerAt == null || at - _lastTriggerAt! >= cooldown)) {
      _lastTriggerAt = at;
      _peaks.clear();
      _lastSign = 0;
      _lastAxis = -1;
      return true;
    }
    return false;
  }
}
