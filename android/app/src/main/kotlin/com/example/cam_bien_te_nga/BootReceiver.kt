package com.example.cam_bien_te_nga

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Bật lại giám sát nền sau khi điện thoại khởi động lại hoặc app vừa được cập nhật. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val p = SafetyStore.prefs(context)
        if (!MonitoringPolicy.restartAfterBoot(
                p.getBoolean("enabled", false), p.getBoolean("monitoring", true), p.getBoolean("backgroundEnabled", true))) return
        try {
            val service = Intent(context, SafetyService::class.java)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service) else context.startService(service)
        } catch (_: Exception) {
            p.edit().putString("startupError", "Android không cho tự bật lại giám sát sau khi khởi động máy. Hãy mở Motion để bật lại.").apply()
        }
    }
}
