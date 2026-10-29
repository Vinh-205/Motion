enum Sensitivity { low, medium, high }

// Ngưỡng THỬ NGHIỆM cho bài tập, chưa được xác thực y tế.
class DetectionConfig {
  const DetectionConfig({
    this.abnormalDelta = 4,
    this.impact = 23,
    this.rotationAngle = 0.65,
    this.stillness = const Duration(seconds: 3),
    this.adaptiveCeiling = 1.3,
    this.quietToleranceMs = 100,
  });
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
  static const rotationWindow = Duration(milliseconds: 1500);
  static const sequenceWindow = Duration(seconds: 8);
  static const maxGap = Duration(milliseconds: 400);
  static const cooldown = Duration(seconds: 8);

  static DetectionConfig forSensitivity(Sensitivity value) => switch (value) {
    Sensitivity.low => const DetectionConfig(
      abnormalDelta: 5,
      impact: 27,
      rotationAngle: 0.9,
      adaptiveCeiling: 1.5,
      quietToleranceMs: 0,
    ),
    Sensitivity.medium => const DetectionConfig(),
    Sensitivity.high => const DetectionConfig(
      abnormalDelta: 3,
      impact: 20,
      rotationAngle: 0.45,
      adaptiveCeiling: 1.15,
      quietToleranceMs: 200,
    ),
  };
}
