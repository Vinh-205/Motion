import '../models/detection_config.dart';

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
  FallState state = FallState.normal;
  Duration? _last, _started, _impactAt, _quietSince;
  double _rotation = 0;

  void reset() {
    state = FallState.normal;
    _last = _started = _impactAt = _quietSince = null;
    _rotation = 0;
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
  }) {
    if (state == FallState.fallSuspected) return state;
    if (!magnitude.isFinite || !rotation.isFinite || !gyroFresh) {
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
    if (state == FallState.normal) {
      if (magnitude < DetectionConfig.lowGravity ||
          (magnitude - DetectionConfig.gravity).abs() > config.abnormalDelta ||
          rotation > DetectionConfig.rotationTrigger) {
        state = FallState.possibleFall;
        _started = at;
      }
      // Một đỉnh đơn lẻ không đủ: cần mẫu va chạm SAU mẫu bất thường.
      return state;
    }
    _rotation += rotation * (gap.inMicroseconds / 1000000).clamp(0, 0.2);
    switch (state) {
      case FallState.possibleFall:
        if (at - _started! > DetectionConfig.impactWindow) {
          reset();
        } else if (magnitude >= config.impact) {
          _impactAt = at;
          state = FallState.impactDetected;
        }
      case FallState.impactDetected:
        if (at - _impactAt! > DetectionConfig.rotationWindow) {
          reset();
        } else if (_rotation >= config.rotationAngle) {
          state = FallState.waitingForStillness;
        }
      case FallState.waitingForStillness:
        final quiet =
            (magnitude - DetectionConfig.gravity).abs() <
                DetectionConfig.quietAcceleration &&
            rotation < DetectionConfig.quietRotation;
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
