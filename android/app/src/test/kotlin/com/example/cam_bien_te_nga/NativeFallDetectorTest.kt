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
}
