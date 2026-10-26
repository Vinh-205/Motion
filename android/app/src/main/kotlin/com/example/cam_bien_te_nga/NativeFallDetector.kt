package com.example.cam_bien_te_nga

import kotlin.math.abs

/** Same experimental sequence and thresholds as lib/services/fall_detector.dart. */
class NativeFallDetector {
    var sensitivity = "medium"
    var state = 0
        private set
    private var last: Long? = null
    private var started: Long? = null
    private var impactAt: Long? = null
    private var quietSince: Long? = null
    private var rotationSum = 0.0

    fun reset() { state = 0; last = null; started = null; impactAt = null; quietSince = null; rotationSum = 0.0 }

    fun update(at: Long, magnitude: Double, rotation: Double, gyroFresh: Boolean): Boolean {
        if (state == 4) return true
        if (!magnitude.isFinite() || !rotation.isFinite() || !gyroFresh) { reset(); return false }
        val gap = if (last == null) 0L else at - last!!
        if (gap < 0 || gap > 400) reset()
        if (started != null && at - started!! > 8000) reset()
        last = at
        val abnormal = when (sensitivity) { "low" -> 5.0; "high" -> 3.0; else -> 4.0 }
        val impact = when (sensitivity) { "low" -> 27.0; "high" -> 20.0; else -> 23.0 }
        val angle = when (sensitivity) { "low" -> 0.9; "high" -> 0.45; else -> 0.65 }
        if (state == 0) {
            if (magnitude < 5 || abs(magnitude - 9.81) > abnormal || rotation > 1.5) { state = 1; started = at }
            return false
        }
        rotationSum += rotation * (gap / 1000.0).coerceIn(0.0, 0.2)
        when (state) {
            1 -> if (at - started!! > 1500) reset() else if (magnitude >= impact) { impactAt = at; state = 2 }
            2 -> if (at - impactAt!! > 1500) reset() else if (rotationSum >= angle) state = 3
            3 -> {
                if (abs(magnitude - 9.81) >= 1.3 || rotation >= 0.35) quietSince = null
                else {
                    if (quietSince == null) quietSince = at
                    if (at - quietSince!! >= 3000) state = 4
                }
            }
        }
        return state == 4
    }
}
