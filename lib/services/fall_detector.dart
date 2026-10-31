import 'dart:collection';
import 'dart:math';

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

// Experimental algorithm mirrored by NativeFallDetector, which owns real Android SOS.
class FallDetector {
  FallDetector({DetectionConfig? config})
    : config = config ?? const DetectionConfig();
  DetectionConfig config;
  bool rotationAvailable = true;
  FallState state = FallState.normal;
  Duration? _last, _started, _impactAt, _lowSince, _quietSince, _mildSince;
  int _maxLowMs = 0, _quietGoodMs = 0;
  double _rotation = 0, _peak = 0;
  bool _wasQuiet = false;
  String _path = '', triggerReason = '', lastRejection = '';
  final _impacts = Queue<(Duration, double)>();
  final _baseline = Queue<(Duration, double)>();
  final _peaks = Queue<(Duration, double)>();
  double _impactPeak = 0;
  int _bounceCount = 0;
  Duration? _lastBounceAt;
  double impactThreshold = 19;

  void reset({bool clearBaseline = true}) {
    state = FallState.normal;
    _last = _started = _impactAt = _lowSince = null;
    _maxLowMs = 0;
    _rotation = 0;
    _peak = 0;
    _path = '';
    triggerReason = '';
    _impactPeak = 0;
    _bounceCount = 0;
    _lastBounceAt = null;
    _resetQuiet();
    if (clearBaseline) {
      _baseline.clear();
      _impacts.clear();
      _peaks.clear();
    }
  }

  void _resetQuiet() {
    _quietSince = _mildSince = null;
    _quietGoodMs = 0;
    _wasQuiet = false;
  }

