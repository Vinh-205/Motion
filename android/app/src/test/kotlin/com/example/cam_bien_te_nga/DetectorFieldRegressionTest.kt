package com.example.cam_bien_te_nga
import org.junit.Assert.*
import org.junit.Test
import kotlin.math.sin
import kotlin.math.max

class DetectorFieldRegressionTest {
    @Test fun adaptationCannotRunAwayAndCandidateThresholdIsFrozen() {
        val d = NativeFallDetector().apply { sensitivity = "high" }
        for (at in 0L..30000L step 10) {
            assertFalse(d.update(at, max(0.5, 9.81 + 19 * sin(at / 35.0)), 2.0, true))
            assertTrue(d.impactThreshold in 20.0..23.0)
        }
        d.reset()
        for (at in 0L..990L step 10) d.update(at, 9.81, 0.0, true)
        d.update(1000, 2.0, 0.0, true)
        val frozen = d.impactThreshold
        for (at in 1010L..1400L step 10) d.update(at, if (at % 20 == 0L) 15.0 else 2.0, 2.0, true)
        assertEquals(frozen, d.impactThreshold, 0.0001)
    }
    @Test fun sustainedLowGravityAndStrongImpactCanTriggerWithoutRotation() {
        for (level in listOf("low", "medium", "high")) {
            val d = NativeFallDetector().apply { sensitivity = level }
            for (at in 0L..150L step 10) assertFalse(d.update(at, 2.0, 0.0, true))
            assertFalse(d.update(160, 35.0, 0.0, true))
            assertEquals(3, d.state)
            for (at in 170L..3160L step 10) assertFalse(d.update(at, 9.81, 0.0, true))
            assertTrue(d.update(3170, 9.81, 0.0, true))
            assertTrue(d.triggerReason.contains("120 ms"))
            assertTrue(d.triggerReason.contains("35.00"))
        }
    }
    @Test fun shortMildJitterDoesNotEraseHighSensitivityQuietWindow() {
        val d = NativeFallDetector().apply { sensitivity = "high" }
        d.update(0, 2.0, 0.0, true)
        d.update(100, 30.0, 5.0, true)
        d.update(200, 9.81, 5.0, true)
        for (at in 210L..3400L step 10) d.update(at, if (at % 1000 in 0L..30L) 11.5 else 9.81, 0.1, true)
        assertEquals(4, d.state)
        assertTrue(d.triggerReason.contains("phần yên"))
    }
    @Test fun rejectionStatesExplainMissingEvidence() {
        val d = NativeFallDetector()
        d.update(0, 2.0, 0.0, true)
        for (at in 10L..1600L step 10) d.update(at, 9.81, 0.0, true)
        assertTrue(d.lastRejection.contains("va chạm"))
        d.update(1700, 9.81, 0.0, false)
        assertTrue(d.lastRejection.contains("dữ liệu"))
    }
}
