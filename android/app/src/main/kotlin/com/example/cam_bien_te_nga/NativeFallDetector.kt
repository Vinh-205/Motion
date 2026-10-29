package com.example.cam_bien_te_nga

import java.util.ArrayDeque
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt

/** Experimental, mirrored in lib/services/fall_detector.dart. Not a medical classifier. */
class NativeFallDetector {
    var sensitivity = "medium"
    var rotationAvailable = true
    var state = 0
        private set
    var impactThreshold = 23.0
        private set
    var lastRejection = ""
        private set
    var triggerReason = ""
        private set
    private var last: Long? = null
    private var started: Long? = null
    private var impactAt: Long? = null
    private var lowSince: Long? = null
    private var maxLowMs = 0L
    private var rotationSum = 0.0
    private var peakAcceleration = 0.0
    private var quietSince: Long? = null
    private var quietGoodMs = 0L
    private var mildSince: Long? = null
    private var wasQuiet = false
    private var path = ""
    private val baseline = ArrayDeque<Pair<Long, Double>>()

    private fun number(value: Double) = String.format(Locale.US, "%.2f", value)
    val diagnostic: String get() =
        "${when (state) { 0 -> "Chờ chuỗi mới"; 1 -> "Chờ va chạm"; 2 -> "Chờ bằng chứng xoay"; 3 -> "Kiểm tra ít chuyển động"; else -> "Đã tạo cảnh báo" }}. " +
        "Đỉnh ${number(peakAcceleration)} m/s²; ngưỡng ${number(impactThreshold)} m/s²; " +
        "xoay tích lũy ${number(rotationSum)} rad; giảm gia tốc ${maxLowMs} ms; phần yên ${quietGoodMs} ms."

    fun reset(clearBaseline: Boolean = true) {
        state = 0; last = null; started = null; impactAt = null; lowSince = null
        maxLowMs = 0; rotationSum = 0.0; peakAcceleration = 0.0; path = ""; triggerReason = ""
        resetQuiet()
        if (clearBaseline) baseline.clear()
    }
    private fun resetQuiet() { quietSince = null; quietGoodMs = 0; mildSince = null; wasQuiet = false }
    private fun reject(reason: String, clearBaseline: Boolean = false) {
        lastRejection = reason
        reset(clearBaseline)
    }

