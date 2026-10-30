package com.example.cam_bien_te_nga

import android.app.Activity
import android.app.KeyguardManager
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.graphics.Color
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Button

/** Isolated read-only surface: no Flutter navigation, account, editing or outgoing call. */
class EmergencyCardActivity : Activity() {
    private val changes = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == "sosActive" && getSystemService(KeyguardManager::class.java).isKeyguardLocked &&
            !SafetyStore.prefs(this).getBoolean("sosActive", false)) finish()
    }
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        SafetyStore.prefs(this).registerOnSharedPreferenceChangeListener(changes)
        render()
    }
    override fun onResume() { super.onResume(); render() }
    override fun onDestroy() {
        SafetyStore.prefs(this).unregisterOnSharedPreferenceChangeListener(changes)
        super.onDestroy()
    }
    private fun render() {
        val locked = getSystemService(KeyguardManager::class.java).isKeyguardLocked
        val active = SafetyStore.prefs(this).getBoolean("sosActive", false)
        val permitted = EmergencyCardPolicy.canReadLocked(EmergencyCardStore.available(this), true, active)
        if (locked && !permitted) { finish(); return }
        if (Build.VERSION.SDK_INT >= 27) { setShowWhenLocked(permitted); setTurnScreenOn(permitted) }
        else if (permitted) {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(28, 48, 28, 32); setBackgroundColor(Color.rgb(245,247,239))
        }
        fun text(value: String, size: Float = 19f) { column.addView(TextView(this).apply {
            this.text = value; textSize = size; setTextColor(Color.rgb(23,37,27)); setPadding(0, 10, 0, 14)
        }) }
        text("MOTION · THẺ THÔNG TIN KHẨN CẤP", 25f)
        text("Thông tin do người dùng tự khai. Chưa được xác minh y tế.", 15f)
        try {
            val card = EmergencyCardStore.read(this)
            for ((field, label) in linkedMapOf("name" to "Họ tên", "conditions" to "Bệnh nền", "allergies" to "Dị ứng",
                "medications" to "Thuốc đang dùng", "bloodGroup" to "Nhóm máu (tự khai)", "heightCm" to "Chiều cao (cm)",
                "weightKg" to "Cân nặng (kg)", "contactName" to "Người liên hệ", "contactPhone" to "Số liên hệ")) {
                val value = card.optString(field).ifBlank { "Chưa cung cấp" }
                text("$label\n$value")
            }
        } catch (_: Exception) { text("Không đọc được thẻ. Không có thông tin để hiển thị.") }
        column.addView(Button(this).apply { text = "ĐÓNG THẺ"; setOnClickListener { finish() } })
        setContentView(ScrollView(this).apply { addView(column) })
    }
}
