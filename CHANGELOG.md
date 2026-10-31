# Nhật ký thay đổi Motion

## 1.1.5+11 (31/10/2026)

Gồm toàn bộ các mục bên dưới từ 30–31/10/2026. APK `Motion-1.1.5-android.apk`: 57.586.481 byte, SHA-256 `2738ecc53515baed164bf430c368d4689e5eefa03ba33bbb7638e883666185bd`, ký cùng chứng chỉ release với 1.1.4-test.10 (SHA-256 chứng chỉ `3674ac7a…0ed0be2`) nên cài đè giữ dữ liệu. Đã kiểm tra: `flutter analyze` sạch, `flutter test` đạt, Kotlin unit test và 27 backend test đạt, cài và mở được trên máy ảo Pixel 7, kịch bản integration giám sát nền (kể cả khóa màn hình) đạt ở lần chạy lại (lần đầu trượt do không thấy thông báo SOS trên màn khóa). Chưa thử trên điện thoại thật: SMS/gọi, lắc SOS, độ nhạy cảm biến, tự bật lại sau reboot.

Ghi chú theo ngày, mới nhất ở trên. Trạng thái phát hành APK và hướng dẫn cài đặt nằm trong [README](README.md).

### Kiểm tra tổng hợp Dart (31/10/2026)

Sau khi pull và dọn README, `flutter analyze` báo không có vấn đề và `flutter test` đạt 109 test, gồm các test Dart đã sửa theo cảm biến mới, `shake_detector_test` và `cloud_account_test`. Ghi chú "chưa chạy Dart" trong các mục bên dưới là trạng thái lúc viết, nay đã được chạy. Lưu ý: test `real monitoring diagnostics at bottom render with a Material ancestor` (`test/emergency_card_test.dart:33`) cảnh báo `tap()` rơi ngoài khung 800×600 nên cú chạm có thể không trúng mục chẩn đoán; test vẫn đạt nhưng nên cuộn mục đó vào màn hình hoặc dùng `ensureVisible` để test có giá trị. Kotlin, backend và build APK chưa chạy lại.

### Giao diện đăng nhập và dashboard admin (31/10/2026)

- **Đăng nhập:** logo căn giữa; tiêu đề có hiệu ứng chữ chạy ([TypewriterText](lib/widgets/typewriter_text.dart)).
- **Dashboard admin:** thẻ hồ sơ gọn theo giao diện sáng/tối, nút tạo tài khoản đặt cạnh tiêu đề mục, ô chọn vai trò đổi thành chip kèm số lượng, thẻ tài khoản thu về một hàng (chữ cái đầu, nhãn vai trò, menu thao tác). Xem [CloudDashboardScreen](lib/screens/cloud_dashboard_screen.dart) và [RoleOverview](lib/widgets/role_overview.dart).

### Cập nhật cảm biến phản ứng nhanh (30/10/2026, sau 1.1.4+10)

Người test phản ánh cảm biến nhận ra cú ngã quá chậm. Nguyên nhân nằm ở thuật toán: sau khi ghi nhận va chạm, ứng dụng còn bắt máy nằm yên đủ 3 giây và chờ thêm tối đa 1,5 giây để thấy bằng chứng xoay, rồi mới mở cảnh báo. Tốc độ lấy mẫu vốn đã là 100 Hz và chuông báo động bật ngay khi detector kết luận, nên bản này chỉ chỉnh thuật toán, không đổi luồng SOS.

| Thông số | Trước | Sau (Thấp / Trung bình / Cao) |
| --- | --- | --- |
| Thời gian yên sau va chạm | 3 giây | 1,5 / 1 / 0,6 giây |
| Chờ bằng chứng xoay sau va chạm | 1,5 giây | 0,8 giây |
| Ngưỡng va chạm | 26 / 22 / 18 m/s² | 24 / 19 / 15 m/s² |
| Góc xoay tích lũy cần có | 0,90 / 0,65 / 0,45 rad | 0,70 / 0,50 / 0,35 rad |
| Độ lệch gia tốc để bắt đầu nghi ngờ | 5 / 4 / 3 m/s² | 4 / 3,5 / 2,5 m/s² |

