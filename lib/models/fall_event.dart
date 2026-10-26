enum EventSource { sensor, demo, manual }

enum EventOutcome { safe, sos, cancelled }

class FallEvent {
  const FallEvent({
    required this.at,
    required this.source,
    required this.outcome,
    this.simulated = true,
    this.smsStatus = '',
    this.detail = '',
    this.id = '',
    this.reason = '',
    this.recipientName = '',
    this.recipientPhone = '',
    this.sensitivity = '',
    this.countdownSeconds,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    this.locationAt,
    this.recipients = const [],
    this.callStatus = '',
    this.callDetail = '',
    this.callPhone = '',
  });
  final DateTime at;
  final EventSource source;
  final EventOutcome outcome;
  final bool simulated;
  final String smsStatus, detail;
  final String id, reason, recipientName, recipientPhone, sensitivity;
  final int? countdownSeconds;
  final double? latitude, longitude, locationAccuracy;
  final DateTime? locationAt;
  final List<Map<String, dynamic>> recipients;
  final String callStatus, callDetail, callPhone;
  factory FallEvent.fromDevice(Map<String, dynamic> value) => FallEvent(
    at: DateTime.fromMillisecondsSinceEpoch((value['at'] as num).toInt()),
    source: value['source'] == 'manual'
        ? EventSource.manual
        : EventSource.sensor,
    outcome: value['outcome'] == 'safe'
        ? EventOutcome.safe
        : value['outcome'] == 'cancelled'
        ? EventOutcome.cancelled
        : EventOutcome.sos,
    simulated: false,
    smsStatus: value['smsStatus'] as String? ?? '',
    detail: value['detail'] as String? ?? '',
    id: value['id'] as String? ?? '',
    callStatus: value['callStatus'] as String? ?? '',
    callDetail: value['callDetail'] as String? ?? '',
    callPhone: value['callPhone'] as String? ?? '',
    recipients: ((value['recipients'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    reason: value['reason'] as String? ?? '',
    recipientName: value['recipientName'] as String? ?? '',
    recipientPhone: value['recipientPhone'] as String? ?? '',
    sensitivity: value['sensitivity'] as String? ?? '',
    countdownSeconds: (value['countdownSeconds'] as num?)?.toInt(),
    latitude: (value['latitude'] as num?)?.toDouble(),
    longitude: (value['longitude'] as num?)?.toDouble(),
    locationAccuracy: (value['locationAccuracy'] as num?)?.toDouble(),
    locationAt: value['locationAt'] is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (value['locationAt'] as num).toInt(),
          )
        : null,
  );
  String get sourceLabel => switch (source) {
    EventSource.sensor => 'Chuỗi chuyển động nghi ngờ',
    EventSource.demo => 'Mô phỏng té ngã',
    EventSource.manual => 'SOS chủ động',
  };
  String get outcomeLabel {
    if (outcome == EventOutcome.safe) return 'Người dùng xác nhận an toàn';
    if (outcome == EventOutcome.cancelled) return 'Đã hủy cảnh báo';
    if (simulated) return 'SOS mô phỏng đã kích hoạt';
    return switch (smsStatus) {
      'sent' => 'SMS đã gửi đến nhà mạng',
      'delivered' => 'SMS được nhà mạng báo phát',
      'failed' => 'Gửi SMS thất bại',
      'unknown' => 'Chưa xác nhận kết quả gửi SMS',
      'dryRun' => 'Kiểm thử · không gửi SMS',
      'partial' => 'SMS có kết quả khác nhau theo người nhận',
      _ => 'Đang xử lý SMS',
    };
  }
}

String formatTime(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} • ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
}
