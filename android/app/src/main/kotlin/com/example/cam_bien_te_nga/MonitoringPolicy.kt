package com.example.cam_bien_te_nga

/** Background permission is independent from the master detector and any active SOS. */
object MonitoringPolicy {
    fun collectSensors(monitoring: Boolean, backgroundEnabled: Boolean, appVisible: Boolean) =
        monitoring && (appVisible || backgroundEnabled)
}
