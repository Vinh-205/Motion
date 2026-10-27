package com.example.cam_bien_te_nga

import kotlin.math.abs
import kotlin.math.sqrt
import kotlin.math.max

/** Same experimental sequence and thresholds as lib/services/fall_detector.dart. */
class NativeFallDetector {
    var sensitivity = "medium"
    var rotationAvailable = true
    var state = 0
        private set
    private var last: Long? = null
    private var started: Long? = null
    private var impactAt: Long? = null
    private var quietSince: Long? = null
    private var rotationSum = 0.0
    private var lowSince: Long? = null
    private var sustainedLow = false
    private val baseline = java.util.ArrayDeque<Pair<Long, Double>>()
    var impactThreshold = 23.0
        private set

    fun reset(clearBaseline: Boolean = true) { state = 0; last = null; started = null; impactAt = null; quietSince = null; rotationSum = 0.0; lowSince = null; sustainedLow = false; if (clearBaseline) baseline.clear() }

    fun update(at: Long, magnitude: Double, rotation: Double, gyroFresh: Boolean, accelerationDelta: Double = 0.0): Boolean {
        if (state == 4) return true
        if (!magnitude.isFinite() || !accelerationDelta.isFinite() || (rotationAvailable && (!rotation.isFinite() || !gyroFresh))) { reset(); return false }
        val gap = if (last == null) 0L else at - last!!
        if (gap < 0 || gap > 400) reset()
        if (started != null && at - started!! > 8000) reset()
        last = at
        // No gyro: require sustained low gravity BEFORE impact, not ordinary walking/jolts.
        if (magnitude < 5.0) {
            if (lowSince == null) lowSince = at
            if (at - lowSince!! >= (if (rotationAvailable) 40 else 80)) sustainedLow = true
        } else {
            if (lowSince != null && at - lowSince!! >= (if (rotationAvailable) 40 else 80)) sustainedLow = true
            lowSince = null
        }
        val abnormal = when (sensitivity) { "low" -> 5.0; "high" -> 3.0; else -> 4.0 }
        val impact = when (sensitivity) { "low" -> 27.0; "high" -> 20.0; else -> 23.0 }
        val angle = when (sensitivity) { "low" -> 0.9; "high" -> 0.45; else -> 0.65 }
        while (baseline.isNotEmpty() && at - baseline.first.first > 2000) baseline.removeFirst()
        impactThreshold = impact
        if (baseline.size >= 20 && at - baseline.first.first >= 500) {
            val mean = baseline.sumOf { it.second } / baseline.size
            val variance = baseline.sumOf { (it.second - mean) * (it.second - mean) } / baseline.size
            impactThreshold = max(impact, mean + 3.0 * sqrt(variance))
        }
        // Use preceding data (not the current impact) to estimate ordinary gait.
        // Limit history by both time and count; never adapt the quiet confirmation threshold.
        baseline.addLast(at to magnitude); if (baseline.size > 1000) baseline.removeFirst()
        // Repeated impacts after the initial settling interval are ongoing activity,
        // not a completed fall followed by rest. Keep the gait baseline on rejection.
        if (state >= 2 && impactAt != null && at - impactAt!! > 300 && magnitude >= impact) {
            reset(false); last = at
        }
        if (state == 0) {
            if (magnitude < 5 || (rotationAvailable && (abs(magnitude - 9.81) > abnormal || rotation > 1.5))) { state = 1; started = at }
            return false
        }
        if (rotationAvailable) rotationSum += rotation * (gap / 1000.0).coerceIn(0.0, 0.2)
        when (state) {
            1 -> if (at - started!! > 1500) reset(false) else if (magnitude >= impactThreshold) {
                // Repeated gait oscillations without a low-gravity phase require a much
                // stronger impact AND subsequent gyro rotation evidence, not a single step.
                if (sustainedLow || (rotationAvailable && magnitude >= impactThreshold + 6.0)) { impactAt = at; state = if (rotationAvailable) 2 else 3 }
                else reset(false)
            }
            2 -> if (at - impactAt!! > 1500) reset(false) else if (rotationSum >= angle) state = 3
            3 -> {
                if (abs(magnitude - 9.81) >= 1.3 || (if (rotationAvailable) rotation >= 0.35 else accelerationDelta >= 1.3)) quietSince = null
                else {
                    if (quietSince == null) quietSince = at
                    if (at - quietSince!! >= 3000) state = 4
                }
            }
        }
        return state == 4
    }
}
