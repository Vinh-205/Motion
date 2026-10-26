// Điểm mở rộng cho SMS/GPS sau này. Hiện KHÔNG gửi ra ngoài.
class SosService {
  String activate({
    required String contactName,
    required String phone,
    List<String> recipients = const [],
  }) {
    final person = recipients.isNotEmpty
        ? 'Liên hệ dự kiến:\n${recipients.join('\n')}'
        : contactName.isEmpty
        ? 'Chưa lưu người liên hệ.'
        : 'Liên hệ dự kiến: $contactName • $phone.';
    return 'Yêu cầu hỗ trợ đã được ghi nhận trong ứng dụng.\n$person\n'
        'ĐÂY LÀ MÔ PHỎNG: chưa gửi SMS, chưa gọi điện và chưa thông báo cho ai.';
  }
}
