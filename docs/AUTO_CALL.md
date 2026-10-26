# Gọi điện cùng đợt SMS SOS — Motion 1.0.1 (build 3)

Người dùng đã xác nhận bản trước gửi được SMS và vị trí thật trên thiết bị thử nghiệm. Chức năng gọi mới chưa được xác nhận gọi/kết nối thực tế trong phiên phát triển này.

## Thiết lập

1. Lưu các liên hệ trong **Liên hệ**. Bấm biểu tượng điện thoại cạnh một người để đưa người đó lên đầu và làm số ưu tiên gọi. Những người còn lại vẫn nhận SMS.
2. Vào **Cài đặt → Thiết lập SOS qua SIM → Tự gọi cùng lúc gửi SOS**, đọc thông tin và đồng ý, sau đó cấp quyền gọi điện Android. Mặc định tự gọi tắt; bật tùy chọn chưa tạo cuộc gọi.
3. Chọn SIM gọi mặc định trong cài đặt điện thoại. SIM SMS và SIM gọi có thể khác nhau. Cần SIM có dịch vụ gọi/sóng và người nhận sẵn sàng nhận thử.

Tùy chọn gọi không tự bật giám sát. Vẫn cần bật **SOS qua SIM** để dịch vụ tiếp nhận và xử lý cảnh báo.

Khi hết thời gian xác nhận hoặc bấm gửi SOS, app yêu cầu gửi SMS đến toàn bộ danh sách và yêu cầu gọi một số ưu tiên độc lập với nhau, không chờ cuộc gọi kết thúc mới gửi SMS. Thời điểm tin/cuộc gọi thực sự đi còn phụ thuộc Android, SIM và nhà mạng.

App yêu cầu loa ngoài qua Android Telecom. Khi nhận thấy chế độ âm thanh đang dành cho cuộc gọi, dịch vụ tạm dừng âm báo để người dùng nói chuyện; nếu vẫn còn SOS thì phát lại âm sau khi cuộc gọi kết thúc. Hành vi loa/Bluetooth và SIM chọn lúc gọi phụ thuộc thiết bị; cần thử trên điện thoại đích.

## Giới hạn và trạng thái

- Một SOS chỉ yêu cầu gọi một lần đến số đã chốt khi cảnh báo bắt đầu, không gọi lại hoặc tự lần lượt gọi các số khác. Sửa người ưu tiên sau đó chỉ áp dụng cho cảnh báo tiếp theo.
- `Đã yêu cầu Android gọi` không xác nhận cuộc gọi đã kết nối, người nhận bắt máy hoặc đang trợ giúp. Không xin quyền đọc nhật ký cuộc gọi/đọc trạng thái điện thoại để suy diễn điều đó.
- Từ chối/thu hồi quyền gọi, đang có cuộc gọi khác, lỗi SIM hoặc Android chặn gọi không ngăn quá trình gửi SMS.
- Lần gọi có mã claim bền vững trước khi chạm Telecom; tiến trình khởi động lại không tự gọi lặp khi chưa rõ kết quả.
- Đóng SOS/tắt tùy chọn trước khi yêu cầu gọi được thực thi sẽ ngăn cuộc gọi còn chờ. Một cuộc gọi đã giao cho Android phải kết thúc trên màn hình cuộc gọi của điện thoại, nút đóng SOS không cúp máy.
- Không tự gọi số cơ quan khẩn cấp. Các nút 113/114/115 vẫn chỉ mở trình gọi điện để người dùng xác nhận.
- Chỉ dùng quyền `CALL_PHONE` khi bật tùy chọn; không xin `READ_CALL_LOG`, `READ_PHONE_STATE` hoặc quyền ghi âm. Không phát giọng nói tự động hoặc ghi âm cuộc gọi.

## Kiểm thử

Widget/unit tests kiểm tra đồng ý/từ chối, quyền gọi bị từ chối không tắt SMS và việc đổi/lưu người ưu tiên. Integration dry-run kiểm tra cùng một cảnh báo có SMS cho hai người và một yêu cầu gọi giả đến đúng người đã chốt; cả hai đường đều bị chặn trước API nhà mạng/Telecom, không xin quyền gọi và không gọi thật.

Tài liệu API: https://developer.android.com/reference/android/telecom/TelecomManager#placeCall(android.net.Uri,android.os.Bundle)
