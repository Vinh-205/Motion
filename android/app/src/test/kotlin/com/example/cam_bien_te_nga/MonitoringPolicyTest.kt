package com.example.cam_bien_te_nga
import org.junit.Assert.*
import org.junit.Test

class MonitoringPolicyTest {
    @Test fun backgroundOffStillDetectsInForeground() {
        assertTrue(MonitoringPolicy.collectSensors(true, false, true))
        assertFalse(MonitoringPolicy.collectSensors(true, false, false))
        assertTrue(MonitoringPolicy.collectSensors(true, true, false))
        assertTrue(MonitoringPolicy.collectSensors(true, true, true))
    }
    @Test fun masterOffAlwaysStopsAutomaticDetection() {
        for (background in listOf(true, false)) for (visible in listOf(true, false)) {
            assertFalse(MonitoringPolicy.collectSensors(false, background, visible))
        }
    }
    @Test fun bootRestartOnlyWhenRealSosAndBackgroundWereOn() {
        assertTrue(MonitoringPolicy.restartAfterBoot(true, true, true))
        assertFalse(MonitoringPolicy.restartAfterBoot(false, true, true))
        assertFalse(MonitoringPolicy.restartAfterBoot(true, false, true))
        assertFalse(MonitoringPolicy.restartAfterBoot(true, true, false))
    }
}
