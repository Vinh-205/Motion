package com.example.cam_bien_te_nga

import kotlin.math.PI
import kotlin.math.sin
import org.junit.Assert.*
import org.junit.Test

class GaitAndFallTest {
    @Test fun repeatedFootfallImpactsThenStoppingAreNotFallsButANewStrongerFallCanTrigger() {
        for (gyro in listOf(true, false)) for (thenFall in listOf(true, false)) {
            val d = NativeFallDetector().apply { rotationAvailable = gyro; sensitivity = "high" }
            for (at in 0L..19990L step 10) {
                val phase = at % 400
                val a = if (phase < 100) 3.0 else if (phase < 130) 28.0 else 9.81
                assertFalse("repeated footfall at $at", d.update(at, a, 1.8, gyro, 0.8))
            }
            assertTrue(d.impactThreshold > 20.0)
            if (!thenFall) {
                for (at in 20000L..25000L step 10) assertFalse(d.update(at, 9.81, 0.0, gyro))
            } else {
                for (at in 20000L..20090L step 10) assertFalse(d.update(at, 2.0, 0.0, gyro))
                assertFalse(d.update(20100, 45.0, 8.0, gyro, 50.0))
                for (at in 20110L..20300L step 10) assertFalse(d.update(at, 9.81, 8.0, gyro, 2.0))
                for (at in 20310L..23300L step 10) assertFalse(d.update(at, 9.81, 0.0, gyro))
                assertTrue(d.update(23310, 9.81, 0.0, gyro))
            }
        }
    }
    @Test fun walkingRunningAndThenSittingAreNotFalls() {
        for (gyro in listOf(true, false)) for (level in listOf("low", "medium", "high")) {
            val d = NativeFallDetector().apply { rotationAvailable = gyro; sensitivity = level }
            // Synthetic 100 Hz walking (2 Hz) and running (3 Hz), then sitting/standing still.
            // Negative examples, not a measured clinical accuracy claim.
            for (at in 0L..30000L step 10) {
                val t = at / 1000.0
                val a = if (at < 15000) 9.81 + 3.0 * sin(2 * PI * 2 * t) else 9.81 + 8.0 * sin(2 * PI * 3 * t)
                assertFalse("gait $gyro $level at $at", d.update(at, a, 1.2, gyro, 0.8))
            }
            for (at in 30010L..35000L step 10) assertFalse(d.update(at, 9.81, 0.0, gyro))
        }
    }
    @Test fun lowGravityImpactAndRestTriggerWithOrWithoutGyroAt100Hz() {
        for (gyro in listOf(true, false)) for (level in listOf("low", "medium", "high")) {
            val d = NativeFallDetector().apply { rotationAvailable = gyro; sensitivity = level }
            for (at in 0L..90L step 10) assertFalse(d.update(at, 2.0, 0.0, gyro))
            assertFalse(d.update(100, 35.0, 8.0, gyro, 50.0))
            for (at in 110L..300L step 10) assertFalse(d.update(at, 9.81, 8.0, gyro, 2.0))
            for (at in 310L..3300L step 10) assertFalse(d.update(at, 9.81, 0.0, gyro))
            assertTrue("fall $gyro $level", d.update(3310, 9.81, 0.0, gyro))
        }
    }
    @Test fun briefLowGlitchOrBumpCannotTriggerAccelerometerMode() {
        val d = NativeFallDetector().apply { rotationAvailable = false }
        d.update(0, 2.0, 0.0, false)
        d.update(10, 35.0, 0.0, false)
        for (at in 20L..5000L step 10) assertFalse(d.update(at, 9.81, 0.0, false))
        assertEquals(0, d.state)
    }
    @Test fun pocketMovementAndMissingDataPreventConfirmation() {
        val d = NativeFallDetector().apply { rotationAvailable = false }
        for (at in 0L..90L step 10) d.update(at, 2.0, 0.0, false)
        d.update(100, 35.0, 0.0, false)
        for (at in 110L..5000L step 10) assertFalse(d.update(at, 9.81, 0.0, false, 2.0))
        assertFalse(d.update(6000, 9.81, 0.0, false))
        assertEquals(0, d.state)
    }
}