Thay đổi nằm ở [FallDetector](lib/services/fall_detector.dart), [DetectionConfig](lib/models/detection_config.dart) và [NativeFallDetector](android/app/src/main/kotlin/com/example/cam_bien_te_nga/NativeFallDetector.kt); hai bản Dart và Kotlin được giữ giống nhau. Trên chuỗi dữ liệu mô phỏng 100 Hz, độ trễ từ lúc va chạm đến lúc báo động của cú ngã mạnh giảm từ khoảng 3,2 giây xuống 1,7 / 1,2 / 0,8 giây. Một số cú ngã vừa và nhẹ mà bản trước bỏ sót nay cũng được bắt, nhất là ở mức Cao. Các tình huống đời thường mô phỏng (đi bộ, chạy, ngồi phịch xuống ghế, ném điện thoại lên giường, nhảy dây, va nhẹ vào túi) không tạo báo nhầm ở cả ba mức. Đây là số liệu mô phỏng, không phải độ chính xác thực tế; ngưỡng thấp hơn đồng nghĩa dễ báo nhầm hơn trên máy thật, nên cần thử đi lại, ngồi xuống và bỏ điện thoại vào túi trước khi tin dùng. Nếu báo nhầm nhiều, tăng lại thời gian yên trong `DetectionConfig.forSensitivity` và hằng số tương ứng trong `NativeFallDetector.kt`. Thời gian đếm ngược 15–30 giây trước khi gửi SMS không đổi, vì đó là cơ hội để bấm TÔI ỔN khi báo nhầm.

**Kiểm thử đã chạy cho thay đổi này:** 15 test JUnit của detector Kotlin đạt; 27 test backend đạt. Các test Dart tương ứng (`fall_detector_test`, `gait_and_fall_test`, `detector_field_regression_test`) đã được sửa theo mốc thời gian mới nhưng **chưa được chạy lại**; hãy chạy `flutter test` trước khi phát hành. Chưa thử trên điện thoại thật.

**APK build ngày 30/10/2026 (`build/app/outputs/flutter-apk/app-release.apk`):** 57.569.961 byte, SHA-256 `c7cfc3cf776718b22226909545535cadc664b020f89c3bcd59cb4471627f114a`, vẫn mang phiên bản 1.1.4 (`versionCode=10`). Tệp này được build trên máy không có `android/key.properties`, nên nhiều khả năng đã ký bằng khoá debug: không cài đè được lên bản release chính thức (sẽ báo xung đột chữ ký) và chưa được đưa lên GitHub Releases. Liên kết và mã SHA-256 ở đầu tài liệu vẫn là của bản 1.1.4-test.10 cũ. Để phát hành bản có cảm biến mới, người giữ khoá ký cần build lại với `key.properties`, tăng phiên bản (ví dụ 1.1.5+11), tải APK lên Releases rồi cập nhật liên kết, kích thước và SHA-256 ở đầu README.

### Sửa Đăng xuất, gộp thẻ khẩn cấp, làm mới màn xem thẻ (31/10/2026)