  void _reject(String reason, {bool clearBaseline = false}) {
    lastRejection = reason;
    reset(clearBaseline: clearBaseline);
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
      _reject(
        'Thiếu dữ liệu cảm biến mới hoặc dữ liệu không hợp lệ.',
        clearBaseline: true,
      );
      return state;
    }
    final gap = _last == null ? Duration.zero : at - _last!;
    if (gap.isNegative || gap > DetectionConfig.maxGap) {
      _reject('Dữ liệu ngắt quá 400 ms; bỏ chuỗi cũ.', clearBaseline: true);
    }
    if (_started != null && at - _started! > DetectionConfig.sequenceWindow) {
      _reject('Chuỗi quá 8 giây mà chưa đủ điều kiện xác nhận.');
    }
    _last = at;
    while (_baseline.isNotEmpty &&
        at - _baseline.first.$1 > const Duration(seconds: 2)) {
      _baseline.removeFirst();
    }
    // Các đỉnh mạnh trong 2 giây trước: lắc/nhảy tạo nhiều đỉnh đều nhau, cú ngã thì nổi bật hẳn.
    while (_peaks.isNotEmpty &&
        at - _peaks.first.$1 > const Duration(seconds: 2)) {
      _peaks.removeFirst();
    }
    final priorPeakCount = _peaks.length;
    final priorPeakMax = _peaks.isEmpty
        ? 0.0
        : _peaks.map((e) => e.$2).reduce(max);
    if (magnitude >= config.impact &&
        (_peaks.isEmpty ||
            at - _peaks.last.$1 >= const Duration(milliseconds: 150))) {
      _peaks.add((at, magnitude));
    }
    // Sau va chạm, điện thoại thường nảy/lăn vài lần với lực yếu dần: không được huỷ cú ngã.
    // Chỉ coi là hoạt động lặp (lắc, nhảy, đi) khi va chạm mạnh gần bằng lần đầu, quá nhiều lần
    // hoặc còn tiếp diễn sau cửa sổ nảy.
    if (state.index >= 2 &&
        _impactAt != null &&
        magnitude >= config.impact &&
        at - _impactAt! > const Duration(milliseconds: 150)) {
      if (_lastBounceAt == null ||
          at - _lastBounceAt! >= const Duration(milliseconds: 100)) {
        _bounceCount++;
        _lastBounceAt = at;
      }
      if (at - _impactAt! > DetectionConfig.bounceWindow ||
          magnitude >= _impactPeak * 0.85 ||
          _bounceCount > 3) {
        _reject(
          'Có va chạm tiếp tục lặp lại sau va chạm đầu; chưa coi là ngã rồi nằm yên.',
        );
        _last = at;
      }
    }
    if (state == FallState.normal) {
      impactThreshold = config.impact;
      if (_baseline.length >= 20 &&
          at - _baseline.first.$1 >= const Duration(milliseconds: 500)) {
        final mean =
            _baseline.fold<double>(0, (s, e) => s + e.$2) / _baseline.length;
        final variance =
            _baseline.fold<double>(0, (s, e) => s + pow(e.$2 - mean, 2)) /
            _baseline.length;
        impactThreshold = max(
          config.impact,
          mean + 3 * sqrt(variance),
        ).clamp(config.impact, config.impact * config.adaptiveCeiling);
      }
    }
    _baseline.add((at, magnitude));
    if (_baseline.length > 1000) _baseline.removeFirst();
    if (magnitude < DetectionConfig.lowGravity) {
      _lowSince ??= at;
      _maxLowMs = max(_maxLowMs, (at - _lowSince!).inMilliseconds);
    } else {
      if (_lowSince != null) {
        _maxLowMs = max(_maxLowMs, (at - _lowSince!).inMilliseconds);
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
        _peak = magnitude;
      }
      // Evaluate the first impact sample as well as subsequent samples.
      if (state == FallState.normal || magnitude < impactThreshold) {
        return state;
      }
    }
    _peak = max(_peak, magnitude);
    if (rotationAvailable) {
      _rotation += rotation * (gap.inMicroseconds / 1000000).clamp(0, 0.2);
    }
    switch (state) {
      case FallState.possibleFall:
        if (at - _started! > DetectionConfig.impactWindow) {
          _reject(
            'Chưa có va chạm đạt ngưỡng: đỉnh ${_peak.toStringAsFixed(2)} / ${impactThreshold.toStringAsFixed(2)} m/s².',
          );
        } else if (magnitude >= impactThreshold) {
          while (_impacts.isNotEmpty &&
              at - _impacts.first.$1 > const Duration(seconds: 2)) {
            _impacts.removeFirst();
          }
          final repeated =
              _impacts.length >= 2 &&
              magnitude <= _impacts.map((e) => e.$2).reduce(max) * 1.2;
          if (_impacts.isEmpty ||
              at - _impacts.last.$1 >= const Duration(milliseconds: 200)) {
            _impacts.add((at, magnitude));
          }
          final rhythmic =
              priorPeakCount >= 2 && magnitude <= priorPeakMax * 1.3;
          if (repeated || rhythmic) {
            _reject('Va chạm lặp lại; chờ sự kiện mới mạnh hơn.');
            return state;
          }
          final lowEnough = _maxLowMs >= (rotationAvailable ? 40 : 80);
          if (!lowEnough &&
              !(rotationAvailable &&
                  (magnitude >= impactThreshold + 6 ||
                      (magnitude >= impactThreshold + config.impactMargin &&
                          rotation >= 2.5)))) {
            _reject('Va chạm thiếu pha giảm gia tốc đủ lâu hoặc chưa đủ mạnh.');
          } else {
            _impactAt = at;
            _impactPeak = magnitude;
            final ballistic =
                _maxLowMs >= 120 && magnitude >= impactThreshold + 6;
            state = !rotationAvailable || ballistic
                ? FallState.waitingForStillness
                : FallState.impactDetected;
            _path = ballistic
                ? 'giảm gia tốc ít nhất 120 ms + va chạm mạnh (không bắt buộc xoay)'
                : !rotationAvailable
                ? 'gia tốc, không có con quay'
                : 'gia tốc + va chạm + xoay';
          }
        }
      case FallState.impactDetected:
        if (at - _impactAt! > DetectionConfig.rotationWindow) {
          _reject(
            'Thiếu bằng chứng xoay: ${_rotation.toStringAsFixed(2)} / ${config.rotationAngle.toStringAsFixed(2)} rad.',
          );
        } else if (_rotation >= config.rotationAngle) {
          state = FallState.waitingForStillness;
        }
      case FallState.waitingForStillness:
        final deviation = (magnitude - DetectionConfig.gravity).abs();
        final motion = rotationAvailable ? rotation : accelerationDelta;
        final quiet =
            deviation < config.quietDeviation &&
            motion <
                (rotationAvailable
                    ? config.quietAngularSpeed
                    : config.quietDeviation);
        final severe =
            deviation >= 3 || motion >= (rotationAvailable ? 1.0 : 3.0);
        if (quiet) {
          if (_quietSince == null) {
            _quietSince = at;
          } else if (_wasQuiet) {
            _quietGoodMs += gap.inMilliseconds.clamp(0, 400);
          }
          _mildSince = null;
        } else if (severe || config.quietToleranceMs == 0) {
          _resetQuiet();
          lastRejection = 'Đã thấy va chạm nhưng vẫn còn chuyển động rõ; chờ ít chuyển động.';
        } else {
          _mildSince ??= at;
          if ((at - _mildSince!).inMilliseconds > config.quietToleranceMs) {
            _resetQuiet();
            lastRejection = 'Chuyển động nhỏ kéo dài, chưa đủ phần yên.';
          }
        }
        _wasQuiet = quiet;
        final elapsed = _quietSince == null
            ? 0
            : (at - _quietSince!).inMilliseconds;
        if (quiet &&
            elapsed >= config.stillness.inMilliseconds &&
            _quietGoodMs >= elapsed * 0.85) {
          state = FallState.fallSuspected;
          triggerReason =
              'Nghi ngờ theo nhánh $_path. Đỉnh ${_peak.toStringAsFixed(2)} m/s²; ngưỡng ${impactThreshold.toStringAsFixed(2)} m/s²; giảm gia tốc $_maxLowMs ms; xoay tích lũy ${_rotation.toStringAsFixed(2)} rad; phần yên $_quietGoodMs / $elapsed ms.';
          lastRejection = '';
        }
      case FallState.normal:
      case FallState.fallSuspected:
        break;
    }
    return state;
  }
}
