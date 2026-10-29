package com.example.cam_bien_te_nga

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import java.text.Normalizer
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlin.math.sqrt
import org.json.JSONObject
import org.json.JSONArray
import android.media.AudioManager

/** Native owner of real fall detection, deadlines and SMS; independent of Flutter's lifecycle. */
class SafetyService : Service(), SensorEventListener, LocationListener {
    companion object {
        var instance: SafetyService? = null
            private set
        const val NOTIFICATION_ID = 7301
        const val ALERT_ID = 7302
        var appVisible = false
    }
    val mainHandler = Handler(Looper.getMainLooper())
    val detector = NativeFallDetector()
    var running = false
        private set
    var dryRun = false
        private set
    var sensorError = ""
        private set
    var lastLocation: Location? = null
        private set
    private lateinit var sensors: SensorManager
    private lateinit var locations: LocationManager
    private var wakeLock: PowerManager.WakeLock? = null
    private var wakeLeaseAt = 0L
    private val alertSound by lazy { AlertSound(this) }
    private var rotationMagnitude = 0.0
    private var rotationAt = 0L
    private var accelerationAt = 0L
    private var hasRotation = false
    private var previousAcceleration: DoubleArray? = null
    private var previousAccelerationTimestamp = 0L
    var accelerationValues: List<Double>? = null
        private set
    var rotationValues: List<Double>? = null
        private set
    var sensorSampleHz = 0.0
        private set
    private var sampleWindowAt = 0L
    private var sampleCount = 0
    private var monitoringStartedAt = 0L
    private var cooldownUntil = 0L
    private var demoUntil = 0L
    private var monotonicDeadline = 0L
    private var timeoutSince = 0L
    private var tickCount = 0
    private var callAudioPaused = false
    private val p get() = SafetyStore.prefs(this)
    private val notifications get() = getSystemService(NotificationManager::class.java)
    private val ticker = object : Runnable {
        override fun run() {
            if (!running) return
            if (!dryRun && checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                p.edit().putString("startupError", "Quyền SMS đã bị thu hồi. Hãy bật lại SOS thật sau khi cấp quyền.").apply()
                disable(); return
            }
            val now = SystemClock.elapsedRealtime()
            if (!dryRun && (p.getLong("deadline", 0) > 0 || p.getBoolean("sosActive", false))) {
                val mode = getSystemService(AudioManager::class.java).mode
                val talking = mode == AudioManager.MODE_IN_CALL || mode == AudioManager.MODE_IN_COMMUNICATION
                if (talking && !callAudioPaused) { alertSound.stop(); callAudioPaused = true }
                else if (!talking && callAudioPaused) { callAudioPaused = false; startAlarm() }
            }
            if (p.getLong("deadline", 0) > 0 && now >= monotonicDeadline) sendPending()
            if (p.getString("smsStatus", "") == "sending" && timeoutSince > 0 && now - timeoutSince > 120000) {
                SafetyStore.updateSms(this@SafetyService, p.getString("currentId", "")!!, "unknown", "Android chưa trả kết quả gửi SMS. Không tự gửi lại để tránh trùng tin.")
            }
            if (shouldCollectSensors() && !sensorsReady() && now - monitoringStartedAt > 2000) {
                detector.reset()
                sensorError = "Chưa nhận đủ dữ liệu cảm biến mới. Chưa thể phát hiện té ngã."
            }
            tickCount++
            if (tickCount % 5 == 0) updateNotification()
            if (tickCount % 5 == 0) syncWakeLock()
            mainHandler.postDelayed(this, 200)
        }
    }
    override fun onCreate() {
        super.onCreate()
        instance = this
        sensors = getSystemService(SensorManager::class.java)
        locations = getSystemService(LocationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            notifications.createNotificationChannel(NotificationChannel("motion_monitoring", "Giám sát chuyển động", NotificationManager.IMPORTANCE_LOW))
            notifications.createNotificationChannel(NotificationChannel("motion_alert", "Xác nhận an toàn", NotificationManager.IMPORTANCE_HIGH).apply { setSound(null, null); enableVibration(false) })
        }
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stopBackground" && running) {
            p.edit().putBoolean("backgroundEnabled", false).apply()
            configure()
            return START_STICKY
        }
        if (intent?.action == "confirmSafe" && running) { confirmSafe(); return START_STICKY }
        if (intent?.action == "dismissSos" && running) { dismissSos(); return START_STICKY }
        if (intent?.action == "disable") { disable(); return START_NOT_STICKY }
        if (running) return START_STICKY
        dryRun = intent?.getBooleanExtra("dryRun", false) == true && applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (!p.getBoolean("enabled", false) && !dryRun) { stopSelf(); return START_NOT_STICKY }
        try {
            val locationAllowed = hasLocationPermission() && (locations.isProviderEnabled(LocationManager.GPS_PROVIDER) || locations.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
            val notification = buildNotification(false)
            if (Build.VERSION.SDK_INT >= 34) {
                var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
                if (locationAllowed) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                startForeground(NOTIFICATION_ID, notification, type)
            } else if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION_ID, notification, if (locationAllowed) ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION else 0)
            } else startForeground(NOTIFICATION_ID, notification)
            running = true
            p.edit().putString("startupError", "").apply()
            wakeLock = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "motion:fall-monitor").apply { setReferenceCounted(false); acquire(10 * 60 * 1000L) }
            configure()
            if (locationAllowed) startLocation()
            if (!dryRun && p.getBoolean("eventDryRun", false)) {
                p.edit().putLong("deadline", 0).putBoolean("sosActive", false).putString("currentId", "").putString("smsStatus", "").putString("sosMessage", "").apply()
            }
            val deadline = p.getLong("deadline", 0)
            if (deadline > 0) {
                monotonicDeadline = SystemClock.elapsedRealtime() + (deadline - System.currentTimeMillis()).coerceAtLeast(0)
                startAlarm()
            } else if (p.getString("smsStatus", "") in listOf("sending", "preparing")) {
                SafetyStore.updateSms(this, p.getString("currentId", "")!!, "unknown", "Dịch vụ đã khởi động lại. Chưa xác nhận kết quả lần gửi trước; không tự gửi trùng.")
            }
            if (p.getBoolean("sosActive", false) && p.getString("callStatus", "") == "pending") {
                SafetyStore.updateCall(this, p.getString("currentId", "")!!, "unknown", "Dịch vụ đã khởi động lại. Không tự gọi lại khi chưa biết kết quả lần trước.")
            }
            mainHandler.post(ticker)
            if (intent?.action == "confirmSafe") confirmSafe()
            if (intent?.action == "dismissSos") dismissSos()
            else if (p.getBoolean("sosActive", false)) startAlarm()
            return if (dryRun) START_NOT_STICKY else START_STICKY
        } catch (_: Exception) {
            p.edit().putBoolean("enabled", false).putString("startupError", "Android không cho khởi chạy dịch vụ giám sát. Mở app, kiểm tra quyền và bật lại SOS thật.").apply()
            running = false
            stopSelf()
            return START_NOT_STICKY
        }
    }
    fun configure() {
        detector.reset()
        detector.sensitivity = p.getString("sensitivity", "medium") ?: "medium"
        sensors.unregisterListener(this)
        accelerationAt = SystemClock.elapsedRealtime()
        monitoringStartedAt = accelerationAt
        rotationAt = 0
        accelerationAt = 0
        previousAcceleration = null
        previousAccelerationTimestamp = 0L
        accelerationValues = null; rotationValues = null
        sensorSampleHz = 0.0; sampleCount = 0; sampleWindowAt = 0
        sensorError = ""
        if (shouldCollectSensors()) {
            val acc = SensorCapabilities.accelerometer(sensors)
            val gyro = SensorCapabilities.gyroscope(sensors)
            hasRotation = gyro != null
            detector.rotationAvailable = hasRotation
            if (acc == null) sensorError = "Thiết bị không có cảm biến gia tốc. Chỉ dùng SOS thủ công."
            else {
                // 100 Hz requested, no batching. Actual rate depends on phone hardware.
                val accRegistered = sensors.registerListener(this, acc, 10000, 0)
                val gyroRegistered = gyro == null || sensors.registerListener(this, gyro, 10000, 0)
                if (!accRegistered || !gyroRegistered) sensorError = "Không đăng ký được luồng cảm biến Android. Hãy bật lại giám sát."
            }
        }
        syncWakeLock()
        updateNotification()
    }
    fun shouldCollectSensors(): Boolean = MonitoringPolicy.collectSensors(
        p.getBoolean("monitoring", true), p.getBoolean("backgroundEnabled", true), appVisible)
    fun visibilityChanged(visible: Boolean) {
        appVisible = visible
        if (running && !p.getBoolean("backgroundEnabled", true)) configure()
    }
    private fun syncWakeLock() {
        val needed = shouldCollectSensors() || p.getLong("deadline", 0) > 0 || p.getBoolean("sosActive", false)
        if (needed && (wakeLock?.isHeld != true || SystemClock.elapsedRealtime() - wakeLeaseAt >= 5 * 60 * 1000L)) {
            wakeLock?.acquire(10 * 60 * 1000L)
            wakeLeaseAt = SystemClock.elapsedRealtime()
        }
        else if (!needed && wakeLock?.isHeld == true) wakeLock?.release()
    }
    override fun onSensorChanged(event: SensorEvent) {
        if (!running || !shouldCollectSensors()) return
        val now = event.timestamp / 1000000L
        if (event.sensor.type == Sensor.TYPE_GYROSCOPE || event.sensor.type == Sensor.TYPE_GYROSCOPE_UNCALIBRATED) {
            val corrected = (0..2).map { i -> event.values[i].toDouble() - if (event.sensor.type == Sensor.TYPE_GYROSCOPE_UNCALIBRATED && event.values.size >= 6) event.values[i + 3].toDouble() else 0.0 }
            rotationValues = corrected
            rotationMagnitude = sqrt(corrected.sumOf { it * it }); rotationAt = now; return
        }
        if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
        val values = event.values.take(3).map { it.toDouble() }
        val magnitude = sqrt(values.sumOf { it * it })
        val delta = previousAcceleration?.let { previous -> sqrt((0..2).sumOf { i -> (values[i] - previous[i]) * (values[i] - previous[i]) }) * (50.0 / (now - previousAccelerationTimestamp).coerceAtLeast(1)) } ?: 0.0
        previousAcceleration = values.toDoubleArray()
        previousAccelerationTimestamp = now
        accelerationValues = values
        accelerationAt = SystemClock.elapsedRealtime()
        if (sampleWindowAt == 0L) sampleWindowAt = now
        sampleCount++
        if (now - sampleWindowAt >= 1000) { sensorSampleHz = sampleCount * 1000.0 / (now - sampleWindowAt); sampleCount = 0; sampleWindowAt = now }
        // Delivery can interleave gyro/accelerometer timestamps slightly out of order.
        if (hasRotation && (rotationAt == 0L || kotlin.math.abs(now - rotationAt) > 250)) { detector.reset(); return }
        sensorError = ""
        if (dryRun || SystemClock.elapsedRealtime() < demoUntil || SystemClock.elapsedRealtime() < cooldownUntil || p.getLong("deadline", 0) > 0 || p.getBoolean("sosActive", false)) return
        if (detector.update(now, magnitude, rotationMagnitude, true, delta)) beginAlert()
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    fun beginAlert() {
        if (p.getLong("deadline", 0) > 0 || p.getBoolean("sosActive", false)) return
        val now = System.currentTimeMillis()
        val seconds = p.getInt("countdownSeconds", 30).coerceIn(15, 30)
        p.edit().putString("currentId", UUID.randomUUID().toString()).putString("source", "sensor")
            .putLong("eventAt", now).putLong("deadline", now + seconds * 1000L)
            .putString("eventPhone", p.getString("contactPhone", "")).putString("eventContactName", p.getString("contactName", "")).putString("smsStatus", "")
            .putString("sosMessage", "").putInt("eventCountdown", seconds).putBoolean("eventDryRun", dryRun).apply()
        monotonicDeadline = SystemClock.elapsedRealtime() + seconds * 1000L
        p.edit().putString("eventDetectionReason", if (dryRun) "Kiểm thử dry-run; không suy luận từ cảm biến." else detector.triggerReason).apply()
        captureRecipients()
        captureEventMetadata()
        startAlarm(); updateNotification()
    }
    fun beginDryRunAlert(withCall: Boolean) {
        check(dryRun)
        beginAlert()
        if (withCall && p.getLong("deadline", 0) > 0) {
            p.edit().putBoolean("eventAutoCall", true).putString("callStatus", "pending").apply()
            captureEventMetadata()
        }
    }
    fun startDemo(): Boolean {
        if (p.getLong("deadline", 0) > 0 || p.getBoolean("sosActive", false)) return false
        detector.reset(); demoUntil = SystemClock.elapsedRealtime() + 120000
        return true
    }
    fun endDemo() { demoUntil = 0; cooldownUntil = SystemClock.elapsedRealtime() + 8000; detector.reset() }
    fun remainingMilliseconds(): Long = if (p.getLong("deadline", 0) > 0) (monotonicDeadline - SystemClock.elapsedRealtime()).coerceAtLeast(0) else 0
    fun sensorsReady(): Boolean {
        val now = SystemClock.elapsedRealtime()
        return running && shouldCollectSensors() && accelerationAt > 0 && now - accelerationAt in 0..1999 && (!hasRotation || (rotationAt > 0 && now - rotationAt in 0..1999))
    }
    fun confirmSafe() {
        if (p.getLong("deadline", 0) == 0L) return
        SafetyStore.record(this, mapOf("id" to p.getString("currentId", ""), "at" to p.getLong("eventAt", 0), "source" to "sensor", "outcome" to "safe", "smsStatus" to "", "detail" to "Người dùng xác nhận an toàn; không gửi SMS."))
        p.edit().putLong("deadline", 0).putBoolean("sosActive", false).putString("smsStatus", "").apply()
        stopAlarm(); detector.reset(); cooldownUntil = SystemClock.elapsedRealtime() + 8000; updateNotification()
    }
    fun manualSos() {
        if (p.getBoolean("sosActive", false)) return
        if (p.getLong("deadline", 0) == 0L) {
            p.edit().putString("currentId", UUID.randomUUID().toString()).putString("source", "manual").putLong("eventAt", System.currentTimeMillis()).putString("eventPhone", p.getString("contactPhone", "")).putString("eventContactName", p.getString("contactName", "")).putInt("eventCountdown", 0).putBoolean("eventDryRun", dryRun).apply()
            captureRecipients()
        }
        sendPending()
    }
    private fun sendPending() {
        if (p.getBoolean("sosActive", false)) return
        val id = p.getString("currentId", "") ?: ""
        if (id.isEmpty()) return
        p.edit().putLong("deadline", 0).putBoolean("sosActive", true).putString("smsStatus", "preparing").putString("sosMessage", "Đang chuẩn bị cảnh báo SMS.").apply()
        notifications.cancel(ALERT_ID)
        startAlarm(); timeoutSince = SystemClock.elapsedRealtime()
        captureEventMetadata()
        val message = buildSms()
        SafetyStore.record(this, mapOf("id" to id, "at" to p.getLong("eventAt", 0), "source" to p.getString("source", "sensor"), "outcome" to "sos", "smsStatus" to "preparing", "detail" to "Đang chuẩn bị cảnh báo SMS."))
        val recipients = SafetyStore.eventRecipients(this)
        if (recipients.isEmpty()) {
            // Compatibility with a pending alert created by the previous single-contact APK.
            SmsDispatch.dispatch(this, id, p.getString("eventPhone", "") ?: "", message)
        } else for (recipient in recipients) {
            SmsDispatch.dispatch(this, recipient["id"] as String, recipient["phone"] as String, message)
        }
        CallDispatch.dispatch(this, id)
        updateNotification()
    }
    fun dismissSos() {
        stopAlarm()
        p.edit().putBoolean("sosActive", false).putString("currentId", "").putString("smsStatus", "").putString("sosMessage", "").apply()
        cooldownUntil = SystemClock.elapsedRealtime() + 8000; detector.reset(); updateNotification()
    }
    private fun buildSms(): String {
        fun ascii(value: String) = Normalizer.normalize(value, Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "").replace('đ', 'd').replace('Đ', 'D')
        fun time(at: Long) = SimpleDateFormat("dd/MM/yyyy HH:mm:ss Z", Locale.US).format(Date(at))
        val owner = ascii(p.getString("ownerName", "")!!.trim()).ifEmpty { "Chu dien thoai" }.take(80)
        val description = if (p.getString("source", "sensor") == "manual") "$owner chu dong yeu cau tro giup" else "$owner co chuyen dong nghi ngo te nga; chua xac nhan sau ${p.getInt("eventCountdown", 30)} giay"
        val location = lastLocation
        val where = if (location == null) "Khong lay duoc vi tri; vui long lien he va kiem tra ngay." else "Vi tri gan nhat (${time(location.time)}, sai so ~${location.accuracy.toInt()}m): https://maps.google.com/?q=${location.latitude},${location.longitude}. Vui long kiem tra ngay."
        return "MOTION SOS: $description luc ${time(p.getLong("eventAt", System.currentTimeMillis()))}. $where"
    }
    private fun captureEventMetadata() {
        val manual = p.getString("source", "sensor") == "manual"
        val metadata = mutableMapOf<String, Any?>(
            "reason" to if (manual) "Người dùng chủ động nhấn SOS." else p.getString("eventDetectionReason", "Sự kiện cũ chưa lưu số đo kích hoạt."),
            "recipientName" to p.getString("eventContactName", ""),
            "recipientPhone" to p.getString("eventPhone", ""),
            "countdownSeconds" to p.getInt("eventCountdown", 30),
            "sensitivity" to p.getString("sensitivity", "medium"),
            "recipients" to SafetyStore.eventRecipients(this),
            "callStatus" to if (p.getBoolean("eventAutoCall", false)) "pending" else "off",
            "callDetail" to "", "callPhone" to p.getString("eventCallPhone", ""),
        )
        lastLocation?.let { location -> metadata.putAll(mapOf(
            "latitude" to location.latitude, "longitude" to location.longitude,
            "locationAccuracy" to location.accuracy.toDouble(), "locationAt" to location.time,
        )) }
        p.edit().putString("eventMetadata", JSONObject(metadata).toString()).apply()
    }
    private fun captureRecipients() {
        val id = p.getString("currentId", "")!!
        val recipients = SafetyStore.contacts(this).mapIndexed { index, c -> mapOf(
            "id" to "$id:r$index", "name" to c["name"], "phone" to c["phone"], "smsStatus" to "pending", "detail" to "Chưa gửi SMS."
        ) }
        p.edit().putString("eventRecipients", JSONArray(recipients.map { JSONObject(it) }).toString()).apply()
        p.edit().putBoolean("eventAutoCall", p.getBoolean("autoCallEnabled", false))
            .putString("eventCallPhone", recipients.firstOrNull()?.get("phone") as? String ?: "")
            .putString("callStatus", if (p.getBoolean("autoCallEnabled", false)) "pending" else "off").putString("callDetail", "").apply()
    }
    private fun hasLocationPermission() = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED || checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    private fun startLocation() {
        if (!hasLocationPermission()) return
        for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
            try {
                if (!locations.isProviderEnabled(provider)) continue
                locations.getLastKnownLocation(provider)?.let { if (lastLocation == null || it.time > lastLocation!!.time) lastLocation = Location(it) }
                locations.requestLocationUpdates(provider, 30000L, 10f, this, Looper.getMainLooper())
            } catch (_: SecurityException) { /* Location is optional; the alert must still be sent. */ }
            catch (_: IllegalArgumentException) { /* Provider not offered on this device. */ }
        }
    }
    override fun onLocationChanged(location: Location) { if (lastLocation == null || location.time >= lastLocation!!.time) lastLocation = Location(location) }
    @Deprecated("Legacy Android callback")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
    override fun onProviderEnabled(provider: String) = Unit
    override fun onProviderDisabled(provider: String) = Unit
    private fun startAlarm() {
        syncWakeLock()
        if (dryRun) return
        val mode = getSystemService(AudioManager::class.java).mode
        if (mode == AudioManager.MODE_IN_CALL || mode == AudioManager.MODE_IN_COMMUNICATION) { callAudioPaused = true; return }
        callAudioPaused = false
        alertSound.start()
    }
    private fun stopAlarm() {
        callAudioPaused = false
        alertSound.stop()
        notifications.cancel(ALERT_ID)
    }
    private fun buildNotification(alert: Boolean): Notification {
        val counting = p.getLong("deadline", 0) > 0
        val open = PendingIntent.getActivity(this, if (alert) 2 else 0, Intent(this, MainActivity::class.java)
            .putExtra("motionAlert", alert).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, if (alert) "motion_alert" else "motion_monitoring") else { @Suppress("DEPRECATION") Notification.Builder(this) }
        val seconds = ((monotonicDeadline - SystemClock.elapsedRealtime()).coerceAtLeast(0) + 999) / 1000
        builder.setSmallIcon(R.drawable.ic_motion_notification).setContentTitle(if (alert && counting) "MOTION · Bạn có ổn không?" else if (alert) "MOTION · SOS đã kích hoạt" else if (dryRun) "MOTION · KIỂM THỬ, không gửi SMS" else "MOTION · SOS qua SIM")
            .setContentText(if (alert && counting) "Còn $seconds giây trước khi gửi SMS. Bấm TÔI ỔN để hủy." else if (alert) "Đang phát âm SOS. Mở app để xem kết quả gửi SMS đến các liên hệ." else if (sensorError.isNotEmpty()) sensorError else if (p.getBoolean("sosActive", false)) "Mở app để xem kết quả gửi SMS." else if (!p.getBoolean("monitoring", true)) "Phát hiện tự động đang tắt. SOS thủ công vẫn sẵn sàng." else if (!p.getBoolean("backgroundEnabled", true)) "Giám sát nền đã tắt. Chỉ phát hiện khi mở app." else "Đang giám sát chuyển động, kể cả khi khóa màn hình.")
            .setContentIntent(open).setOngoing(!alert).setOnlyAlertOnce(true).setVisibility(Notification.VISIBILITY_PUBLIC)
        if (alert) {
            val safe = PendingIntent.getService(this, if (counting) 1 else 4, Intent(this, SafetyService::class.java).setAction(if (counting) "confirmSafe" else "dismissSos"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            builder.addAction(Notification.Action.Builder(null, if (counting) "TÔI ỔN" else "DỪNG ÂM SOS", safe).build()).setCategory(Notification.CATEGORY_ALARM)
                .addAction(Notification.Action.Builder(null, "MỞ CẢNH BÁO", open).build())
                .setPriority(Notification.PRIORITY_MAX)
            // Android chooses full screen on a locked device or heads-up while in use.
            // Debug dry runs never take over the screen or generate a real alarm.
            if (!dryRun && (Build.VERSION.SDK_INT < 34 || notifications.canUseFullScreenIntent())) {
                builder.setFullScreenIntent(open, true)
            }
        } else {
            val stop = PendingIntent.getService(this, 3, Intent(this, SafetyService::class.java).setAction("stopBackground"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            if (p.getBoolean("backgroundEnabled", true)) builder.addAction(Notification.Action.Builder(null, "TẮT GIÁM SÁT NỀN", stop).build())
        }
        return builder.build()
    }
    private fun updateNotification() {
        if (!running) return
        try {
            notifications.notify(NOTIFICATION_ID, buildNotification(false))
            if (p.getLong("deadline", 0) > 0 || p.getBoolean("sosActive", false)) notifications.notify(ALERT_ID, buildNotification(true))
        } catch (_: SecurityException) { /* Notification permission may be revoked independently. */ }
    }
    fun disable() {
        if (p.getLong("deadline", 0) > 0) {
            SafetyStore.record(this, mapOf("id" to p.getString("currentId", ""), "at" to p.getLong("eventAt", 0), "source" to "sensor", "outcome" to "cancelled", "smsStatus" to "", "detail" to "Đã hủy cảnh báo do tắt dịch vụ hoặc thiếu quyền SMS. Chưa gửi SMS."))
        }
        p.edit().putBoolean("sosActive", false).putString("currentId", "").putString("smsStatus", "").putString("sosMessage", "").apply()
        p.edit().putBoolean("enabled", false).putLong("deadline", 0).apply()
        running = false; stopAlarm(); stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
    }
    override fun onDestroy() {
        running = false
        mainHandler.removeCallbacksAndMessages(null)
        sensors.unregisterListener(this)
        try { locations.removeUpdates(this) } catch (_: Exception) { }
        stopAlarm()
        if (wakeLock?.isHeld == true) wakeLock?.release()
        if (instance === this) instance = null
        super.onDestroy()
    }
}
