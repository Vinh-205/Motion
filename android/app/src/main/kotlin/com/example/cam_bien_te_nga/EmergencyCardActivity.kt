package com.example.cam_bien_te_nga

import android.app.Activity
import android.app.KeyguardManager
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

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

    private class Palette(
        val background: Int, val surface: Int, val line: Int, val ink: Int, val muted: Int,
        val red: Int, val redSoft: Int, val button: Int, val buttonText: Int,
    )
    private fun isDark() =
        resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
    private fun palette() = if (isDark()) Palette(
        Color.rgb(16, 20, 18), Color.rgb(27, 33, 29), Color.rgb(53, 64, 54), Color.rgb(242, 243, 233),
        Color.rgb(164, 176, 162), Color.rgb(255, 120, 106), Color.argb(46, 255, 120, 106),
        Color.rgb(242, 243, 233), Color.rgb(16, 20, 18),
    ) else Palette(
        Color.rgb(245, 247, 239), Color.WHITE, Color.rgb(222, 227, 214), Color.rgb(23, 37, 27),
        Color.rgb(98, 110, 98), Color.rgb(190, 40, 28), Color.argb(26, 190, 40, 28),
        Color.rgb(23, 37, 27), Color.WHITE,
    )
    private fun dp(value: Int) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics).toInt()
    private fun rounded(color: Int, radius: Int, stroke: Int? = null) = GradientDrawable().apply {
        setColor(color); cornerRadius = dp(radius).toFloat(); if (stroke != null) setStroke(dp(1), stroke)
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
        val c = palette()
        if (Build.VERSION.SDK_INT >= 30) {
            val light = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
            window.insetsController?.setSystemBarsAppearance(if (isDark()) 0 else light, light)
        }
        val card = try { EmergencyCardStore.read(this) } catch (_: Exception) { null }
        fun field(key: String) = card?.optString(key)?.trim().orEmpty()
        val wrap = ViewGroup.LayoutParams.WRAP_CONTENT
        val match = ViewGroup.LayoutParams.MATCH_PARENT

        fun gap(height: Int) = View(this).apply { layoutParams = LinearLayout.LayoutParams(1, dp(height)) }
        fun label(text: String, color: Int = c.muted) = TextView(this).apply {
            this.text = text; textSize = 12f; setTextColor(color); typeface = Typeface.DEFAULT_BOLD; letterSpacing = 0.06f
        }
        fun value(text: String, size: Float = 17f) = TextView(this).apply {
            val empty = text.isBlank()
            this.text = if (empty) "Chưa cung cấp" else text
            textSize = size
            setTextColor(if (empty) c.muted else c.ink)
            if (empty) setTypeface(typeface, Typeface.ITALIC)
            setTextIsSelectable(!empty)
            setPadding(0, dp(3), 0, 0)
        }
        fun tile(title: String, raw: String, unit: String, accent: Boolean, last: Boolean) = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(12), dp(14), dp(12))
            background = if (accent) rounded(c.redSoft, 16) else rounded(c.surface, 16, c.line)
            layoutParams = LinearLayout.LayoutParams(0, wrap, 1f).apply { if (!last) marginEnd = dp(8) }
            addView(label(title, if (accent) c.red else c.muted))
            addView(TextView(this@EmergencyCardActivity).apply {
                text = if (raw.isBlank()) "—" else raw + unit
                textSize = 20f; typeface = Typeface.DEFAULT_BOLD
                setTextColor(if (accent) c.red else c.ink)
                setPadding(0, dp(4), 0, 0)
            })
        }
        fun section(rows: List<Pair<String, String>>) = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = rounded(c.surface, 18, c.line)
            setPadding(dp(16), dp(4), dp(16), dp(4))
            rows.forEachIndexed { index, (title, text) ->
                if (index > 0) addView(View(this@EmergencyCardActivity).apply {
                    setBackgroundColor(c.line); layoutParams = LinearLayout.LayoutParams(match, dp(1))
                })
                addView(LinearLayout(this@EmergencyCardActivity).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(0, dp(12), 0, dp(12))
                    addView(label(title)); addView(value(text))
                })
            }
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(16), dp(20), dp(24))
            setBackgroundColor(c.background)
        }
        root.addView(TextView(this).apply {
            text = "MOTION · THẺ KHẨN CẤP"; textSize = 12f; typeface = Typeface.DEFAULT_BOLD; letterSpacing = 0.08f
            setTextColor(c.red); background = rounded(c.redSoft, 20); setPadding(dp(12), dp(6), dp(12), dp(6))
            layoutParams = LinearLayout.LayoutParams(wrap, wrap)
        })
        root.addView(gap(14))
        if (card == null) {
            root.addView(value("Không đọc được thẻ. Không có thông tin để hiển thị."))
        } else {
            root.addView(TextView(this).apply {
                text = field("name").ifBlank { "Chưa có tên" }
                textSize = 28f; typeface = Typeface.DEFAULT_BOLD; setTextColor(c.ink)
            })
            root.addView(gap(4))
            root.addView(TextView(this).apply {
                text = "Thông tin do người dùng tự khai, chưa được xác minh y tế."
                textSize = 13f; setTextColor(c.muted)
            })
            root.addView(gap(18))
            root.addView(LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                addView(tile("NHÓM MÁU", field("bloodGroup"), "", accent = true, last = false))
                addView(tile("CHIỀU CAO", field("heightCm"), " cm", accent = false, last = false))
                addView(tile("CÂN NẶNG", field("weightKg"), " kg", accent = false, last = true))
            })
            root.addView(gap(12))
            root.addView(section(listOf(
                "BỆNH NỀN" to field("conditions"),
                "DỊ ỨNG" to field("allergies"),
                "THUỐC ĐANG DÙNG" to field("medications"),
            )))
            root.addView(gap(12))
            root.addView(section(listOf(
                "NGƯỜI LIÊN HỆ" to field("contactName"),
                "SỐ LIÊN HỆ" to field("contactPhone"),
            )))
        }
        root.addView(gap(20))
        root.addView(Button(this).apply {
            text = "ĐÓNG THẺ"; textSize = 16f; typeface = Typeface.DEFAULT_BOLD
            setTextColor(c.buttonText); background = rounded(c.button, 16); stateListAnimator = null
            layoutParams = LinearLayout.LayoutParams(match, dp(52))
            setOnClickListener { finish() }
        })

        val scroll = ScrollView(this).apply {
            setBackgroundColor(c.background); isFillViewport = true; clipToPadding = false
            addView(root)
        }
        // Android 15+ vẽ tràn màn hình: chừa chỗ cho thanh trạng thái, lỗ camera và thanh điều hướng.
        scroll.setOnApplyWindowInsetsListener { view, insets ->
            if (Build.VERSION.SDK_INT >= 30) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            } else {
                @Suppress("DEPRECATION")
                view.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            }
            insets
        }
        setContentView(scroll)
        scroll.requestApplyInsets()
    }
}
