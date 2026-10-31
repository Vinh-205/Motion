package com.example.cam_bien_te_nga

/** Background permission is independent from the master detector and any active SOS. */
object MonitoringPolicy {
    fun collectSensors(monitoring: Boolean, backgroundEnabled: Boolean, appVisible: Boolean) =
        monitoring && (appVisible || backgroundEnabled)

    /** Sau khi khởi động máy/cập nhật app chỉ tự bật lại khi người dùng đã bật SOS thật và giám sát nền. */
    fun restartAfterBoot(enabled: Boolean, monitoring: Boolean, backgroundEnabled: Boolean) =
        enabled && monitoring && backgroundEnabled
}
