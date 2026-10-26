package com.example.cam_bien_te_nga

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import java.util.concurrent.Executors

object SmsDispatch {
    private val worker = Executors.newSingleThreadExecutor()
    fun defaultSubscription(): Int = SubscriptionManager.getDefaultSmsSubscriptionId()
    fun preflight(context: Context): String? {
        if (context.checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) return "Chưa được cấp quyền gửi SMS."
        if (!SubscriptionManager.isValidSubscriptionId(defaultSubscription())) return "Chưa có SIM mặc định để gửi SMS. Hãy chọn SIM SMS mặc định trong cài đặt điện thoại."
        return null
    }
    fun dispatch(service: SafetyService, id: String, phone: String, text: String) {
        // Dry-run tests cannot reach any Android SMS API, even with SEND_SMS granted.
        if (service.dryRun || SafetyStore.prefs(service).getBoolean("eventDryRun", false)) {
            SafetyStore.updateSms(service, id, "dryRun", "KIỂM THỬ: đã tạo cảnh báo và vị trí; không gọi API gửi SMS.")
            return
        }
        val failure = preflight(service)
        if (failure != null || !SafetyStore.validPhone(phone)) {
            SafetyStore.updateSms(service, id, "failed", failure ?: "Số liên hệ không hợp lệ. Chưa gửi SMS.")
            return
        }
        val app = service.applicationContext
        // Persist the send claim before touching the modem. A process restart must never resend it.
        worker.execute {
            val prefs = SafetyStore.prefs(app)
            if (prefs.getBoolean("claimed.$id", false)) {
                SafetyStore.updateSms(app, id, "unknown", "Cảnh báo này đã có lần yêu cầu gửi. Không tự gửi trùng; chưa xác nhận kết quả.")
                return@execute
            }
            if (!prefs.edit().putBoolean("claimed.$id", true).commit()) {
                SafetyStore.updateSms(app, id, "failed", "Không lưu được mã cảnh báo, chưa gửi SMS.")
                return@execute
            }
            service.mainHandler.post {
                if (!prefs.getBoolean("enabled", false) || SafetyService.instance !== service) {
                    SafetyStore.updateSms(app, id, "failed", "Dịch vụ đã dừng trước khi yêu cầu gửi SMS.")
                    return@post
                }
                try {
                    val subscription = defaultSubscription()
                    check(SubscriptionManager.isValidSubscriptionId(subscription)) { "Không có SIM SMS mặc định." }
                    @Suppress("DEPRECATION")
                    val manager = if (Build.VERSION.SDK_INT >= 31) app.getSystemService(SmsManager::class.java).createForSubscriptionId(subscription) else SmsManager.getSmsManagerForSubscriptionId(subscription)
                    val parts = manager.divideMessage(text)
                    val sent = ArrayList<PendingIntent>()
                    val delivered = ArrayList<PendingIntent>()
                    for (index in parts.indices) {
                        fun callback(kind: String): PendingIntent {
                            val intent = Intent(app, SmsStatusReceiver::class.java)
                                .setAction("${app.packageName}.SMS.$kind.$id.$index")
                                .putExtra("id", id).putExtra("part", index).putExtra("total", parts.size).putExtra("kind", kind)
                            return PendingIntent.getBroadcast(app, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        }
                        sent.add(callback("sent")); delivered.add(callback("delivered"))
                    }
                    SafetyStore.updateSms(app, id, "sending", "Đang yêu cầu SIM gửi SMS đến liên hệ khẩn cấp. Chưa có xác nhận gửi.")
                    manager.sendMultipartTextMessage(phone, null, parts, sent, delivered)
                } catch (_: SecurityException) {
                    SafetyStore.updateSms(app, id, "failed", "Quyền SMS đã bị thu hồi hoặc Android chặn gửi SMS.")
                } catch (_: Exception) {
                    SafetyStore.updateSms(app, id, "failed", "Không yêu cầu gửi được SMS. Kiểm tra SIM mặc định, sóng và quyền SMS.")
                }
            }
        }
    }
}

class SmsStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: return
        val index = intent.getIntExtra("part", -1)
        val total = intent.getIntExtra("total", 0)
        val kind = intent.getStringExtra("kind") ?: return
        if (index !in 0 until total || total !in 1..100) return
        val event = SafetyStore.dispatchState(context, id) ?: return
        val p = SafetyStore.prefs(context)
        if (resultCode != Activity.RESULT_OK) {
            if (kind == "sent") SafetyStore.updateSms(context, id, "failed", "Một hoặc nhiều phần SMS gửi thất bại (mã $resultCode). Chưa xác nhận người thân nhận được đầy đủ.")
            return
        }
        p.edit().putBoolean("$kind.$id.$index", true).apply()
        if (!(0 until total).all { p.getBoolean("$kind.$id.$it", false) }) return
        if (event["smsStatus"] == "failed" || event["smsStatus"] == "delivered") return
        if (kind == "delivered") SafetyStore.updateSms(context, id, "delivered", "Nhà mạng đã báo phát SMS đến thiết bị nhận. Điều này không xác nhận người thân đã đọc hoặc đang trợ giúp.")
        else if (kind == "sent") SafetyStore.updateSms(context, id, "sent", "SIM đã báo gửi tất cả phần SMS đến nhà mạng. Chưa xác nhận người thân nhận hoặc đọc tin.")
    }
}
