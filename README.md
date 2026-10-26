# Motion

Ứng dụng Flutter giám sát té ngã và SOS trên Android. Phiên bản **1.0.1+3**.

## Tài liệu hướng dẫn cài đặt

Đọc **[Tài liệu hướng dẫn cài đặt](TAI_LIEU_HUONG_DAN_CAI_DAT.md)** để tải source, chạy trong VS Code, cài trên điện thoại và build APK.

Người tham gia test: **[Tải APK Android](https://github.com/Vinh-205/Motion/releases/download/v1.0.1-test.3/Motion-1.0.1-android.apk)** · **[QR tải app](TAI_LIEU_HUONG_DAN_CAI_DAT.md#tải-apk-để-tham-gia-test-không-cần-máy-tính)** · **[Hướng dẫn sử dụng](TAI_LIEU_HUONG_DAN_CAI_DAT.md#9-hướng-dẫn-sử-dụng-sau-khi-cài-đặt)**.

```powershell
git clone https://github.com/Vinh-205/Motion.git
cd Motion
flutter pub get
flutter devices
flutter run -d <device-id>
```

Thay `<device-id>` bằng ID thiết bị thực tế. Cần cài Flutter và Android toolchain trước.

## Chức năng

- Giám sát cảm biến và chạy nền bằng Android foreground service.
- Cảnh báo đếm ngược, nút TÔI ỔN và âm thanh SOS tùy chọn.
- SMS SOS kèm vị trí đến nhiều liên hệ; tùy chọn gọi một liên hệ ưu tiên trong cùng đợt SOS.
- Lịch sử chi tiết, sáng/tối và icon chuyển động.
- Mở trình gọi 113/114/115 bằng thao tác chủ động; không tự gọi số khẩn cấp.

SOS chỉ hoạt động sau khi thiết lập và cấp quyền. Release không hiển thị nút mô phỏng. Người dùng đã xác nhận SMS/vị trí thật trên điện thoại đã thử; cuộc gọi thật và độ tin cậy trên nhiều thiết bị vẫn cần kiểm chứng. Thuật toán có thể bỏ sót hoặc báo giả; app không phải thiết bị y tế.

## Các README và tài liệu dùng để làm gì?

| Tệp | Mục đích |
| --- | --- |
| README.md | Giới thiệu dự án, chức năng và mục lục trên GitHub |
| [Tài liệu hướng dẫn cài đặt](TAI_LIEU_HUONG_DAN_CAI_DAT.md) | Hướng dẫn chính để tải, cài và chạy app |
| [SOS_SMS.md](docs/SOS_SMS.md) | Quyền, SIM, SMS và giám sát nền |
| [AUTO_CALL.md](docs/AUTO_CALL.md) | Thiết lập tự gọi liên hệ ưu tiên |
| [RELEASE_READINESS.md](docs/RELEASE_READINESS.md) | Mức kiểm chứng, ký và build release |
| [HUONG_DAN_DEMO.md](HUONG_DAN_DEMO.md) | Thuật toán, kịch bản kiểm tra; có nội dung thử nghiệm cũ được ghi chú |
| [MORPHICONS.md](docs/MORPHICONS.md) | Công cụ tạo bộ icon và animation |
| [README animation](assets/animations/README.md) | Nguồn gốc và cách dùng tài nguyên Lottie |
| [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) | Giấy phép thành phần bên thứ ba |

README trong thư mục tài nguyên iOS là ghi chú của bộ khung Flutter cho lập trình viên. README là tài liệu đọc trong GitHub/IDE, không phải màn hình của app.

## Cấu trúc

- `lib/`: giao diện, trạng thái, logic Flutter.
- `android/`: dịch vụ nền, cảm biến, SMS, cuộc gọi và âm thanh native.
- `assets/`: tài nguyên animation.
- `test/`, `integration_test/`, `android/app/src/test/`: kiểm thử.
- `tool/morphicons/`: công cụ tạo icon; không cần npm để chạy app.
- Các thư mục nền tảng khác là khung Flutter; SOS native hiện triển khai cho Android.

Source và tài nguyên cần thiết được đưa lên Git. Build, cache, đường dẫn SDK riêng, khóa ký và mật khẩu được bỏ qua.
