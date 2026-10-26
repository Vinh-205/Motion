# Motion — giám sát té ngã và SOS qua SIM

Ứng dụng Flutter đọc accelerometer và gyroscope, kiểm tra chuỗi chuyển động nghi ngờ và cảnh báo xác nhận. Luồng mặc định dùng SOS thật qua SIM sau khi người dùng thiết lập liên hệ và cấp quyền; chưa thiết lập thì hiển thị **Chưa bật SOS**, không thay bằng SOS giả. Có tùy chọn gọi một liên hệ ưu tiên cùng đợt gửi SMS, cần bật và cấp quyền riêng. Mô phỏng chỉ dành cho bộ kiểm thử bật rõ chế độ test, bị khóa trong release. Không phải thiết bị y tế.

## Tài liệu

- [Tự gọi liên hệ ưu tiên cùng lúc gửi SMS SOS](docs/AUTO_CALL.md)

- [Bản release: mức sẵn sàng, ký ứng dụng và giới hạn đã kiểm chứng](docs/RELEASE_READINESS.md)

- [SOS qua SIM: thiết lập, quyền, chạy nền và giới hạn](docs/SOS_SMS.md)
- [Icon và animation morphicons trong Flutter](docs/MORPHICONS.md)
- [Hướng dẫn cài đặt từ Git trên Windows](docs/CAI_DAT.md)
- [Bản tài liệu để đọc và in PDF](docs/HUONG_DAN_CAI_DAT.html) — tải file về, mở bằng trình duyệt rồi Ctrl+P → Save as PDF.
- [Hướng dẫn demo và bảng ngưỡng thuật toán](HUONG_DAN_DEMO.md)

## Môi trường đã kiểm chứng

Flutter 3.47.4 stable / Dart 3.13.3, sensors_plus 7.1.1; Android SDK Platform 36; Pixel 7 emulator API 37.2. Project yêu cầu Dart ^3.13.3, Android minSdk 24. Giữ pubspec.lock; không tự nâng cấp đồng loạt package.

Cài [Git](https://git-scm.com/install/windows), [Flutter SDK](https://docs.flutter.dev/install/manual) và [Android toolchain](https://docs.flutter.dev/platform-integration/android/setup) trước. Plugin Flutter trong Android Studio không thay thế Flutter SDK.

## Lấy mã nguồn và chạy

Repository của nhóm: https://github.com/Vinh-205/LapTrinhDiDong. Mã nguồn Flutter được đặt tại gốc repository; thực hiện các lệnh bên dưới để cài và chạy.

```powershell
$repoUrl = 'https://github.com/Vinh-205/LapTrinhDiDong.git'
git clone $repoUrl cam_bien_te_nga
Set-Location cam_bien_te_nga
flutter doctor -v
flutter doctor --android-licenses
flutter pub get
flutter devices
flutter run -d emulator-5554
```

Đọc và chấp nhận license nếu đồng ý. Mở máy ảo trong Device Manager trước; thay device ID bằng kết quả flutter devices. Luôn chạy lệnh tại thư mục có pubspec.yaml. Không sao chép android/local.properties từ máy khác.

## Kiểm tra và build

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

APK: build/app/outputs/flutter-apk/app-debug.apk. Các kiểm thử Flutter, Kotlin và kiểm thử tích hợp dry-run trên emulator nằm trong test/, android/app/src/test/ và integration_test/. Cần kiểm tra lại sau clone trên máy khác; chưa kiểm thử gửi SMS thật trên điện thoại.

## Chức năng và demo

Bốn tab: Theo dõi, Lịch sử, Liên hệ, Cài đặt. Theo dõi hiển thị X/Y/Z, magnitude, công tắc giám sát và SOS thủ công. Nhấn MÔ PHỎNG TÉ NGÃ → TÔI ỔN để hủy, hoặc GỬI TRỢ GIÚP NGAY/chờ hết 15–30 giây để kích hoạt SOS mô phỏng. Xem kết quả ở Lịch sử.

Cảm biến trên Android thật dùng stream sensors_plus; emulator cung cấp cảm biến ảo. Nút mô phỏng không ghi đè dữ liệu cảm biến. Thuật toán yêu cầu chuỗi bất thường → va chạm → bằng chứng xoay → ít chuyển động, không kết luận từ một lần rung.

## Giới hạn

Mô phỏng giám sát foreground và không gửi ra ngoài. Khi bật SOS qua SIM trên điện thoại Android, dịch vụ native giám sát khi khóa màn hình và tự yêu cầu gửi SMS sau khi hết thời gian xác nhận. Buộc dừng app, khởi động máy, thu hồi quyền, lỗi SIM/sóng và tiết kiệm pin của hãng có thể làm gián đoạn. Liên hệ và lịch sử SMS thật lưu trên Android; lịch sử mô phỏng chỉ lưu trong phiên, tối đa 200 mục hiển thị. Ngưỡng chỉ dành cho thử nghiệm, chưa đánh giá độ chính xác hoặc gửi/nhận SMS trên điện thoại thật. Xem docs/SOS_SMS.md.

## Lỗi Kotlin khác ổ đĩa

Giữ kotlin.incremental=false trong android/gradle.properties. Cấu hình này xử lý lỗi incremental paths khi Pub cache ở C và project ở D. Nếu gặp lỗi khác, đọc log trước; xem hướng dẫn xử lý trong docs/CAI_DAT.md.

## Chuẩn bị repository để nộp

Hướng dẫn cập nhật repository hiện có, commit, push và thử clone sạch nằm ở mục 4 của docs/CAI_DAT.md. Không đưa build, .dart_tool, local.properties hoặc khóa ký lên Git. Nộp kèm link repository mà giảng viên truy cập được và tài liệu cài đặt.
