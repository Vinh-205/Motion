package com.example.cam_bien_te_nga

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract.CommonDataKinds.Phone
import android.provider.Settings
import android.net.Uri
import android.os.PowerManager
import android.media.AudioManager
import android.media.RingtoneManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var pickerResult: MethodChannel.Result? = null
    private var soundPickerResult: MethodChannel.Result? = null
    private var permissionResult: MethodChannel.Result? = null
    private var callPermissionResult: MethodChannel.Result? = null
    private var smsPermissionResult: MethodChannel.Result? = null
    private val main = Handler(Looper.getMainLooper())
    private val previewSound by lazy { AlertSound(this) }
    private var localCountdownSound = false
    private val stopPreview = Runnable { previewSound.stop(); localCountdownSound = false }
    private val storageWorker = Executors.newSingleThreadExecutor()
    private val prefs get() = SafetyStore.prefs(applicationContext)
    override fun getInitialRoute(): String? {
        // Captured before Dart starts: a slow emulator must not be mistaken for SOS.
        return if (intent?.getBooleanExtra("motionAlert", false) == true ||
            prefs.getLong("deadline", 0) > 0 || prefs.getBoolean("sosActive", false)) "/motion-alert"
        else super.getInitialRoute()
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        updateAlertWindow()
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        updateAlertWindow()
    }
    private var alertWindow: Boolean? = null
    private fun updateAlertWindow() {
        val alert = intent?.getBooleanExtra("motionAlert", false) == true && prefs.getLong("deadline", 0) > 0
        // state() chạy khoảng 2 lần/giây: chỉ đổi cờ cửa sổ khi giá trị thật sự thay đổi, tránh làm
        // hệ thống (nhất là ColorOS) tính lại hiển thị cửa sổ liên tục.
        if (alertWindow == alert) return
        alertWindow = alert
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(alert)
            setTurnScreenOn(alert)
        } else {
            @Suppress("DEPRECATION") val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (alert) window.addFlags(flags) else window.clearFlags(flags)
        }
        // Never dismiss the device's secure keyguard.
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "motion/device_safety").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getEmergencyCard" -> {
                        check(!getSystemService(android.app.KeyguardManager::class.java).isKeyguardLocked) { "Hãy mở khóa để quản lý thẻ." }
                        val card = EmergencyCardStore.read(this)
                        result.success(card.keys().asSequence().associateWith { card.get(it) })
                    }
                    "saveEmergencyCard" -> {
                        check(!getSystemService(android.app.KeyguardManager::class.java).isKeyguardLocked) { "Hãy mở khóa để sửa thẻ." }
                        EmergencyCardStore.save(this, call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                        result.success(null)
                    }
                    "deleteEmergencyCard" -> {
                        check(!getSystemService(android.app.KeyguardManager::class.java).isKeyguardLocked) { "Hãy mở khóa để xóa thẻ." }
                        EmergencyCardStore.delete(this); result.success(null)
                    }
                    "openEmergencyCard" -> { startActivity(Intent(this, EmergencyCardActivity::class.java)); result.success(null) }
                    "state" -> result.success(state())
                    "requestSmsPermission" -> {
                        check(smsPermissionResult == null && permissionResult == null && callPermissionResult == null) { "Một yêu cầu quyền đang mở." }
                        if (checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) result.success(state())
                        else {
                            prefs.edit().putBoolean("smsPermissionRequested", true).apply()
                            smsPermissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.SEND_SMS), 7307)
                        }
                    }
                    "setAutoCall" -> setAutoCall(call, result)
                    "getAlertSound" -> result.success(AlertSound.settings(this))
                    "resetAlertSound" -> {
                        check(prefs.getLong("deadline", 0) == 0L && !prefs.getBoolean("sosActive", false) && !localCountdownSound) { "Hãy xử lý cảnh báo trước khi đổi âm thanh." }
                        main.removeCallbacks(stopPreview); previewSound.stop()
                        prefs.edit().remove("alertSoundUri").commit()
                        result.success(AlertSound.settings(this))
                    }
                    "pickAlertSound" -> pickAlertSound(result)
                    "previewAlertSound" -> {
                        val active = call.argument<Boolean>("active") == true
                        check(prefs.getLong("deadline", 0) == 0L && !prefs.getBoolean("sosActive", false) && !localCountdownSound) { "Cảnh báo đang phát. Hãy xử lý cảnh báo trước khi nghe thử." }
                        main.removeCallbacks(stopPreview)
                        if (active) { previewSound.start(); main.postDelayed(stopPreview, 3000) }
                        else previewSound.stop()
                        result.success(null)
                    }
                    "getAppearance" -> result.success(prefs.getString("appearance", "light"))
                    "setAppearance" -> {
                        val mode = call.argument<String>("mode")
                        check(mode == "light" || mode == "dark")
                        prefs.edit().putString("appearance", mode).apply()
                        result.success(null)
                    }
                    "openFullScreenSettings" -> {
                        if (Build.VERSION.SDK_INT >= 34) startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName")))
                        else openAppSettings()
                        result.success(state())
                    }
                    "openAppSettings" -> { openAppSettings(); result.success(state()) }
                    "requestBatteryExemption" -> { requestBatteryExemption(); result.success(state()) }
                    "leaveToHome" -> {
                        check(SafetyService.instance?.running == true && prefs.getBoolean("enabled", false) && prefs.getBoolean("monitoring", true) && prefs.getBoolean("backgroundEnabled", true)) { "Hãy bật giám sát nền trước khi về Home." }
                        moveTaskToBack(true)
                        result.success(state())
                    }
                    "setLocalAlertSound" -> {
                        main.removeCallbacks(stopPreview)
                        // Never interfere with an active real countdown or arm the SMS service.
                        if (SafetyService.instance == null || (prefs.getLong("deadline", 0) == 0L && !prefs.getBoolean("sosActive", false))) {
                            if (call.argument<Boolean>("active") == true) {
                                localCountdownSound = true
                                previewSound.start()
                                if (call.argument<Boolean>("continuous") != true) main.postDelayed(stopPreview, 35000)
                            } else { localCountdownSound = false; previewSound.stop() }
                        }
                        result.success(null)
                    }
                    "pickContact" -> pickContact(result)
                    "saveContact" -> saveContact(call, result)
                    "saveContacts" -> {
                        val contacts = (call.argument<List<Map<String, Any?>>>("contacts") ?: emptyList()).map { c ->
                            mapOf("id" to (c["id"] as? String ?: ""), "name" to (c["name"] as? String ?: "").trim().take(80), "phone" to SafetyStore.normalize(c["phone"] as? String ?: ""))
                        }
                        persistContacts(contacts, result)
                    }
                    "dialEmergency" -> {
                        val number = call.argument<String>("number") ?: ""
                        check(number in listOf("113", "114", "115")) { "Số khẩn cấp không hợp lệ." }
                        startActivity(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", number, null)))
                        result.success(state())
                    }
                    "enableRealSms" -> enableReal(call, result)
                    "disableRealSms" -> { SafetyService.instance?.disable(); prefs.edit().putBoolean("enabled", false).apply(); result.success(state()) }
                    "configure" -> { saveConfiguration(call); SafetyService.instance?.configure(); result.success(state()) }
                    "manualSos" -> { requireService().manualSos(); result.success(state()) }
                    "confirmSafe" -> { requireService().confirmSafe(); result.success(state()) }
                    "dismissSos" -> { requireService().dismissSos(); result.success(state()) }
                    "beginDemo" -> {
                        requireDebug()
                        if (SafetyService.instance?.startDemo() == false) result.error("real_alert_active", "Có cảnh báo thật đang chờ xử lý. Không thể bắt đầu mô phỏng.", null)
                        else result.success(state())
                    }
                    "endDemo" -> { SafetyService.instance?.endDemo(); result.success(state()) }
                    "startBackgroundDryRun" -> {
                        requireDebug()
                        check(SafetyService.instance == null) { "Hãy tắt SOS thật trước khi kiểm thử." }
                        check(!prefs.getBoolean("enabled", false)) { "Không kiểm thử khi SOS thật đã được cấu hình bật." }
                        startSafety(result, true)
                    }
                    "triggerDryRunAlert" -> { requireDebug(); val service = requireService(); check(service.dryRun); service.beginDryRunAlert(call.argument<Boolean>("autoCallDryRun") == true); result.success(state()) }
                    "leaveDryRunToHome" -> {
                        requireDebug(); check(requireService().dryRun)
                        moveTaskToBack(true)
                        result.success(state())
                    }
                    else -> result.notImplemented()
                }
            } catch (error: IllegalStateException) { result.error("not_ready", error.message, null) }
            catch (_: Exception) { result.error("device_error", "Không hoàn tất được thao tác Android. Vui lòng thử lại.", null) }
        }
    }
    private fun requireService() = SafetyService.instance?.takeIf { it.running } ?: throw IllegalStateException("Dịch vụ SOS chưa chạy. Hãy bật lại SOS thật trong Cài đặt.")
    private fun requireDebug() { check(applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) { "Chỉ dùng trong bản kiểm thử." } }
    private fun openAppSettings() = startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
    /** Hộp thoại hệ thống "Cho phép chạy nền không giới hạn pin"; nếu máy không hỗ trợ thì mở trang cài đặt. */
    private fun requestBatteryExemption() {
        if (getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)) { openAppSettings(); return }
        try {
            startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
        } catch (_: ActivityNotFoundException) {
            try { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) } catch (_: ActivityNotFoundException) { openAppSettings() }
        }
    }
    private fun state(): Map<String, Any?> {
        updateAlertWindow()
        val notifications = getSystemService(NotificationManager::class.java)
        val sensorManager = getSystemService(android.hardware.SensorManager::class.java)
        return SafetyStore.snapshot(this) + mapOf(
        "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}",
        "androidVersion" to "${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
        "smsPermission" to (checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED),
        "locationPermission" to (checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED || checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED),
        "notificationPermission" to (notifications.areNotificationsEnabled() && (Build.VERSION.SDK_INT < 26 || notifications.getNotificationChannel("motion_alert")?.importance != NotificationManager.IMPORTANCE_NONE)),
        "fullScreenAllowed" to (Build.VERSION.SDK_INT < 34 || notifications.canUseFullScreenIntent()),
        "batteryUnrestricted" to getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName),
        "simReady" to android.telephony.SubscriptionManager.isValidSubscriptionId(SmsDispatch.defaultSubscription()),
        "hasRequiredSensors" to (SensorCapabilities.accelerometer(sensorManager) != null),
        "hasGyroscope" to (SensorCapabilities.gyroscope(sensorManager) != null),
        "sensorMode" to if (SensorCapabilities.accelerometer(sensorManager) == null) "manual" else if (SensorCapabilities.gyroscope(sensorManager) == null) "accelerometer" else "full",
        "sensorSampleHz" to (SafetyService.instance?.sensorSampleHz ?: 0.0),
        "impactThreshold" to (SafetyService.instance?.detector?.impactThreshold ?: 23.0),
        "nativeAcceleration" to SafetyService.instance?.accelerationValues,
        "nativeRotation" to SafetyService.instance?.rotationValues,
        "smsPermissionNeedsSettings" to (checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED && prefs.getBoolean("smsPermissionRequested", false) && !shouldShowRequestPermissionRationale(Manifest.permission.SEND_SMS)),
        "alarmVolume" to getSystemService(AudioManager::class.java).getStreamVolume(AudioManager.STREAM_ALARM),
    )
    }
    private fun saveConfiguration(call: MethodCall) {
        val editor = prefs.edit()
        call.argument<Number>("countdownSeconds")?.let { editor.putInt("countdownSeconds", it.toInt().coerceIn(15, 30)) }
        call.argument<String>("sensitivity")?.let { check(it in listOf("low", "medium", "high")); editor.putString("sensitivity", it) }
        call.argument<Boolean>("monitoring")?.let { editor.putBoolean("monitoring", it) }
        call.argument<Boolean>("backgroundEnabled")?.let { editor.putBoolean("backgroundEnabled", it) }
        call.argument<Boolean>("shakeSosEnabled")?.let { editor.putBoolean("shakeSosEnabled", it) }
        call.argument<String>("ownerName")?.let { editor.putString("ownerName", it.trim().take(80)) }
        editor.apply()
    }
    private fun enableReal(call: MethodCall, result: MethodChannel.Result) {
        check(permissionResult == null && smsPermissionResult == null && callPermissionResult == null) { "Một yêu cầu cấp quyền đang mở." }
        check(SafetyStore.contacts(this).isNotEmpty()) { "Hãy lưu ít nhất một liên hệ khẩn cấp hợp lệ trước." }
        check(Build.HARDWARE !in listOf("ranchu", "goldfish")) { "SOS qua SIM cần điện thoại Android thật có SIM. Máy ảo không gửi SMS." }
        check(android.telephony.SubscriptionManager.isValidSubscriptionId(SmsDispatch.defaultSubscription())) { "Hãy lắp SIM và chọn SIM SMS mặc định trong cài đặt điện thoại." }
        saveConfiguration(call)
        if (SensorCapabilities.accelerometer(getSystemService(android.hardware.SensorManager::class.java)) == null) prefs.edit().putBoolean("monitoring", false).apply()
        val required = mutableListOf<String>()
        if (checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            prefs.edit().putBoolean("smsPermissionRequested", true).apply()
            required.add(Manifest.permission.SEND_SMS)
        }
        // Request essential SMS separately; optional location/notifications follow on retry.
        if (required.isEmpty() && checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            required.add(Manifest.permission.ACCESS_COARSE_LOCATION); required.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (Manifest.permission.SEND_SMS !in required && Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) required.add(Manifest.permission.POST_NOTIFICATIONS)
        if (required.isEmpty()) startSafety(result, false)
        else {
            permissionResult = result
            requestPermissions(required.distinct().toTypedArray(), 7304)
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7307) {
            val result = smsPermissionResult ?: return
            smsPermissionResult = null
            result.success(state())
            return
        }
        if (requestCode == 7306) {
            val result = callPermissionResult ?: return
            callPermissionResult = null
            val granted = checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
            prefs.edit().putBoolean("autoCallEnabled", granted).apply()
            if (granted) result.success(state()) else result.error("call_denied", "Chưa có quyền gọi điện. Tự gọi đang tắt; SMS vẫn hoạt động độc lập.", null)
            return
        }
        if (requestCode != 7304) return
        val result = permissionResult ?: return
        permissionResult = null
        if (checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            result.error("sms_denied", "Android chưa cấp quyền SMS. Cuộc gọi không thay thế SMS. Bấm CẤP QUYỀN SMS hoặc mở Cài đặt ứng dụng → Quyền → SMS. Nếu quyền bị khóa/không xuất hiện, trình cài đặt hoặc chính sách thiết bị có thể đang hạn chế SMS; app không thể tự vượt giới hạn này.", null)
            return
        }
        if (Manifest.permission.SEND_SMS in permissions) { enableReal(MethodCall("enableRealSms", null), result); return }
        startSafety(result, false)
    }
    private fun startSafety(result: MethodChannel.Result, dryRun: Boolean) {
        if (!dryRun) prefs.edit().putBoolean("enabled", true).apply()
        prefs.edit().putString("startupError", "").apply()
        try {
            val intent = Intent(this, SafetyService::class.java).putExtra("dryRun", dryRun)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
            fun awaitStart(attempt: Int) {
                if (SafetyService.instance?.running == true) result.success(state())
                else if (prefs.getString("startupError", "")!!.isNotEmpty() || attempt >= 50) {
                    prefs.edit().putBoolean("enabled", false).apply()
                    stopService(Intent(this, SafetyService::class.java))
                    result.error("service_failed", prefs.getString("startupError", "")!!.ifEmpty { "Dịch vụ giám sát chưa khởi chạy. Vui lòng thử lại khi app đang mở." }, null)
                } else main.postDelayed({ awaitStart(attempt + 1) }, 100)
            }
            main.post { awaitStart(0) }
        } catch (_: Exception) {
            prefs.edit().putBoolean("enabled", false).apply()
            result.error("service_failed", "Android chặn khởi chạy dịch vụ. Hãy mở app và thử lại.", null)
        }
    }
    private fun setAutoCall(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") == true
        if (!enabled) { prefs.edit().putBoolean("autoCallEnabled", false).apply(); result.success(state()); return }
        check(callPermissionResult == null) { "Một yêu cầu quyền gọi đang mở." }
        check(Build.HARDWARE !in listOf("ranchu", "goldfish")) { "Tự gọi SOS cần điện thoại thật. Máy ảo không gọi điện." }
        check(SafetyStore.contacts(this).isNotEmpty()) { "Hãy lưu người nhận trước khi bật tự gọi." }
        if (checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
            prefs.edit().putBoolean("autoCallEnabled", true).apply(); result.success(state())
        } else { callPermissionResult = result; requestPermissions(arrayOf(Manifest.permission.CALL_PHONE), 7306) }
    }
    private fun saveContact(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")?.trim() ?: ""
        val phone = SafetyStore.normalize(call.argument<String>("phone") ?: "")
        check(name.isNotEmpty() && SafetyStore.validPhone(phone)) { "Tên hoặc số điện thoại chưa hợp lệ." }
        val previous = SafetyStore.contacts(this)
        val contact = mapOf("id" to (previous.firstOrNull()?.get("id") ?: java.util.UUID.randomUUID().toString()), "name" to name, "phone" to phone)
        persistContacts(listOf(contact) + previous.drop(1), result)
    }
    private fun persistContacts(contacts: List<Map<String, String>>, result: MethodChannel.Result) {
        check(contacts.size <= 10) { "Tối đa 10 liên hệ khẩn cấp." }
        check(contacts.all { it["id"]!!.isNotBlank() && it["name"]!!.isNotBlank() && SafetyStore.validPhone(it["phone"]!!) }) { "Liên hệ chưa hợp lệ." }
        check(contacts.map { SafetyStore.phoneKey(it["phone"]!!) }.distinct().size == contacts.size && contacts.map { it["id"] }.distinct().size == contacts.size) { "Số điện thoại hoặc mã liên hệ bị trùng." }
        check(contacts.isNotEmpty() || !prefs.getBoolean("enabled", false)) { "Tắt SOS qua SIM trước khi xóa liên hệ cuối cùng." }
        storageWorker.execute {
            val first = contacts.firstOrNull()
            val saved = prefs.edit().putString("contacts", JSONArray(contacts.map { JSONObject(it) }).toString())
                .putString("contactName", first?.get("name") ?: "").putString("contactPhone", first?.get("phone") ?: "").commit()
            main.post { result.success(saved) }
        }
    }
    @Suppress("DEPRECATION")
    private fun pickAlertSound(result: MethodChannel.Result) {
        check(soundPickerResult == null) { "Danh sách âm thanh đang mở." }
        check(prefs.getLong("deadline", 0) == 0L && !prefs.getBoolean("sosActive", false) && !localCountdownSound) { "Hãy xử lý cảnh báo trước khi đổi âm thanh." }
        main.removeCallbacks(stopPreview); previewSound.stop()
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            .putExtra(RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
            .putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, AlertSound.selectedUri(this))
            .putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Âm thanh cảnh báo Motion")
        soundPickerResult = result
        try { startActivityForResult(intent, 7305) }
        catch (_: Exception) { soundPickerResult = null; result.error("no_sound_picker", "Thiết bị không mở được danh sách âm báo thức.", null) }
    }
    @Suppress("DEPRECATION")
    private fun pickContact(result: MethodChannel.Result) {
        if (pickerResult != null) { result.error("picker_busy", "Danh bạ đang mở.", null); return }
        pickerResult = result
        try { startActivityForResult(Intent(Intent.ACTION_PICK).setType(Phone.CONTENT_TYPE), 7303) }
        catch (_: ActivityNotFoundException) { pickerResult = null; result.error("no_contacts_app", "Thiết bị chưa có ứng dụng chọn danh bạ. Bạn có thể nhập số thủ công.", null) }
        catch (_: Exception) { pickerResult = null; result.error("contact_error", "Không mở được danh bạ. Bạn có thể nhập số thủ công.", null) }
    }
    @Deprecated("Platform result bridge for FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 7305) {
            val result = soundPickerResult ?: return
            soundPickerResult = null
            if (resultCode != Activity.RESULT_OK) { result.success(null); return }
            @Suppress("DEPRECATION") val uri = if (Build.VERSION.SDK_INT >= 33) data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
                else data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            if (uri == null || uri.scheme !in listOf("content", "android.resource")) {
                result.error("invalid_sound", "Chưa chọn được âm thanh hợp lệ. Giữ nguyên âm hiện tại.", null); return
            }
            val editor = prefs.edit()
            editor.putString("alertSoundUri", uri.toString())
            if (editor.commit()) result.success(AlertSound.settings(this))
            else result.error("sound_save_failed", "Không lưu được âm thanh. Vui lòng thử lại.", null)
            return
        }
        if (requestCode != 7303) return
        val result = pickerResult ?: return
        pickerResult = null
        if (resultCode != Activity.RESULT_OK) { result.success(null); return }
        val uri = data?.data
        if (uri == null) { result.error("empty_contact", "Không lấy được số từ liên hệ đã chọn.", null); return }
        try {
            contentResolver.query(uri, arrayOf(Phone.DISPLAY_NAME, Phone.NUMBER), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val number = SafetyStore.normalize(cursor.getString(cursor.getColumnIndexOrThrow(Phone.NUMBER)) ?: "")
                    check(SafetyStore.validPhone(number)) { "Số vừa chọn chưa hợp lệ. Bạn có thể nhập số thủ công." }
                    result.success(mapOf("name" to (cursor.getString(cursor.getColumnIndexOrThrow(Phone.DISPLAY_NAME)) ?: ""), "phone" to number))
                    return
                }
            }
            result.error("empty_contact", "Liên hệ này chưa có số điện thoại.", null)
        } catch (_: SecurityException) { result.error("contact_denied", "Android chưa cho đọc số vừa chọn. Hãy chọn lại hoặc nhập thủ công.", null) }
        catch (error: Exception) { result.error("invalid_contact", error.message ?: "Không đọc được số liên hệ.", null) }
    }
    override fun onDestroy() {
        smsPermissionResult?.error("activity_closed", "Màn hình cấp quyền SMS đã đóng.", null); smsPermissionResult = null
        callPermissionResult?.error("activity_closed", "Màn hình cấp quyền gọi đã đóng.", null); callPermissionResult = null
        main.removeCallbacks(stopPreview)
        previewSound.stop()
        soundPickerResult?.error("activity_closed", "Màn hình chọn âm thanh đã đóng.", null); soundPickerResult = null
        pickerResult?.error("activity_closed", "Màn hình chọn liên hệ đã đóng.", null); pickerResult = null
        permissionResult?.error("activity_closed", "Màn hình cấp quyền đã đóng.", null); permissionResult = null
        storageWorker.shutdown()
        super.onDestroy()
    }

    override fun onStart() {
        super.onStart()
        SafetyService.appVisible = true
        SafetyService.instance?.visibilityChanged(true)
    }
    override fun onStop() {
        SafetyService.appVisible = false
        SafetyService.instance?.visibilityChanged(false)
        main.removeCallbacks(stopPreview)
        previewSound.stop()
        localCountdownSound = false
        super.onStop()
    }
}
