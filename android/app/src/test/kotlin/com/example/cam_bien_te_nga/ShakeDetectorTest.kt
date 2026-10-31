package com.example.cam_bien_te_nga

import kotlin.math.PI
import kotlin.math.sin
import org.junit.Assert.*
import org.junit.Test

class ShakeDetectorTest {
    private fun run(ms: Long, f: (Long) -> Triple<Double, Double, Double>): List<Long> {
        val d = ShakeDetector()
        val hits = mutableListOf<Long>()
        for (t in 0L..ms step 10) { val (x, y, z) = f(t); if (d.update(t, x, y, z)) hits += t }
        return hits
    }
    private fun still(t: Long) = Triple(0.0, 9.81, 0.0)

    @Test fun vigorousSideToSideShakeTriggersQuickly() {
        val hits = run(4000) { t -> if (t < 1000) still(t) else Triple(25 * sin(2 * PI * 3.5 * (t - 1000) / 1000.0), 9.81, 0.0) }
        assertEquals(1, hits.size)
        assertTrue("kích hoạt trong 2 s: ${hits[0]}", hits[0] - 1000 <= 2000)
    }
    @Test fun upAndDownShakeWhileHoldingUprightTriggers() {
        val hits = run(4000) { t -> if (t < 1000) still(t) else Triple(0.0, 9.81 + 25 * sin(2 * PI * 3.0 * (t - 1000) / 1000.0), 0.0) }
        assertEquals(1, hits.size)
    }
    @Test fun continuousShakingRespectsCooldown() {
        val hits = run(15000) { t -> if (t < 500) still(t) else Triple(28 * sin(2 * PI * 4.0 * t / 1000.0), 9.81, 0.0) }
        assertEquals(2, hits.size)
        assertTrue(hits[1] - hits[0] >= 10000)
    }
    @Test fun gentleShakeDoesNotTrigger() {
        assertTrue(run(8000) { t -> Triple(10 * sin(2 * PI * 3.0 * t / 1000.0), 9.81, 0.0) }.isEmpty())
    }
    @Test fun runningJumpingWalkingDoNotTrigger() {
        // Chạy: va chạm chân + pha bay (gia tốc ~0) — đỉnh mạnh chỉ một chiều.
        assertTrue(run(20000) { t -> val ph = t % 333; Triple(1.5 * sin(t / 50.0), if (ph < 30) 32.0 else if (ph < 150) 0.5 else 9.81, 0.0) }.isEmpty())
        assertTrue(run(20000) { t -> Triple(0.0, 9.81 + 8.0 * sin(2 * PI * 3 * t / 1000.0), 0.0) }.isEmpty())
        assertTrue(run(20000) { t -> val ph = t % 500; Triple(0.0, if (ph < 120) 3.0 else if (ph < 150) 26.0 else 9.81, 0.0) }.isEmpty())
        assertTrue(run(20000) { t -> Triple(0.0, 9.81 + 3.0 * sin(2 * PI * 2 * t / 1000.0), 0.0) }.isEmpty())
    }
    @Test fun dropWithBouncesDoesNotTrigger() {
        assertTrue(run(8000) { t ->
            when {
                t < 1000 -> still(t)
                t < 1450 -> Triple(0.3, 0.5, 0.2)
                t == 1450L -> Triple(5.0, 60.0, 8.0)
                t == 1800L -> Triple(3.0, 28.0, 2.0)
                t == 2150L -> Triple(2.0, 21.0, 1.0)
                t < 2500 -> Triple(1.5 * sin(t / 10.0), 9.81 + 4 * sin(t / 15.0), 0.0)
                else -> still(t)
            }
        }.isEmpty())
    }
    @Test fun invalidValuesAndGapsResetSafely() {
        val d = ShakeDetector()
        assertFalse(d.update(0, Double.NaN, 9.81, 0.0))
        for (t in 0L..1000L step 10) assertFalse(d.update(t, 0.0, 9.81, 0.0))
        assertFalse(d.update(5000, 30.0, 9.81, 0.0))
    }
}
