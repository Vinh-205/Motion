package com.example.cam_bien_te_nga

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telecom.TelecomManager
import java.util.concurrent.Executors

/** One attempt per SOS, independent of the SMS queue. Never calls in dry runs. */
object CallDispatch {
    private val worker = Executors.newSingleThreadExecutor()
    fun dispatch(service: SafetyService, id: String) {
        val p = SafetyStore.prefs(service)
        if (!p.getBoolean("eventAutoCall", false)) {
            SafetyStore.updateCall(service, id, "off", "Tự gọi đang tắt."); return
        }
        if (service.dryRun || p.getBoolean("eventDryRun", false)) {
            SafetyStore.updateCall(service, id, "dryRun", "KIỂM THỬ: không gọi API điện thoại."); return
        }
        val phone = p.getString("eventCallPhone", "") ?: ""
        worker.execute {
            if (p.getBoolean("callClaimed.$id", false)) {
                SafetyStore.updateCall(service, id, "unknown", "Đã có lần yêu cầu gọi; không tự gọi lại."); return@execute
            }
            if (!p.edit().putBoolean("callClaimed.$id", true).commit()) {
                SafetyStore.updateCall(service, id, "failed", "Không lưu được mã lần gọi; chưa thực hiện gọi."); return@execute
            }
            service.mainHandler.post {
                try {
                    check(SafetyService.instance === service && p.getBoolean("enabled", false)) { "Dịch vụ đã dừng; chưa yêu cầu gọi." }
                    check(p.getBoolean("autoCallEnabled", false) && p.getBoolean("sosActive", false) && p.getString("currentId", "") == id) { "SOS hoặc tự gọi đã được tắt trước khi thực hiện cuộc gọi." }
                    check(Build.HARDWARE !in listOf("ranchu", "goldfish")) { "Không gọi thật trên máy ảo." }
                    check(service.checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) { "Chưa có quyền gọi điện; SMS vẫn được xử lý riêng." }
                    check(SafetyStore.validPhone(phone)) { "Số gọi SOS không hợp lệ." }
                    @Suppress("DEPRECATION")
                    check(!android.telephony.PhoneNumberUtils.isEmergencyNumber(phone)) { "Không tự gọi số cơ quan khẩn cấp." }
                    val mode = service.getSystemService(AudioManager::class.java).mode
                    check(mode != AudioManager.MODE_IN_CALL && mode != AudioManager.MODE_IN_COMMUNICATION) { "Đang có cuộc gọi khác; không yêu cầu cuộc gọi mới. SMS vẫn được xử lý riêng." }
                    service.getSystemService(TelecomManager::class.java).placeCall(Uri.fromParts("tel", phone, null), Bundle().apply {
                        putBoolean(TelecomManager.EXTRA_START_CALL_WITH_SPEAKERPHONE, true)
                    })
                    SafetyStore.updateCall(service, id, "requested", "Đã yêu cầu Android gọi liên hệ ưu tiên và bật loa ngoài. Chưa xác nhận kết nối hoặc người nhận trả lời.")
                } catch (error: IllegalStateException) {
                    SafetyStore.updateCall(service, id, "failed", error.message ?: "Chưa yêu cầu được cuộc gọi.")
                } catch (_: Exception) {
                    SafetyStore.updateCall(service, id, "failed", "Android chưa cho thực hiện cuộc gọi. Kiểm tra quyền, SIM gọi mặc định và sóng; SMS vẫn được xử lý riêng.")
                }
            }
        }
    }
}
