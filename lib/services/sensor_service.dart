import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class Vector3 {
  const Vector3(this.x, this.y, this.z);
  final double x, y, z;
  double get magnitude => sqrt(x * x + y * y + z * z);
}

class SensorService extends ChangeNotifier {
  StreamSubscription<AccelerometerEvent>? _acc;
  StreamSubscription<GyroscopeEvent>? _gyro;
  Vector3? acceleration, rotation;
  DateTime? accelerationAt, rotationAt;
  String? error;
  int accelerationSequence = 0;
  int _generation = 0;
  bool running = false;
  bool hasGyroscope = true;
  String? rotationWarning;

  bool fresh(DateTime now) =>
      error == null &&
      running &&
      accelerationAt != null &&
      now.difference(accelerationAt!).inMilliseconds < 2000 &&
      (!hasGyroscope ||
          (rotationAt != null &&
              now.difference(rotationAt!).inMilliseconds < 2000));

  void start() {
    if (running) return;
    running = true;
    error = null;
    acceleration = rotation = null;
    accelerationAt = rotationAt = null;
    final generation = ++_generation;
    void failed(Object e) {
      if (!running || generation != _generation) return;
      error = 'Không đọc được cảm biến. Hãy kiểm tra thiết bị và thử bật lại giám sát.';
      notifyListeners();
    }

    try {
      _acc =
          accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 10),
          ).listen((e) {
            if (!running || generation != _generation) return;
            acceleration = Vector3(e.x, e.y, e.z);
            accelerationAt = DateTime.now();
            accelerationSequence++;
            notifyListeners();
          }, onError: failed);
      if (hasGyroscope) {
        _gyro =
            gyroscopeEventStream(
              samplingPeriod: const Duration(milliseconds: 10),
            ).listen(
              (e) {
                if (!running || generation != _generation) return;
                rotation = Vector3(e.x, e.y, e.z);
                rotationAt = DateTime.now();
                notifyListeners();
              },
              onError: (Object e) {
                if (!running || generation != _generation) return;
                hasGyroscope = false;
                rotation = null;
                rotationAt = null;
                rotationWarning =
                    'Không có dữ liệu con quay. Không hiển thị số xoay giả.';
                notifyListeners();
              },
            );
      }
    } catch (e) {
      failed(e);
    }
  }

  void stop() {
    running = false;
    _generation++;
    unawaited(_acc?.cancel());
    unawaited(_gyro?.cancel());
    _acc = null;
    _gyro = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
