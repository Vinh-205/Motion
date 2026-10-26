# Tài liệu hướng dẫn cài đặt

Ứng dụng **Motion — giám sát té ngã và SOS qua SIM**, phiên bản **1.0.1+3**.
Repository: [Vinh-205/Motion](https://github.com/Vinh-205/Motion).

## Tải APK để tham gia test (không cần máy tính)

Quét QR bằng điện thoại **Android** hoặc bấm **[Tải Motion 1.0.1 — APK](https://github.com/Vinh-205/Motion/releases/download/v1.0.1-test.3/Motion-1.0.1-android.apk)**. Mã QR trỏ trực tiếp đến cùng tệp APK trên GitHub Releases, không cần đăng nhập GitHub.

[![QR tải APK Motion](docs/images/motion-apk-qr.png)](https://github.com/Vinh-205/Motion/releases/download/v1.0.1-test.3/Motion-1.0.1-android.apk)

1. Tải tệp `Motion-1.0.1-android.apk` (khoảng 54 MB). Đây là bản test Android 7.0 trở lên, không dùng cho iPhone.
2. Mở tệp đã tải → nếu Android yêu cầu, cho phép **Cài ứng dụng không rõ nguồn gốc / Cho phép từ nguồn này** cho trình duyệt hoặc ứng dụng quản lý tệp đang mở APK → nhấn **Cài đặt**. Có thể tắt lại quyền cài từ nguồn này sau khi cài xong.
3. Mở Motion và làm theo **[Hướng dẫn sử dụng bên dưới](#9-hướng-dẫn-sử-dụng-sau-khi-cài-đặt)**. Người test không cần cài Flutter, Android Studio hay bật USB debugging.

Nếu đã có Motion, hãy thử cài cập nhật. Nếu báo xung đột chữ ký, có thể bản cũ là debug; ghi lại liên hệ/cấu hình trước khi quyết định gỡ bản cũ vì gỡ app sẽ xóa dữ liệu cục bộ. Không bỏ qua cảnh báo bảo mật chưa hiểu rõ; gửi ảnh lỗi cho người phát triển để kiểm tra.

Đây là bản phát hành thử dành cho nhóm dự kiến 50–100 người. Mỗi máy tự cấu hình liên hệ/SIM; không có tài khoản hay hệ thống thu thập phản hồi tự động. Không tự dùng số của người tổ chức làm người nhận SOS cho cả nhóm. Thống nhất trước với người nhận khi thử SMS hoặc cuộc gọi thật vì có thể phát sinh cước.

[Trang bản test, thông tin tệp và ghi chú phát hành](https://github.com/Vinh-205/Motion/releases/tag/v1.0.1-test.3). QR này cố định ở bản 1.0.1+3, không tự chuyển sang bản mới.

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

## 9. Hướng dẫn sử dụng sau khi cài đặt

### Bước 1 — Làm quen giao diện

App có bốn mục **Theo dõi**, **Lịch sử**, **Liên hệ**, **Cài đặt**. Nút mặt trời/mặt trăng trên thanh đầu dùng để đổi giao diện sáng/tối. Lần đầu chưa thiết lập sẽ hiện **Chưa bật SOS**; chỉ mở app chưa có nghĩa đã bắt đầu giám sát.

### Bước 2 — Thêm liên hệ khẩn cấp

Vào **Liên hệ** → thêm tên và số điện thoại hoặc chọn liên hệ từ thiết bị → lưu. Có thể thêm nhiều người (tối đa 10). Kiểm tra số và thông báo trước cho từng người nhận. Khi SOS được kích hoạt, SMS sẽ được yêu cầu gửi đến các liên hệ đã chốt cho sự kiện đó.

Chọn biểu tượng điện thoại cạnh một người để đặt **liên hệ gọi ưu tiên**. App chỉ yêu cầu gọi một người trong một sự kiện, không lần lượt gọi cả danh sách và không tự gọi lại. Các số 113/114/115 là nút mở trình gọi để người dùng chủ động thao tác, không nằm trong danh sách tự động.

### Bước 3 — Thiết lập SOS, âm thanh và thời gian xác nhận

Vào **Cài đặt → Thiết lập SOS qua SIM**, điền thông tin được yêu cầu, chọn SIM và cấp quyền SMS/vị trí theo hướng dẫn trên app. Bật vị trí của điện thoại nếu muốn đính kèm tọa độ; độ chính xác phụ thuộc tín hiệu và quyền đã cấp.

Nếu muốn gọi cùng đợt gửi tin, bật **Tự gọi cùng lúc gửi SOS**, đọc xác nhận và cấp quyền gọi. Đây là tùy chọn riêng. Kiểm tra SIM thoại mặc định trong Android. App yêu cầu loa ngoài nhưng cách xử lý còn phụ thuộc thiết bị. Người nhận cần bắt máy mới có thể trò chuyện.

Chọn thời gian xác nhận phù hợp (ví dụ 30 giây), độ nhạy và âm thanh cảnh báo. Nhấn **Nghe thử** để kiểm tra loa/âm lượng; thao tác này không gửi SMS hoặc gọi. Độ nhạy cao có thể làm tăng cảnh báo giả; không điều chỉnh theo kỳ vọng chỉ cần lắc máy là có cảnh báo.

### Bước 4 — Bắt đầu và dừng giám sát

Từ **Theo dõi**, mở **Bắt đầu giám sát**, kiểm tra các mục thiết lập và nhấn bắt đầu. Cho phép các quyền cần thiết; các quyền mở màn hình cảnh báo và cài đặt pin cần làm theo hướng dẫn riêng trên thiết bị.

Sau khi app xác nhận dịch vụ đang chạy, có thể về Home hoặc khóa màn hình. Kiểm tra thông báo giám sát còn hiện. Không force-stop app. Sau khi khởi động lại máy, mở Motion và bắt đầu lại. Muốn kết thúc phiên, quay lại app và tắt giám sát; tránh chỉ đóng giao diện rồi cho rằng đã dừng.

### Bước 5 — Xử lý khi có cảnh báo

- Nếu an toàn, nhấn **TÔI ỔN** trước khi hết đếm ngược để hủy SOS của cảnh báo đó.
- Nếu cần trợ giúp, dùng nút gửi trợ giúp ngay hoặc chờ hết thời gian. App yêu cầu gửi SMS có thông tin vị trí nếu lấy được; tùy chọn gọi ưu tiên được thực hiện trong cùng đợt.
- Âm SOS tiếp tục sau khi yêu cầu gửi tin, kể cả khi SMS lỗi. Có thể dừng âm theo điều khiển trên app/thông báo. Âm thanh có cơ chế tạm dừng khi nhận thấy chế độ cuộc gọi; âm lượng, DND và hệ điều hành vẫn ảnh hưởng kết quả.
- Muốn kết thúc cuộc gọi đã chuyển sang Android, dùng nút kết thúc trong giao diện điện thoại. Đóng cảnh báo Motion không tự cúp cuộc gọi đã thực hiện.

### Bước 6 — Kiểm tra lịch sử

Vào **Lịch sử**, chọn sự kiện để xem thời gian, lý do kích hoạt, vị trí và trạng thái từng người nhận. **Đã gửi** không đồng nghĩa người nhận đã đọc; trạng thái cuộc gọi **đã yêu cầu** không xác nhận đã kết nối hoặc bắt máy. Nếu lỗi, kiểm tra quyền, SIM, sóng và tài khoản nhà mạng trước khi chủ động thử lại.

## 10. Checklist dành cho nhóm test 50–100 người

1. Kiểm tra mở app, đổi sáng/tối, bốn tab, thêm/sửa liên hệ và nghe thử âm thanh.
2. Kiểm tra thiết lập quyền, bắt đầu giám sát, về Home, khóa/mở máy rồi quay lại app và dừng giám sát.
3. Chỉ thử SOS thật sau khi đã thống nhất với người nhận. Không dùng số cơ quan khẩn cấp để thử. Không cố ngã hay thả rơi điện thoại để kích hoạt cảm biến. Bản release không có nút mô phỏng.
4. Khi thử SOS thủ công, kiểm tra người nhận có SMS/vị trí và cuộc gọi tùy chọn hay không; kết thúc cuộc gọi và dừng âm sau phép thử. SOS thủ công không chứng minh độ chính xác phát hiện té ngã.
5. Gửi phản hồi tại **[GitHub Issues](https://github.com/Vinh-205/Motion/issues)** nếu có tài khoản, hoặc gửi trực tiếp người tổ chức qua kênh đã thống nhất. Ghi mẫu máy, phiên bản Android, phiên bản Motion, bước thao tác, kết quả mong đợi/thực tế và ảnh lỗi. Không công khai số điện thoại, vị trí GPS hay tin nhắn riêng tư; che chúng trước khi đăng ảnh.

Người dùng đã xác nhận SMS/vị trí trên điện thoại đã thử. Cuộc gọi thật, chạy nền dài hạn và độ chính xác phát hiện cần được kiểm chứng thêm trên từng thiết bị; app không bảo đảm phát hiện mọi cú ngã và không thay thế việc gọi trợ giúp chủ động khi có thể.
