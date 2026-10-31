package com.example.cam_bien_te_nga

import kotlin.math.abs

/**
 * Lắc mạnh qua lại để gọi SOS.
 * Đếm các đỉnh gia tốc động (đã trừ trọng lực) đổi chiều liên tiếp trên cùng một trục.
 * Chạy bộ, nhảy hay té ngã chỉ tạo đỉnh mạnh một chiều nên không kích hoạt.
 */
class ShakeDetector(
    private val peakThreshold: Double = 18.0,
    private val neededPeaks: Int = 6,
    private val windowMs: Long = 2000,
    private val minGapMs: Long = 80,
    private val cooldownMs: Long = 10000,
) {
    private val gravity = DoubleArray(3)
    private var gravityReady = false
    private val peaks = ArrayDeque<Long>()
    private var lastAxis = -1
    private var lastSign = 0
    private var lastPeakAt = Long.MIN_VALUE / 2
    private var lastTriggerAt = Long.MIN_VALUE / 2
    private var last: Long? = null

    fun reset() {
        gravityReady = false; peaks.clear(); lastAxis = -1; lastSign = 0; last = null
    }

    fun update(at: Long, x: Double, y: Double, z: Double): Boolean {
        val values = doubleArrayOf(x, y, z)
        if (values.any { !it.isFinite() }) { reset(); return false }
        val gap = last?.let { at - it } ?: 0L
        last = at
        if (!gravityReady || gap < 0 || gap > 400) {
            values.copyInto(gravity); gravityReady = true; peaks.clear(); lastSign = 0; lastAxis = -1
            return false
        }
        // Lọc thông thấp ~0,5 s để ước lượng trọng lực, phần còn lại là chuyển động của tay.
        for (i in 0..2) gravity[i] += 0.02 * (values[i] - gravity[i])
        var axis = 0
        var best = 0.0
        for (i in 0..2) {
            val d = values[i] - gravity[i]
            if (abs(d) > abs(best)) { best = d; axis = i }
        }
        while (peaks.isNotEmpty() && at - peaks.first() > windowMs) peaks.removeFirst()
        if (peaks.isEmpty()) { lastSign = 0; lastAxis = -1 }
        if (abs(best) >= peakThreshold && at - lastPeakAt >= minGapMs) {
            val sign = if (best > 0) 1 else -1
            if (lastSign == 0 || (axis == lastAxis && sign != lastSign)) {
                peaks.addLast(at); lastSign = sign; lastAxis = axis; lastPeakAt = at
            } else if (axis != lastAxis) {
                peaks.clear(); peaks.addLast(at); lastSign = sign; lastAxis = axis; lastPeakAt = at
            }
        }
        if (peaks.size >= neededPeaks && at - lastTriggerAt >= cooldownMs) {
            lastTriggerAt = at; peaks.clear(); lastSign = 0; lastAxis = -1
            return true
        }
        return false
    }
}