- **Đăng xuất không hoạt động:** app gửi `POST /auth/logout` kèm `Content-Type: application/json` nhưng thân rỗng. Fastify trả 400 "Body cannot be empty…", app giữ phiên nên bấm không có tác dụng. Nút Xóa tài khoản cũng gặp đúng lỗi này. [MotionApi](lib/services/motion_api.dart) giờ chỉ khai báo JSON khi có dữ liệu gửi đi. Nếu máy chủ báo phiên đã hết hạn (401), app vẫn đăng xuất trên máy. Có 2 test mới trong `test/cloud_account_test.dart`.
- **Thẻ thông tin khẩn cấp** chỉ còn một lối vào trong **Cài đặt**; đã bỏ nút trùng trong màn tài khoản/Quản trị. Nút trên màn cảnh báo SOS vẫn giữ để người hỗ trợ mở thẻ khi khẩn cấp.
- **Màn xem thẻ** ([EmergencyCardActivity](android/app/src/main/kotlin/com/example/cam_bien_te_nga/EmergencyCardActivity.kt)) được thiết kế lại:
  - Chừa chỗ cho thanh trạng thái và lỗ camera trên Android 15+, nên tiêu đề không còn bị che.
  - Có nhãn "THẺ KHẨN CẤP", tên lớn, 3 ô Nhóm máu / Chiều cao / Cân nặng.
  - Thông tin chia thành thẻ y tế và thẻ liên hệ; mục bỏ trống ghi "Chưa cung cấp".
  - Màu theo chế độ sáng/tối của máy.
  - Vẫn chỉ đọc, chặn chụp màn hình, không có nút gọi.

### Lắc mạnh để gọi SOS (31/10/2026)

**Lắc mạnh để gọi SOS.** Đây là công tắc mới trong **Cài đặt**, mặc định tắt. Khi bật, lắc điện thoại thật mạnh qua lại khoảng 2 giây sẽ mở màn hình **ĐÃ NHẬN LẮC SOS** với chuông và đếm ngược giống khi phát hiện ngã. Không bấm TÔI ỔN thì SOS được gửi. Tin nhắn ghi rõ người dùng đã lắc điện thoại để gọi SOS, còn lịch sử ghi nguồn "Lắc mạnh gọi SOS". Tính năng chỉ hoạt động khi công tắc Phát hiện té ngã đang bật, vì cần cảm biến đang chạy.

Để tránh gửi nhầm khi chạy bộ hay nhảy, [ShakeDetector](android/app/src/main/kotlin/com/example/cam_bien_te_nga/ShakeDetector.kt) trừ trọng lực rồi chỉ đếm các cú gia tốc mạnh (từ khoảng 1,8 g) **đổi chiều qua lại trên cùng một trục**. Cần 6 cú như vậy trong 2 giây. Chạy bộ, nhảy hay té ngã chỉ tạo đỉnh mạnh một chiều nên không kích hoạt. Sau mỗi lần kích hoạt có 10 giây nghỉ. Bản Dart [shake_detector.dart](lib/services/shake_detector.dart) dùng cho chế độ mô phỏng.

**Giao diện:** bố cục gọn kiểu màn Quản trị Motion đã được thử rồi khôi phục về giao diện cũ theo yêu cầu. Công tắc **Lắc mạnh để gọi SOS** nằm trong Cài đặt, ngay dưới **Giám sát khi rời app**.

**Kiểm thử:** 7 test JUnit mới cho ShakeDetector đạt. Lắc mạnh thì kích hoạt trong vòng 2 giây và tôn trọng 10 giây nghỉ. Lắc nhẹ, chạy, nhảy dây, đi bộ hay rơi rồi nảy thì không kích hoạt. Test Dart tương ứng nằm ở `test/shake_detector_test.dart`. `test/widget_test.dart` đã được cập nhật theo ngưỡng mức Cao mới (15 m/s²). Phần giao diện và Dart chưa được biên dịch ở môi trường sửa; hãy chạy `flutter analyze` và `flutter test` trước khi build.

### Sửa lỗi thả rơi báo chậm hoặc không báo (31/10/2026)

Khi thử thật, thả điện thoại rơi thì 5–10 giây sau mới có cảnh báo, có lúc không báo. Nguyên nhân là **cú nảy sau khi chạm sàn**. Điện thoại thường nảy lên 1–3 lần. Detector cũ coi mọi va chạm mạnh xảy ra hơn 300 ms sau cú chạm đầu là "va chạm lặp lại", giống khi đang đi hay nhảy, nên huỷ luôn cú ngã thật. Các cú nảy sau đó lại bị loại vì không có pha rơi. Kết quả là phải chờ một chuỗi tình cờ khác, hoặc không bao giờ báo.

