package com.example.cam_bien_te_nga

/** Pure reducer: one failed recipient must not hide another recipient's result. */
object SmsBatchSummary {
    fun status(states: List<String>): String = when {
        states.isEmpty() -> "failed"
        states.any { it in listOf("pending", "preparing", "sending", "") } -> "sending"
        states.all { it == "dryRun" } -> "dryRun"
        states.all { it == "delivered" } -> "delivered"
        states.all { it in listOf("sent", "delivered") } -> "sent"
        states.all { it == "failed" } -> "failed"
        states.all { it == "unknown" } -> "unknown"
        else -> "partial"
    }
    fun detail(states: List<String>): String {
        if (states.all { it == "dryRun" } && states.isNotEmpty()) return "KIỂM THỬ: ${states.size} người nhận; không gọi API gửi SMS."
        val sent = states.count { it in listOf("sent", "delivered") }
        val delivered = states.count { it == "delivered" }
        val failed = states.count { it == "failed" }
        val unknown = states.count { it == "unknown" }
        val waiting = states.size - sent - failed - unknown
        return "Đã gửi đến nhà mạng: $sent/${states.size} · Báo phát: $delivered · Thất bại: $failed · Chưa xác nhận: $unknown · Đang xử lý: $waiting. Báo phát không xác nhận người nhận đã đọc."
    }
}
