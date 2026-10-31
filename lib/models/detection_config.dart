enum Sensitivity { low, medium, high }

// Ngưỡng THỬ NGHIỆM cho bài tập, chưa được xác thực y tế.
class DetectionConfig {
  const DetectionConfig({
    this.abnormalDelta = 3.5,
    this.impact = 19,
    this.rotationAngle = 0.5,
    this.stillness = const Duration(milliseconds: 1000),
    this.adaptiveCeiling = 1.3,
    this.quietToleranceMs = 100,
    this.impactMargin = 4,
    this.quietDeviation = 1.5,
    this.quietAngularSpeed = 0.45,
  });
  final double impactMargin, quietDeviation, quietAngularSpeed;
  final double abnormalDelta;
  final double impact;
  // Tích phân độ lớn vận tốc góc: bằng chứng xoay, không phải góc tư thế tuyệt đối.
  final double rotationAngle;
  final Duration stillness;
  final double adaptiveCeiling;
  final int quietToleranceMs;
  static const gravity = 9.81;
  static const lowGravity = 5.0;
  static const rotationTrigger = 1.5;
  static const quietAcceleration = 1.3;
  static const quietRotation = 0.35;
  static const impactWindow = Duration(milliseconds: 1500);
  static const rotationWindow = Duration(milliseconds: 800);
  // Cửa sổ sau va chạm đầu: các lần nảy/lăn yếu dần vẫn thuộc cùng một cú ngã.
  static const bounceWindow = Duration(milliseconds: 1500);
  static const sequenceWindow = Duration(seconds: 8);
  static const maxGap = Duration(milliseconds: 400);
  static const cooldown = Duration(seconds: 8);

  static DetectionConfig forSensitivity(Sensitivity value) => switch (value) {
    Sensitivity.low => const DetectionConfig(
      abnormalDelta: 4,
      impact: 24,
      impactMargin: 6,
      quietDeviation: 1.3,
      quietAngularSpeed: 0.35,
      rotationAngle: 0.7,
      stillness: Duration(milliseconds: 1500),
      adaptiveCeiling: 1.5,
      quietToleranceMs: 0,
    ),
    Sensitivity.medium => const DetectionConfig(),
    Sensitivity.high => const DetectionConfig(
      abnormalDelta: 2.5,
      impact: 15,
      impactMargin: 2,
      quietDeviation: 1.9,
      quietAngularSpeed: 0.6,
      rotationAngle: 0.35,
      stillness: Duration(milliseconds: 600),
      adaptiveCeiling: 1.15,
      quietToleranceMs: 200,
    ),
  };
}