Đã sửa ở cả [NativeFallDetector](android/app/src/main/kotlin/com/example/cam_bien_te_nga/NativeFallDetector.kt) và [FallDetector](lib/services/fall_detector.dart):

- Trong 1,5 giây sau cú chạm đầu, các va chạm **yếu hơn rõ rệt** (dưới 85% cú đầu, tối đa 3 lần) được coi là nảy hoặc lăn của cùng một cú ngã, không huỷ chuỗi.
- Để rung lắc mạnh hay nhảy dây không bị coi là "nảy", một va chạm chỉ được tính là cú ngã khi nó **nổi bật hẳn**. Nếu 2 giây trước đó đã có từ 2 đỉnh mạnh tương đương trở lên (đang lắc, nhảy, chạy), nó bị loại. Cú ngã khi đang chạy vẫn được tính vì va chạm mạnh hơn hẳn các bước chạy.

| Mô phỏng 100 Hz | Trước (Thấp / TB / Cao) | Sau (Thấp / TB / Cao) |
| --- | --- | --- |
| Rơi lên nệm, 1 lần chạm | 1,9 / 1,4 / 1,0 s | 1,9 / 1,4 / 1,0 s |
| Rơi sàn, nảy 1 lần | không báo / không báo / 1,4 s | 2,3 / 1,8 / 1,4 s |
| Rơi sàn, nảy 2 lần | không báo cả 3 mức | 2,6 / 2,1 / 1,7 s |
| Rơi sàn, nảy 3 lần | không báo / không báo / 2,0 s | 2,9 / 2,4 / 2,0 s |
| Đang chạy thì ngã | — | 2,3 / 1,8 / 1,4 s |

Các trường hợp không phải ngã đều không báo ở cả ba mức: đi bộ rồi chạy rồi đứng yên, nhảy dây 20 giây, lắc mạnh 3 giây rồi đặt lên bàn hoặc cầm trên tay, ngồi phịch xuống ghế, đặt mạnh điện thoại xuống bàn. **Rung lắc mạnh được cố ý không coi là té ngã.** Muốn gửi SOS khi gặp nguy mà không ngã, dùng nút SOS thủ công.

**Kiểm thử:** 20 test JUnit Kotlin đạt, gồm 2 test mới cho "rơi rồi nảy vẫn báo" và "lắc mạnh rồi đặt xuống không báo". Hai test này đều trượt trên code cũ. Test Dart tương ứng đã được thêm vào `test/fall_detector_test.dart` nhưng chưa chạy được ở môi trường sửa; hãy chạy `flutter test`. Số liệu trên là mô phỏng, cần thử lại trên điện thoại thật.

### Sửa chế độ giám sát nền (31/10/2026)

Chế độ nền có thể tự tắt mà người dùng không hay biết. Khi điện thoại (nhất là Xiaomi, Oppo, Samsung) giết app đang chạy nền hoặc người dùng vuốt app khỏi danh sách đa nhiệm, Android tự khởi động lại dịch vụ giám sát. Lúc đó app không hiển thị, nhưng code vẫn xin chạy nền với loại "vị trí". Từ Android 14 (app đang build cho Android 16), hệ thống từ chối yêu cầu này. Code bắt lỗi rồi tắt hẳn SOS, nên thông báo biến mất và cảm biến ngừng chạy.

Đã sửa trong [SafetyService](android/app/src/main/kotlin/com/example/cam_bien_te_nga/SafetyService.kt):

