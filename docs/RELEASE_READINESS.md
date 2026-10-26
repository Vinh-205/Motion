# Motion 1.0.1 (build 3) — SMS và gọi SOS qua SIM

## Đã thay đổi trong luồng sử dụng

- Mở mới hiển thị **Chưa bật SOS**; không giả định giám sát đã hoạt động khi chưa thiết lập.
- Không có nút mô phỏng trong luồng mặc định, kể cả chạy debug thông thường. Bản release khóa mô phỏng bằng `kReleaseMode`; bộ kiểm thử phải bật rõ `allowSimulation` để dùng dữ liệu giả.
- SOS chưa sẵn sàng thì mở màn hình thiết lập. Controller cũng chặn yêu cầu SOS khi dịch vụ thật chưa chạy, không tạo sự kiện hỗ trợ giả.
- Sau khi chọn liên hệ, SIM, tên người dùng và đồng ý quyền SMS, người dùng bật SOS qua SIM. Khi dịch vụ đang chạy, nút SOS thực hiện gửi SMS thật. SMS có thể tính phí theo người nhận và số phần tin.
- Lịch sử giao diện dùng thật không trộn sự kiện mô phỏng hoặc dry-run. Dữ liệu cũ không bị xóa.
- Nút **Nghe thử** chỉ kiểm tra âm thanh, không tạo sự kiện hay gửi SMS.

## Mức độ sẵn sàng

| Hạng mục | Bằng chứng / giới hạn |
| --- | --- |
| Giao diện, nhiều liên hệ, sáng/tối, lịch sử, âm thanh | Có mã chức năng và kiểm thử tự động |
| Giám sát nền, countdown, chốt danh sách và gửi hàng loạt | Đã kiểm thử native dry-run trên máy ảo; API SMS bị chặn trong phép thử |
| Gửi/nhận SMS và vị trí thật | Người dùng xác nhận đã thành công trên điện thoại đã thử; chưa xác nhận trên nhiều máy/SIM |
| Gọi liên hệ ưu tiên cùng đợt SMS | Đã triển khai, có đồng ý/quyền riêng và kiểm thử dry-run; chưa xác nhận cuộc gọi thật trên điện thoại |
| Phát hiện té ngã thực tế | Thuật toán chuỗi đã kiểm thử bằng dữ liệu kiểm soát; chưa đo tỷ lệ bỏ sót/báo giả trên tập dữ liệu thực tế |
| Chạy lâu, khóa màn hình, tối ưu pin theo hãng | Cần kiểm thử dài hạn trên thiết bị đích; không tự bật theo máy sau khởi động lại |
| Tự mở màn hình khi báo động | Có full-screen intent, phụ thuộc quyền và quyết định của Android |
| Phát hành cửa hàng | Chưa tải lên hoặc được Google Play/App Store duyệt |

Đây là bản chức năng có thể cài để sử dụng thử thực tế có kiểm soát. Không có căn cứ để gọi là hệ thống đã được xác thực y tế hoặc bảo đảm phát hiện mọi cú ngã. Việc bỏ mô phỏng không thay thế kiểm chứng độ tin cậy trên thiết bị thật.

## Build và ký bản phát hành

```powershell
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

Khóa release riêng: `android/keystore/motion-release.jks`. Cấu hình/mật khẩu nằm trong `android/key.properties`. Cả hai được bỏ qua bởi `android/.gitignore`, không đưa lên kho mã hoặc chia sẻ công khai. Sao lưu riêng hai file này để ký các bản cập nhật sau. Build release không dùng lại khóa debug.

APK: `build/app/outputs/flutter-apk/app-release.apk`.
AAB: `build/app/outputs/bundle/release/app-release.aab`.

Mã gói được giữ nguyên `com.example.cam_bien_te_nga` để tránh tự đổi danh tính ứng dụng trong dự án. Cần chốt mã gói trước lần đưa lên cửa hàng đầu tiên.

Nếu điện thoại đã cài APK debug, khóa ký release khác nên Android không cho cài đè. Ghi lại liên hệ/cấu hình cần giữ trước khi tự gỡ bản debug và cài release; không tự gỡ hoặc xóa dữ liệu trong quy trình build này. Từ lần cài release đầu tiên, các bản release tiếp theo dùng cùng khóa sẽ có thể cập nhật thông thường.

## Trước khi phát hành công khai

1. Kiểm chứng SMS thật: một/nhiều người nhận, mất sóng, SIM hết dịch vụ, quyền bị thu hồi, báo gửi/báo phát và việc không tự gửi trùng. Chỉ thử với người nhận đã đồng ý.
2. Kiểm chứng giám sát nền và âm báo khi khóa máy trên thiết bị đích; kiểm tra pin, DND, quyền full-screen và khởi động lại máy.
3. Thu thập dữ liệu cảm biến để đánh giá bỏ sót/báo giả; không thả rơi điện thoại hoặc yêu cầu người thật té.
4. Chuẩn bị chính sách quyền riêng tư, khai báo dữ liệu/quyền SMS và foreground service, nội dung giới thiệu đúng giới hạn; hoàn thành kiểm thử và xét duyệt tài khoản Google Play.

Nguồn: https://docs.flutter.dev/deployment/android · https://support.google.com/googleplay/android-developer/answer/10208820
