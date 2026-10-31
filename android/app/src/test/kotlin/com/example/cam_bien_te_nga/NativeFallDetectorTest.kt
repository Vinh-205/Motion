package com.example.cam_bien_te_nga

import org.junit.Assert.*
import org.junit.Test

class NativeFallDetectorTest {
    @Test fun completeSequenceTriggersForEverySensitivity() {
        for (sensitivity in listOf("low", "medium", "high")) {
            val d = NativeFallDetector().apply { this.sensitivity = sensitivity }
            d.update(0, 9.81, 0.0, true)
            d.update(50, 2.0, 0.0, true)
            d.update(100, 30.0, 3.0, true)
            d.update(150, 9.81, 20.0, true)
            // Thời gian yên sau va chạm đã rút ngắn: low 1,5 s / medium 1 s / high 0,6 s.
            val stillness = when (sensitivity) { "low" -> 1500L; "high" -> 600L; else -> 1000L }
            for (at in 200L until 200L + stillness step 50) assertFalse(d.update(at, 9.81, 0.0, true))
            assertTrue(d.update(200L + stillness, 9.81, 0.0, true))
            assertEquals(4, d.state)
        }
    }
    @Test fun onePeakNeverMeansFall() {
        val d = NativeFallDetector()
        assertFalse(d.update(0, 40.0, 0.0, true))
        for (at in 50L..5000L step 50) assertFalse(d.update(at, 9.81, 0.0, true))
        assertEquals(0, d.state)
    }
    @Test fun missingGyroAndSensorGapsDiscardSequence() {
        val d = NativeFallDetector()
        d.update(0, 2.0, 0.0, true)
        d.update(50, 30.0, 3.0, false)
        assertEquals(0, d.state)
        d.update(100, 2.0, 0.0, true)
        d.update(1000, 9.81, 0.0, true)
        assertEquals(0, d.state)
    }
    @Test fun rotationEvidenceIsRequired() {
        val d = NativeFallDetector()
        d.update(0, 2.0, 0.0, true)
        d.update(50, 30.0, 0.0, true)
        for (at in 100L..7000L step 50) assertFalse(d.update(at, 9.81, 0.0, true))
    }
    @Test fun movementInterruptsStillness() {
        val d = NativeFallDetector()
        d.update(0, 2.0, 0.0, true)
        d.update(50, 30.0, 3.0, true)
        d.update(100, 9.81, 20.0, true)
        for (at in 150L..5000L step 50) assertFalse(d.update(at, if (at % 1000 == 0L) 13.0 else 9.81, 0.0, true))
    }

    @Test fun bouncesAfterImpactDoNotCancelFall() {
        for (level in listOf("low", "medium", "high")) {
            val d = NativeFallDetector().apply { sensitivity = level }
            var t = 0L
            while (t < 1000) { d.update(t, 9.81, 0.3, true); t += 10 }
            while (t < 1450) { d.update(t, 1.0, 4.0, true); t += 10 }
            d.update(t, 62.0, 12.0, true)
            val impact = t
            t += 10
            var fired = 0L
            while (t < impact + 6000) {
                val since = t - impact
                val a = when (since) { 350L -> 28.0; 700L -> 21.0; else -> if (since < 1100) 9.81 + 3.0 * kotlin.math.sin(t / 15.0) else 9.81 }
                val g = if (since < 1100) 4.0 else 0.02
                if (d.update(t, a, g, true)) { fired = t; break }
                t += 10
            }
            assertTrue("rơi rồi nảy phải báo trong 3 s: $level", fired > 0 && fired - impact < 3000)
        }
    }
    @Test fun strongShakingThenTableIsNotAFall() {
        for (level in listOf("low", "medium", "high")) {
            val d = NativeFallDetector().apply { sensitivity = level }
            for (t in 0L..15000L step 10) {
                val a = if (t < 3000) kotlin.math.abs(9.81 + 22 * kotlin.math.sin(2 * kotlin.math.PI * 4 * t / 1000.0)) + 0.5
                    else if (t < 3400) 9.81 + 3 * kotlin.math.sin(t / 20.0) else 9.81
                val g = if (t < 3000) 5.0 + 3 * kotlin.math.sin(t / 30.0) else if (t < 3400) 1.0 else 0.02
                assertFalse("lắc mạnh không phải ngã: $level $t", d.update(t, a, g, true))
            }
        }
    }
}