- Khi dịch vụ được khởi động lúc app ở nền, nó chạy với loại "health" để cảm biến tiếp tục giám sát. Khi người dùng mở lại app thì mới bổ sung loại "vị trí". Nếu không xin được vị trí, dịch vụ vẫn chạy thay vì tắt SOS.
- Thêm [BootReceiver](android/app/src/main/kotlin/com/example/cam_bien_te_nga/BootReceiver.kt): sau khi khởi động lại điện thoại hoặc cài bản cập nhật, giám sát nền tự bật lại. Điều này chỉ xảy ra khi trước đó người dùng đã bật SOS thật và giám sát nền ([MonitoringPolicy](android/app/src/main/kotlin/com/example/cam_bien_te_nga/MonitoringPolicy.kt)).
- Màn **Bắt đầu giám sát** có thêm nút **CHO PHÉP CHẠY NỀN KHÔNG GIỚI HẠN PIN**. Nút này mở thẳng hộp thoại của Android; máy nào không có hộp thoại đó thì mở trang cài đặt pin.

Vị trí trong SMS vẫn lấy từ lần đọc gần nhất. Nếu dịch vụ khởi động lại khi app ở nền, phải mở app một lần thì vị trí mới được cập nhật liên tục trở lại. Một số hãng còn có cài đặt "tự khởi chạy" hoặc "khoá app trong đa nhiệm" riêng, cần bật tay.

**Kiểm thử:** 18 test JUnit thuần Kotlin đạt, gồm test mới cho điều kiện tự bật lại sau khi khởi động máy. Phần mã dùng API Android (`SafetyService`, `BootReceiver`, `MainActivity`) và giao diện Dart chưa được biên dịch trong môi trường sửa. Cần build lại APK, rồi thử trên máy thật: bật giám sát nền, vuốt app khỏi đa nhiệm, khoá màn hình vài phút, khởi động lại máy, và xem thông báo Motion còn hiện hay không.

### Tổng hợp thay đổi đã có trong source và APK 1.1.4+10

