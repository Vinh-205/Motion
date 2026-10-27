package com.example.cam_bien_te_nga

/** Keep modem/platform result codes visible; never describe a phone call as SMS success. */
object SmsFailure {
    fun describe(code: Int, modemCode: Int = -1): String {
        val reason = when (code) {
            1 -> "Lỗi gửi chung; kiểm tra tài khoản nhà mạng và SIM SMS mặc định."
            2 -> "Radio di động đang tắt; kiểm tra chế độ máy bay."
            3 -> "Android không tạo được nội dung SMS."
            4 -> "SIM không có dịch vụ/sóng di động."
            5 -> "Android giới hạn số SMS; chưa gửi thành công."
            6, 7 -> "Android/nhà mạng từ chối loại SMS này."
            else -> "Android hoặc modem từ chối gửi; kiểm tra SIM, tài khoản và quyền SMS."
        }
        return "$reason Mã Android: $code${if (modemCode >= 0) ", modem: $modemCode" else ""}. Một hoặc nhiều phần tin thất bại; không tự gửi lại."
    }
}
