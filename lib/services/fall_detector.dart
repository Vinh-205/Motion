import '../models/detection_config.dart';

import 'dart:collection';
import 'dart:math';

enum FallState {
  normal,
  possibleFall,
  impactDetected,
  waitingForStillness,
  fallSuspected,
}

extension FallStateLabel on FallState {
  String get label => switch (this) {
    FallState.normal => 'Chưa có chuỗi nghi ngờ',
    FallState.possibleFall => 'Đang kiểm tra chuyển động',
    FallState.impactDetected => 'Đã ghi nhận va chạm • kiểm tra xoay',
    FallState.waitingForStillness => 'Đang kiểm tra ít chuyển động',
    FallState.fallSuspected => 'Nghi ngờ té ngã',
  };
}

// Chạy độc lập với Flutter để kiểm thử chuỗi dữ liệu có kiểm soát.
class FallDetector {
  FallDetector({DetectionConfig? config})
    : config = config ?? const DetectionConfig();
  DetectionConfig config;
  bool rotationAvailable = true;
  FallState state = FallState.normal;
  Duration? _last, _started, _impactAt, _quietSince;
  double _rotation = 0;
  Duration? _lowSince;
  bool _sustainedLow = false;
  final _baseline = Queue<(Duration, double)>();
  double impactThreshold = 23;

  void reset({bool clearBaseline = true}) {
    state = FallState.normal;
    _last = _started = _impactAt = _quietSince = null;
    _rotation = 0;
    _lowSince = null;
    _sustainedLow = false;
    if (clearBaseline) _baseline.clear();
  }

  void simulate() {
    reset();
    state = FallState.fallSuspected;
  }

  FallState update({
    required Duration at,
    required double magnitude,
    required double rotation,
    required bool gyroFresh,
    double accelerationDelta = 0,
  }) {
    if (state == FallState.fallSuspected) return state;
    if (!magnitude.isFinite ||
        !accelerationDelta.isFinite ||
        (rotationAvailable && (!rotation.isFinite || !gyroFresh))) {
      reset();
      return state;
    }
    final gap = _last == null ? Duration.zero : at - _last!;
    if (gap.isNegative || gap > DetectionConfig.maxGap) reset();
    _last = at;
    if (_started != null && at - _started! > DetectionConfig.sequenceWindow) {
      reset();
    }
    _last = at;
    while (_baseline.isNotEmpty &&
        at - _baseline.first.$1 > const Duration(seconds: 2)) {
      _baseline.removeFirst();
    }
    impactThreshold = config.impact;
    if (_baseline.length >= 20 &&
        at - _baseline.first.$1 >= const Duration(milliseconds: 500)) {
      final mean =
          _baseline.fold<double>(0, (s, e) => s + e.$2) / _baseline.length;
      final variance =
          _baseline.fold<double>(0, (s, e) => s + pow(e.$2 - mean, 2)) /
          _baseline.length;
      impactThreshold = max(config.impact, mean + 3 * sqrt(variance));
    }
    _baseline.add((at, magnitude));
    if (_baseline.length > 1000) _baseline.removeFirst();
    if (state.index >= 2 &&
        _impactAt != null &&
        at - _impactAt! > const Duration(milliseconds: 300) &&
        magnitude >= config.impact) {
      reset(clearBaseline: false);
      _last = at;
    }
    final lowDuration = Duration(milliseconds: rotationAvailable ? 40 : 80);
    if (magnitude < DetectionConfig.lowGravity) {
      _lowSince ??= at;
      if (at - _lowSince! >= lowDuration) _sustainedLow = true;
    } else {
      if (_lowSince != null && at - _lowSince! >= lowDuration) {
        _sustainedLow = true;
      }
      _lowSince = null;
    }
    if (state == FallState.normal) {
      if (magnitude < DetectionConfig.lowGravity ||
          (rotationAvailable &&
              ((magnitude - DetectionConfig.gravity).abs() >
                      config.abnormalDelta ||
                  rotation > DetectionConfig.rotationTrigger))) {
        state = FallState.possibleFall;
        _started = at;
      }
      // Một đỉnh đơn lẻ không đủ: cần mẫu va chạm SAU mẫu bất thường.
      return state;
    }
    if (rotationAvailable) {
      _rotation += rotation * (gap.inMicroseconds / 1000000).clamp(0, 0.2);
    }
    switch (state) {
      case FallState.possibleFall:
        if (at - _started! > DetectionConfig.impactWindow) {
          reset(clearBaseline: false);
        } else if (magnitude >= impactThreshold) {
          if (_sustainedLow ||
              (rotationAvailable && magnitude >= impactThreshold + 6)) {
            _impactAt = at;
            state = rotationAvailable
                ? FallState.impactDetected
                : FallState.waitingForStillness;
          } else {
            reset(clearBaseline: false);
          }
        }
      case FallState.impactDetected:
        if (at - _impactAt! > DetectionConfig.rotationWindow) {
          reset(clearBaseline: false);
        } else if (_rotation >= config.rotationAngle) {
          state = FallState.waitingForStillness;
        }
      case FallState.waitingForStillness:
        final quiet =
            (magnitude - DetectionConfig.gravity).abs() <
                DetectionConfig.quietAcceleration &&
            (rotationAvailable
                ? rotation < DetectionConfig.quietRotation
                : accelerationDelta < DetectionConfig.quietAcceleration);
        if (!quiet) {
          _quietSince = null;
        } else {
          _quietSince ??= at;
          if (at - _quietSince! >= config.stillness) {
            state = FallState.fallSuspected;
          }
        }
      case FallState.normal:
      case FallState.fallSuspected:
        break;
    }
    return state;
  }
}