| Nhóm | Nội dung đã thực hiện | Mã nguồn / hướng dẫn |
| --- | --- | --- |
| Đăng ký, đăng nhập, quên mật khẩu | Email + mật khẩu + Email OTP; Google OAuth2/OIDC với PKCE và liên kết tài khoản tường minh; Google thật còn cần cấu hình provider | [MotionApi](lib/services/motion_api.dart), [backend auth](backend/src/app.js), phần tài khoản bên dưới |
| Ghi nhớ đăng nhập | Khôi phục token/cache hồ sơ từ secure storage, không nháy màn đăng nhập khi đang khôi phục; phiên mới tối đa 30 ngày; xử lý offline và xóa khi API trả 401 | [SessionGate](lib/screens/session_gate.dart), [test khôi phục phiên](test/emergency_card_test.dart) |
| Vai trò và CRUD | Admin quản lý tài khoản, khóa/mở khóa, phân quyền/phân công; nhân viên chỉ thấy người được giao; backend kiểm tra quyền/chủ sở hữu, bảo vệ admin cuối cùng | [Dashboard](lib/screens/cloud_dashboard_screen.dart), [API + kiểm thử](backend/test/api.test.js) |
| Dọn giao diện quản trị | Bỏ nút lịch hẹn/liên hệ trên tài khoản và Vòng an toàn khỏi giao diện; tìm kiếm tên/email, ô lọc vai trò gọn | [CloudDashboardScreen](lib/screens/cloud_dashboard_screen.dart) |
| Thẻ khẩn cấp | Thêm/xem/sửa/xóa tên, bệnh nền, dị ứng, thuốc, nhóm máu tự khai, chiều cao/cân nặng và liên hệ; một thẻ cho người mang điện thoại, không tự đổi theo tài khoản | [Form thẻ](lib/screens/emergency_card_screen.dart) |
| Thẻ ngoại tuyến và màn hình khóa | Mã hóa AES-GCM/Keystore, không gửi thông tin thẻ lên API; mặc định tắt chia sẻ; đọc qua thông báo SOS khi đã đồng ý và SOS đang hoạt động; Activity riêng không mở sang tài khoản | [Lưu mã hóa](android/app/src/main/kotlin/com/example/cam_bien_te_nga/EmergencyCardStore.kt), [màn hình chỉ đọc](android/app/src/main/kotlin/com/example/cam_bien_te_nga/EmergencyCardActivity.kt) |
| Bố cục ứng dụng | Tài khoản ở Cài đặt, sáng/tối trên cùng bên phải; nhãn SOS cập nhật theo trạng thái; bắt đầu giám sát nền chỉ ở Theo dõi; logo thống nhất, thanh điều hướng kính mờ, Morphicons/Lottie | [Header](lib/widgets/motion_header.dart), [navigation](lib/widgets/liquid_navigation.dart), [startup](lib/widgets/startup_animation.dart) |
| Cảm biến | Xử lý va chạm ngay mẫu đầu; ngưỡng Thấp/Vừa/Cao 24/19/15 m/s², có thích nghi theo dao động; kiểm tra giảm gia tốc/xoay/ít chuyển động, loại va chạm lặp và dữ liệu cũ; đồng bộ Dart/Android | [FallDetector](lib/services/fall_detector.dart), [NativeFallDetector](android/app/src/main/kotlin/com/example/cam_bien_te_nga/NativeFallDetector.kt) |
| Giám sát nền và SOS | Công tắc phát hiện và nền tách riêng; native foreground service xử lý cảm biến/đếm ngược/chuông, SMS nhiều liên hệ và cuộc gọi một số ưu tiên; quyền SMS/gọi/thông báo và kiểm tra full-screen/pin | [SafetyService](android/app/src/main/kotlin/com/example/cam_bien_te_nga/SafetyService.kt), hướng dẫn sử dụng bên dưới |
| Âm thanh, liên hệ, lịch sử | Chuông SOS Motion mặc định, chọn/nghe thử âm; nhập/chọn danh bạ, nhiều người nhận, số gọi ưu tiên; nút 113/114/115 mở trình quay số; lưu trạng thái SMS/gọi và nguyên nhân kích hoạt riêng | [Các màn hình](lib/screens), [Emergency services](lib/widgets/emergency_services.dart) |
| Sửa vùng xám Theo dõi | Tách PageStorageKey của chẩn đoán khỏi vị trí cuộn, thêm Material cho ExpansionTile; có regression test cuộn/mở mục cuối trang | [MonitorScreen](lib/screens/monitor_screen.dart), [test](test/emergency_card_test.dart) |
| API và tài liệu | API HTTPS trên Render, Neon lưu tài khoản, Resend gửi OTP, DNS Cloudflare; Swagger/Schemas, README cài đặt/sử dụng/nơi lưu dữ liệu và Mermaid đồng bộ source | [Swagger](https://motion-api.vihx.online/docs), [OpenAPI trong repo](backend/openapi/motion.openapi.json), [Mermaid](docs/diagrams) |

**Đã kiểm chứng:** 101 Flutter tests, 22 Android unit tests, 27 backend tests, 23 PostgreSQL-compatible tests; integration máy ảo xác nhận đếm ngược chạy nền khi khóa, mở thẻ bằng thông báo và dữ liệu thẻ lưu mã hóa. SMS/gọi trong integration là dry-run. Chưa công bố độ chính xác phát hiện ngã thực tế; cần thử lại SMS/cuộc gọi/cảm biến, pin và khóa màn hình trên điện thoại đích. Google OAuth thật chưa được xác nhận. APK này là bản test, không phải bản đã phát hành lên Play Store/App Store.

### Theo dõi 1.1.4: sửa vùng xám

mục chẩn đoán có `Material` riêng và `PageStorageKey` riêng; không đọc nhầm số vị trí cuộn thành trạng thái bool của ExpansionTile. Đã thêm kiểm thử cuộn xuống/mở chẩn đoán.