    fun update(at: Long, magnitude: Double, rotation: Double, gyroFresh: Boolean, accelerationDelta: Double = 0.0): Boolean {
        if (state == 4) return true
        if (!magnitude.isFinite() || !accelerationDelta.isFinite() || (rotationAvailable && (!rotation.isFinite() || !gyroFresh))) {
            reject("Thiếu dữ liệu cảm biến mới hoặc dữ liệu không hợp lệ.", true); return false
        }
        val gap = if (last == null) 0L else at - last!!
        if (gap < 0 || gap > 400) reject("Dữ liệu ngắt quá 400 ms; bỏ chuỗi cũ.", true)
        if (started != null && at - started!! > 8000) reject("Chuỗi quá 8 giây mà chưa đủ điều kiện xác nhận.")
        last = at
        val impact = when (sensitivity) { "low" -> 27.0; "high" -> 20.0; else -> 23.0 }
        val abnormal = when (sensitivity) { "low" -> 5.0; "high" -> 3.0; else -> 4.0 }
        val angle = when (sensitivity) { "low" -> 0.9; "high" -> 0.45; else -> 0.65 }
        val ceiling = when (sensitivity) { "low" -> 1.5; "high" -> 1.15; else -> 1.3 }
        while (baseline.isNotEmpty() && at - baseline.first.first > 2000) baseline.removeFirst()
        // Learn only before a candidate, then freeze its threshold. Shaking cannot
        // continuously raise the bar for the very fall currently being evaluated.
        if (state >= 2 && impactAt != null && at - impactAt!! > 300 && magnitude >= impact) {
            reject("Có va chạm tiếp tục lặp lại sau va chạm đầu; chưa coi là ngã rồi nằm yên.")
            last = at
        }
        if (state == 0) {
            impactThreshold = impact
            if (baseline.size >= 20 && at - baseline.first.first >= 500) {
                val mean = baseline.sumOf { it.second } / baseline.size
                val variance = baseline.sumOf { (it.second - mean) * (it.second - mean) } / baseline.size
                impactThreshold = max(impact, mean + 3 * sqrt(variance)).coerceAtMost(impact * ceiling)
            }
        }
        baseline.addLast(at to magnitude)
        if (baseline.size > 1000) baseline.removeFirst()
        if (magnitude < 5.0) {
            if (lowSince == null) lowSince = at
            maxLowMs = max(maxLowMs, at - lowSince!!)
        } else {
            if (lowSince != null) maxLowMs = max(maxLowMs, at - lowSince!!)
            lowSince = null
        }
        if (state == 0) {
            if (magnitude < 5 || (rotationAvailable && (abs(magnitude - 9.81) > abnormal || rotation > 1.5))) {
                state = 1; started = at; peakAcceleration = magnitude
            }
            return false
        }
        peakAcceleration = max(peakAcceleration, magnitude)
        if (rotationAvailable) rotationSum += rotation * (gap / 1000.0).coerceIn(0.0, 0.2)
        when (state) {
            1 -> {
                if (at - started!! > 1500) reject("Chưa có va chạm đạt ngưỡng: đỉnh ${number(peakAcceleration)} / ${number(impactThreshold)} m/s².")
                else if (magnitude >= impactThreshold) {
                    val lowEnough = maxLowMs >= if (rotationAvailable) 40 else 80
                    if (!lowEnough && !(rotationAvailable && magnitude >= impactThreshold + 6)) {
                        reject("Va chạm thiếu pha giảm gia tốc đủ lâu hoặc chưa đủ mạnh.")
                    } else {
                        impactAt = at
                        val ballistic = maxLowMs >= 120 && magnitude >= impactThreshold + 6
                        state = if (!rotationAvailable || ballistic) 3 else 2
                        path = if (ballistic) "giảm gia tốc ít nhất 120 ms + va chạm mạnh (không bắt buộc xoay)" else if (!rotationAvailable) "gia tốc, không có con quay" else "gia tốc + va chạm + xoay"
                    }
                }
            }
            2 -> {
                if (at - impactAt!! > 1500) reject("Thiếu bằng chứng xoay: ${number(rotationSum)} / ${number(angle)} rad.")
                else if (rotationSum >= angle) state = 3
            }
            3 -> {
                val deviation = abs(magnitude - 9.81)
                val motion = if (rotationAvailable) rotation else accelerationDelta
                val quiet = deviation < 1.3 && motion < if (rotationAvailable) 0.35 else 1.3
                val severe = deviation >= 3 || motion >= if (rotationAvailable) 1.0 else 3.0
                val tolerance = when (sensitivity) { "low" -> 0L; "high" -> 200L; else -> 100L }
                if (quiet) {
                    if (quietSince == null) quietSince = at
                    else if (wasQuiet) quietGoodMs += gap.coerceIn(0, 400)
                    mildSince = null
                } else if (severe || tolerance == 0L) {
                    resetQuiet()
                    lastRejection = "Đã thấy va chạm nhưng vẫn còn chuyển động rõ; chờ ít chuyển động."
                } else {
                    if (mildSince == null) mildSince = at
                    if (at - mildSince!! > tolerance) { resetQuiet(); lastRejection = "Chuyển động nhỏ kéo dài, chưa đủ phần yên." }
                }
                wasQuiet = quiet
                val elapsed = quietSince?.let { at - it } ?: 0
                if (quiet && elapsed >= 3000 && quietGoodMs >= elapsed * 0.85) {
                    state = 4
                    triggerReason = "Nghi ngờ theo nhánh $path. Đỉnh ${number(peakAcceleration)} m/s²; ngưỡng ${number(impactThreshold)} m/s²; " +
                        "giảm gia tốc ${maxLowMs} ms; xoay tích lũy ${number(rotationSum)} rad; phần yên ${quietGoodMs} / ${elapsed} ms."
                    lastRejection = ""
                }
            }
        }
        return state == 4
    }
}
