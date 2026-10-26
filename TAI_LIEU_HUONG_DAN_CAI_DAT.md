# Tài liệu hướng dẫn cài đặt

Ứng dụng **Motion — giám sát té ngã và SOS qua SIM**, phiên bản **1.0.1+3**.
Repository: [Vinh-205/Motion](https://github.com/Vinh-205/Motion).

## 1. Chuẩn bị trên Windows

- Cài Git for Windows, Flutter SDK, Android Studio và VS Code.
- Thêm thư mục `flutter/bin` vào PATH; mở terminal mới sau khi chỉnh PATH.
- Project yêu cầu **Dart ^3.13.3**; môi trường đã dùng là **Flutter 3.47.4 / Dart 3.13.3**. Giữ `pubspec.lock` khi clone.
- Trong Android Studio → SDK Manager, cài SDK Platform 36, Platform-Tools, Command-line Tools và Android Emulator. Nếu log yêu cầu NDK, cài đúng phiên bản (môi trường hiện tại dùng 28.2.13676358).
- Dùng JDK kèm Android Studio; không cần cài Gradle riêng.
- Trong VS Code, cài extension **Flutter** (kèm Dart). Extension không thay thế Flutter SDK.

```powershell
git --version
flutter --version
flutter doctor -v
flutter doctor --android-licenses
```

Đọc và chấp nhận license nếu đồng ý. Sửa lỗi Android toolchain mà doctor báo. Cảnh báo thiếu Visual Studio chỉ liên quan build Windows desktop.

## 2. Tải source

```powershell
git clone https://github.com/Vinh-205/Motion.git
cd Motion
flutter pub get
code .
```

Nếu không dùng được `code .`, mở VS Code → File → Open Folder → chọn thư mục Motion. Thư mục đang mở phải chứa `pubspec.yaml`, không chỉ thư mục android.

Không sao chép `android/local.properties` từ máy khác. Flutter tạo đường dẫn SDK riêng cho máy hiện tại. Không cần npm install để chạy app vì dữ liệu icon đã được tạo sẵn.

## 3. Chạy máy ảo trong VS Code

1. Android Studio → Device Manager → tạo máy ảo, chọn image phù hợp CPU và nhấn Play. Có thể chọn Pixel 7; chờ Android khởi động xong.
2. VS Code → bấm tên thiết bị trên thanh trạng thái dưới cùng → chọn máy ảo Android. Hoặc Ctrl+Shift+P → Flutter: Select Device.
3. Mở `lib/main.dart`, nhấn F5. Build đầu cần Internet và có thể mất vài phút.
4. Sửa giao diện rồi lưu để hot reload; sau thay đổi native/plugin cần dừng phiên chạy và chạy lại.

```powershell
flutter devices
flutter run -d emulator-5554
```

Thay emulator-5554 bằng ID thực tế. Máy ảo dùng để kiểm tra giao diện; không chứng minh SMS/cuộc gọi qua SIM thật. Nếu Failed to launch, mở máy ảo bằng Device Manager hoặc Flutter: Launch Emulator → cold boot, chờ khởi động rồi chọn lại thiết bị.

## 4. Chạy điện thoại thật và thiết lập SOS

1. Dùng điện thoại Android có accelerometer và gyroscope. Môi trường hiện tại có minSdk 24 (Android 7.0 trở lên).
2. Bật Developer options → USB debugging, kết nối cáp có truyền dữ liệu và đồng ý thông báo cho phép debug.
3. Chạy `flutter devices`, rồi `flutter run -d <device-id>` với ID điện thoại; hoặc chọn điện thoại trong VS Code và nhấn F5.
4. Vào Liên hệ, thêm người nhận đã đồng ý nhận SOS. Biểu tượng điện thoại dùng để chọn một liên hệ ưu tiên cho cuộc gọi.
5. Vào Cài đặt → Thiết lập SOS qua SIM, cấu hình SIM và cấp quyền app yêu cầu. SIM cần hoạt động; SMS/cuộc gọi có thể tính phí.
6. Muốn gọi cùng đợt SMS: bật Tự gọi cùng lúc gửi SOS, đọc xác nhận và cấp quyền gọi. Chọn SIM thoại mặc định trong Android nếu có nhiều SIM. Bật tùy chọn này chưa tự bắt đầu giám sát.
7. Kiểm tra vị trí và âm lượng báo thức. Dùng Nghe thử để thử âm thanh mà không gửi SOS.
8. Mở Bắt đầu giám sát, xử lý quyền còn thiếu rồi bắt đầu. Sau đó có thể về Home; dịch vụ duy trì thông báo giám sát nền.

Khi nghi ngờ té ngã, app đếm ngược để xác nhận. Nhấn TÔI ỔN nếu an toàn. Hết thời gian mà không phản hồi, app yêu cầu gửi SMS đến danh sách đã chốt và gọi một liên hệ ưu tiên nếu đã bật; hai luồng không chờ kết quả của nhau. Âm SOS tiếp tục, có cơ chế tạm dừng khi nhận thấy chế độ âm thanh cuộc gọi. Trạng thái yêu cầu gọi không có nghĩa bên kia đã bắt máy.

Chỉ thử SOS thật với người nhận đã đồng ý; không thử gọi số khẩn cấp hoặc thả rơi điện thoại. Tự mở màn hình phụ thuộc Android. Force-stop, khởi động lại và tiết kiệm pin theo hãng có thể làm gián đoạn. Xem [SMS](docs/SOS_SMS.md) và [tự gọi](docs/AUTO_CALL.md).

## 5. Kiểm tra và build APK debug

Tại thư mục chứa pubspec.yaml:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`. Chép sang điện thoại, cho phép cài ứng dụng từ nguồn tương ứng khi Android yêu cầu rồi mở APK để cài. Đây là bản debug thử nghiệm.

Kiểm thử tích hợp nằm trong integration_test; chỉ chạy theo kịch bản dry-run đã kiểm soát. Kiểm thử tự động không thay thế xác minh SIM và giám sát dài hạn trên máy thật.

## 6. Build release

Bản clone mới không có khóa ký và mật khẩu. Chủ dự án cần khôi phục riêng đúng khóa đã dùng và cấu hình `android/key.properties` trước khi build:

```powershell
flutter build apk --release
flutter build appbundle --release
```

- APK: `build/app/outputs/flutter-apk/app-release.apk`.
- AAB: `build/app/outputs/bundle/release/app-release.aab`.
- Khóa hiện tại: `android/keystore/motion-release.jks`; cấu hình: `android/key.properties`. Hai tệp này không nằm trên GitHub.

Chỉ chạy source bằng debug thì không cần khóa release. Không tạo khóa mới để cập nhật bản release đã cài: Android yêu cầu chữ ký phù hợp. Debug và release khác chữ ký nên có thể không cài đè. Gỡ app sẽ mất dữ liệu cục bộ; cần lưu cấu hình trước khi tự thực hiện.

Xem [mức sẵn sàng phát hành](docs/RELEASE_READINESS.md). Build thành công chưa đồng nghĩa được cửa hàng duyệt.

## 7. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
| --- | --- |
| Không nhận lệnh Flutter | Kiểm tra PATH và mở terminal mới |
| Dart không tương thích | Kiểm tra flutter --version; dùng SDK đáp ứng pubspec.yaml |
| Không thấy thiết bị | Kiểm tra máy ảo/USB debugging, cáp và driver; chạy flutter devices |
| Thiếu SDK/NDK/license | Đọc log, cài đúng thành phần trong SDK Manager |
| Kotlin lỗi cache khác ổ C/D | Giữ kotlin.incremental=false trong android/gradle.properties |
| Release lỗi khóa ký | Khôi phục khóa và key.properties riêng; hoặc build debug |
| Không gửi SMS/gọi | Dùng máy thật, kiểm tra SIM/sóng/quyền, cấu hình SOS và lịch sử |
| Không cài đè bản cũ | Kiểm tra chữ ký và versionCode trước khi thay đổi dữ liệu |

## 8. Cập nhật source

```powershell
git remote -v
git pull --ff-only origin main
flutter pub get
```

Origin phải trỏ đến `https://github.com/Vinh-205/Motion.git`. Chỉ pull khi thay đổi cục bộ đã được lưu/commit phù hợp. Giữ khóa ký, mật khẩu, SDK riêng, cache và build ngoài Git.
