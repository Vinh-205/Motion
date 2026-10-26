# Motion — hướng dẫn sử dụng và kiểm thử

Project hiện tại: `D:\AndroidStudioProjects\Canh_bao_te_nga\Canh_bao_te_nga`.
Ứng dụng hỗ trợ giám sát và SOS Android, không phải thiết bị y tế. Không xác định đột quỵ hoặc mất ý thức.

**Bản dùng thật 1.0.0 (build 2):** không có nút/chế độ mô phỏng trong luồng người dùng. Thiết lập liên hệ và SOS qua SIM trước khi giám sát. Chưa thiết lập thì app hiển thị **Chưa bật SOS**, không tạo SOS giả. Các thao tác mô phỏng ở phần tài liệu cũ bên dưới chỉ dành cho bộ kiểm thử kỹ thuật bật `allowSimulation`, không dùng để vận hành bản release. Xem [mức sẵn sàng và hướng dẫn cài release](docs/RELEASE_READINESS.md).

## Sử dụng cơ bản

**Bản 1.0.1 (build 3):** có tùy chọn **Tự gọi cùng lúc gửi SOS** trong thiết lập SOS qua SIM. Mặc định tắt, cần đồng ý và cấp quyền gọi. Chọn số ưu tiên bằng nút điện thoại ở Liên hệ; SMS vẫn gửi đến cả danh sách. Xem [hướng dẫn gọi SOS](docs/AUTO_CALL.md). Người dùng đã xác nhận SMS và vị trí của bản trước gửi được thật; phần gọi mới cần thử trên điện thoại có SIM.

### SOS có âm thanh và nhiều người nhận

- Sau thời gian xác nhận (mặc định 30 giây), nếu không bấm **TÔI ỔN**, Motion gửi SMS riêng đến **tất cả liên hệ đã lưu** và tiếp tục phát âm SOS trên chính điện thoại chạy app. SMS chứa chữ và vị trí nếu có; không đính kèm file âm thanh và không điều khiển âm báo trên điện thoại người nhận.
- Trong **Liên hệ**, dùng **Thêm liên hệ mới**, chọn từ danh bạ hoặc nhập tên/số rồi **Lưu**. Có thể sửa hoặc xóa từng người, tối đa 10 liên hệ. Số trùng nhau (kể cả dạng `+84` và `0` tương ứng) bị từ chối. Liên hệ cũ tự được giữ lại. Khi SOS qua SIM đang bật, phải tắt trước khi xóa người nhận cuối cùng.
- Mỗi cảnh báo chốt danh sách người nhận lúc kích hoạt; thay danh sách trong thời gian chờ không thay đổi cảnh báo đang xử lý. Trạng thái gửi/báo phát/thất bại được lưu riêng từng người trong **Lịch sử → Xem chi tiết**. Một người gửi lỗi không ngăn gửi đến những người còn lại. SMS có thể tính phí riêng theo người nhận và số phần tin.
- Âm SOS tiếp tục kể cả gửi SMS lỗi, cho đến khi bấm **Dừng âm SOS và về trang chính**, nút dừng âm trên thông báo hoặc tắt dịch vụ. Đóng cảnh báo không thu hồi các tin đã gửi hay hủy các yêu cầu gửi đã được chốt. Trong chế độ mô phỏng, âm chỉ phát khi app đang mở; không gửi SMS thật.
- Các nút **113 · Công an**, **114 · Cứu hỏa**, **115 · Cấp cứu** xuất hiện ở Liên hệ và màn hình cảnh báo. Chỉ mở trình gọi điện để người dùng xác nhận gọi; không tự gọi và không đưa vào nhóm nhận SMS. Không bấm gọi thật trong lúc thử nghiệm.

Nguồn các đầu số: https://www.quangninh.gov.vn/donvi/coto/Trang/ChiTietTinTuc.aspx?nid=3878 (các số 113/114/115 vẫn được sử dụng theo tình huống trong thời gian triển khai tích hợp đầu số).

- **Cài đặt → Âm thanh cảnh báo → Chọn âm thanh** mở danh sách âm báo thức Android. Chọn âm và xác nhận để lưu; quay lại/hủy giữ nguyên âm trước. Chọn **Mặc định** trong danh sách để dùng lại âm báo thức hệ thống. Âm đã chọn áp dụng cho cả mô phỏng và SOS thật, kể cả chạy nền.
- Nút **Nghe thử · 3 giây** chỉ phát âm/rung, không tạo sự kiện và không gửi SMS. Có thể bấm dừng sớm; rời app cũng dừng. Nếu đang có cảnh báo, nghe thử không được phép ngắt âm cảnh báo đó. Âm lượng theo mức báo thức và quy tắc Không làm phiền của điện thoại. Nếu file âm đã chọn không còn đọc được, app thử âm mặc định rồi âm dự phòng.

Để xem lại animation khởi động trong VS Code: dừng debug bằng **Shift + F5**, sau đó chạy **F5**. Hot Reload, quay về từ Home hoặc chạm biểu tượng khi app vẫn đang mở không phát lại phần giới thiệu. Sau khi thay mã Android/native cần dừng và chạy lại để cài bản mới. Animation chỉ bắt đầu sau khung hình Flutter đầu tiên được rasterize, tránh bị splash Android che trên máy ảo chậm.

- Khi mở mới thông thường, Motion phát animation Lottie quỹ đạo khoảng 1,85 giây, tự đổi màu theo giao diện và chạy ngoại tuyến. Trở lại từ Home không phát lại. Khi có SOS đang chờ, mở từ thông báo khẩn hoặc bật giảm chuyển động, app bỏ qua phần giới thiệu. Animation không biểu thị cảm biến đã sẵn sàng.

- Nút mặt trời/mặt trăng cạnh tên **MOTION** đổi giao diện sáng/tối. Mặc định sáng; lựa chọn được lưu trên Android.
- **Theo dõi → Bắt đầu giám sát nền**: thiết lập SOS qua SIM, chọn người liên hệ và cấp quyền. Khi trạng thái sẵn sàng, nhấn **Về Home · Giữ giám sát** hoặc dùng nút Home của điện thoại. Chi tiết quyền/cảm biến/pin nằm trong mục mở rộng **Kiểm tra và cài đặt thiết bị**.
- Khi nghi ngờ té ngã: dịch vụ nền phát âm thanh/rung và đếm ngược. Nếu được Android cho phép, thông báo toàn màn hình mở cảnh báo trên màn hình khóa; khi đang dùng điện thoại có thể chỉ hiện thông báo nổi. Có thể bấm **MỞ CẢNH BÁO** hoặc **TÔI ỔN** trên thông báo. SMS không phụ thuộc việc mở giao diện.
- Android 14 trở lên: trong mục kiểm tra thiết bị, mở **Cài đặt cảnh báo toàn màn hình** để xem/cấp quyền nếu hệ thống hỗ trợ. Không có quyền này vẫn có thông báo thường, đếm ngược và SMS; quyền thông báo và cài đặt của hãng vẫn ảnh hưởng việc hiển thị.
- **Lịch sử → Xem chi tiết**: xem thời điểm, nguyên nhân, kết quả, người liên hệ tại thời điểm đó và vị trí nếu đã lưu. Trạng thái SMS cập nhật khi có phản hồi của Android. Sự kiện cũ chưa lưu các trường mới sẽ hiện thông tin còn thiếu, không lấy người liên hệ/vị trí hiện tại để thay thế.
- **Dừng giám sát nền** hoặc nút dừng trong thông báo sẽ tắt dịch vụ SOS. Không buộc dừng app nếu muốn tiếp tục giám sát. Sau khi khởi động lại máy phải mở app và bật lại.

Đã có nhiều liên hệ khẩn cấp. Chưa bổ sung hẹn giờ xác nhận, hồ sơ sức khỏe hoặc ghi CSV để giữ ứng dụng cơ bản và dễ sử dụng.

## 1. Chạy ứng dụng

Mở đúng thư mục có `pubspec.yaml` trong Android Studio. Mở Device Manager, chạy Pixel 7, chọn thiết bị rồi Run `lib/main.dart`.

Trong terminal tại thư mục project:

```powershell
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Nếu `flutter` chưa có trong PATH, dùng `& 'C:\Users\tuanv\flutter\flutter\bin\flutter.bat'` thay cho `flutter`. Device ID có thể khác: lấy từ `flutter devices`.

APK debug: `build/app/outputs/flutter-apk/app-debug.apk`. Bản build mặc định có ABI ARM32, ARM64 và x86_64; bản chỉ định `--target-platform android-x64` chỉ dùng cho emulator x86_64. Đây là bản debug để học và thử nghiệm, chưa phải bản phát hành cửa hàng.

Điện thoại thật: bật Developer options và USB debugging, kết nối USB, chấp nhận quyền debug, chọn máy trong Android Studio rồi Run. Phần sensor dùng chung, không phải viết lại. Chưa kiểm chứng trên điện thoại thật trong lần triển khai này. Thiết bị thiếu gyroscope sẽ báo chờ/lỗi cảm biến; nút mô phỏng và SOS vẫn dùng được.

## 2. Test từng chức năng

| Thao tác | Kết quả mong đợi |
| --- | --- |
| Mở Theo dõi, bật giám sát | X/Y/Z của hai cảm biến cập nhật; AN TOÀN khi chưa có chuỗi nghi ngờ và có dữ liệu mới |
| Cuộn xuống | Thấy magnitude và thanh mức chuyển động |
| Tắt giám sát | Trạng thái ĐÃ TẮT GIÁM SÁT; thuật toán dừng, các số cũ có thể còn hiển thị |
| Nhấn MÔ PHỎNG TÉ NGÃ | Mở cảnh báo, phát âm báo thức và rung trên Android, đếm ngược 30 giây mặc định; không gửi SMS thật |
| Nhấn TÔI ỔN | Hủy countdown; ghi lịch sử xác nhận an toàn; không có SOS của cảnh báo đó sau này |
| Mô phỏng lần nữa, nhấn GỬI TRỢ GIÚP NGAY | SOS mô phỏng; ghi lịch sử một lần |
| Cài đặt 15 giây, mô phỏng và chờ | Khi về 0, tự chuyển sang SOS mô phỏng |
| Nhấn SOS KHẨN CẤP ở Theo dõi | SOS thủ công kể cả giám sát đang tắt |
| Liên hệ: bỏ trống hoặc nhập số không hợp lệ, Lưu | Hiển thị lỗi nhập liệu |
| Liên hệ: nhập tên và số 9–15 chữ số, có thể có + đầu số | Lưu trong phiên; SOS tiếp theo hiển thị người liên hệ đó |
| Mở Lịch sử | Sự kiện mới ở trên; có thời điểm, nguồn, kết quả và trạng thái |
| Cài đặt: đổi độ nhạy | Áp dụng ngưỡng mới và bỏ chuỗi đang kiểm tra |
| Chuyển app ra nền rồi quay lại | Dừng/khởi động lại sensor; không khẳng định giám sát khi ở nền |

Sau mỗi sự kiện đã xử lý, luồng cảm biến có khoảng nghỉ 8 giây để tránh cảnh báo lặp. Nút mô phỏng và SOS thủ công vẫn dùng ngay được.

## 3. Thử cảm biến trên Emulator

Mở dấu ba chấm **Extended Controls → Virtual Sensors → Device Pose**. Thay đổi Pitch, Roll, Yaw/Rotate/Move và quan sát X/Y/Z. Với emulator nhúng trong Android Studio, mở Extended Controls qua thanh công cụ của Running Devices; nếu không có, chạy emulator trong cửa sổ riêng.

Khi chỉ xoay máy và giữ yên, các trục gia tốc thay đổi nhưng tổng gia tốc có thể vẫn gần **9,81 m/s²**, vì raw accelerometer có trọng lực. Để thấy magnitude biến đổi cần mô phỏng chuyển động tịnh tiến; gyroscope thể hiện tốc độ xoay trong lúc xoay, không phải góc cố định. Emulator không tái tạo đầy đủ một cú té. Dùng nút mô phỏng để trình diễn cảnh báo ổn định; không thả rơi thiết bị hoặc yêu cầu người thật té.

Nguồn chính thức: [Android Emulator Extended Controls](https://developer.android.com/studio/run/emulator-extended-controls), [sensors_plus](https://pub.dev/packages/sensors_plus).

## 4. Thuật toán

### Kiểm tra âm thanh trên điện thoại thật

Tăng **âm lượng báo thức** trong cài đặt âm thanh Android, cho phép báo thức trong chế độ Không làm phiền nếu đang bật. Mở app và nhấn **MÔ PHỎNG TÉ NGÃ**: phải có âm thanh/rung trong lúc đếm ngược. Nhấn **TÔI ỔN** để dừng. Hết đếm ngược hoặc gửi trợ giúp ngay sẽ chuyển sang SOS và tiếp tục phát âm cho đến khi đóng SOS. Mô phỏng không gửi SMS thật, kể cả khi đã bật SOS qua SIM. Khi đưa app ra nền, âm mô phỏng dừng; cảnh báo thật do dịch vụ SOS nền quản lý riêng.

Âm thanh dùng luồng báo thức, không tự đổi âm lượng hệ thống hoặc bỏ qua Không làm phiền. Nếu mô phỏng có tiếng nhưng chuyển động không mở cảnh báo, cần kiểm tra chuỗi cảm biến thay vì phần loa. Không thả rơi điện thoại để thử.

Thuật toán dùng tổng `sqrt(x*x + y*y + z*z)`, không có ngưỡng X/Y/Z riêng. Ngưỡng va chạm thấp hơn làm thuật toán dễ kích hoạt hơn. Một điện thoại rơi thẳng, thiếu xoay, bị nhặt lên trước 3 giây nằm yên hoặc có đỉnh va chạm ngắn hơn chu kỳ lấy mẫu 50 ms có thể không thỏa chuỗi hiện tại. Chưa có dữ liệu ghi từ điện thoại thì không thể kết luận cần đổi ngưỡng nào.

`normal → possibleFall → impactDetected → waitingForStillness → fallSuspected`.

1. Ghi nhận giảm gia tốc, độ lệch lớn khỏi trọng lực hoặc xoay nhanh.
2. Cần mẫu va chạm đến sau mẫu bất thường trong cửa sổ 1,5 giây; một đỉnh đơn lẻ không đủ.
3. Tích phân độ lớn gyroscope để lấy bằng chứng có xoay trong chuỗi. Đây không phải góc tư thế tuyệt đối hay sensor fusion.
4. Sau va chạm, yêu cầu đủ bằng chứng xoay trong 1,5 giây, rồi ít chuyển động liên tục 3 giây.
5. Nếu hoàn tất trong 8 giây, mở cảnh báo xác nhận. Chuỗi thiếu bước, dữ liệu ngắt hoặc gyro cũ bị loại bỏ.

Ngưỡng nằm trong `lib/models/detection_config.dart`, tất cả chỉ là ngưỡng thử nghiệm:

| Độ nhạy | Độ lệch gia tốc khỏi 9,81 | Va chạm | Tích phân độ lớn gyro |
| --- | ---: | ---: | ---: |
| Thấp | > 5 m/s² | ≥ 27 m/s² | ≥ 0,90 rad |
| Trung bình (mặc định) | > 4 m/s² | ≥ 23 m/s² | ≥ 0,65 rad |
| Cao | > 3 m/s² | ≥ 20 m/s² | ≥ 0,45 rad |

Điều kiện bất thường khác: magnitude < 5 m/s² hoặc độ lớn gyro > 1,5 rad/s.
Ít chuyển động: |magnitude − 9,81| < 1,3 m/s² và gyro < 0,35 rad/s liên tục 3 giây.
Khoảng ngắt giữa các mẫu > 400 ms sẽ bỏ chuỗi. Thuật toán yêu cầu gyro mới trong 250 ms; giao diện đánh dấu dữ liệu cũ nếu thiếu cập nhật quá 2 giây. Yêu cầu sampling 50 ms (~20 Hz), tần suất thực tế do thiết bị quyết định. Đếm ngược mặc định 30 giây, có thể chọn 15/20/25/30.

## 5. Phân biệt sensor và demo; hạn chế

- SensorService đọc stream `sensors_plus` thực: trên emulator là cảm biến ảo Android cung cấp, trên điện thoại là cảm biến phần cứng.
- Nút mô phỏng chỉ chuyển trạng thái sang nghi ngờ và mở cảnh báo; không ghi đè X/Y/Z hay giả vờ rằng đã đo được té ngã.
- Luồng mặc định dùng SOS thật sau khi thiết lập và cấp quyền. Có SMS, vị trí nếu có, thông báo/dịch vụ nền và tùy chọn tự gọi một số ưu tiên khi đã bật riêng. Các phép mô phỏng/dry-run kỹ thuật không gửi SMS hoặc gọi điện. Xem [docs/SOS_SMS.md](docs/SOS_SMS.md) và [docs/AUTO_CALL.md](docs/AUTO_CALL.md).
- Hiển thị tối đa 200 sự kiện. Liên hệ và lịch sử SMS thật lưu trên Android. Lịch sử mô phỏng nằm trong phiên; hot restart sẽ mất phần này.
- Mô phỏng chỉ giám sát foreground; khi quay lại đối chiếu deadline. SOS qua SIM dùng bộ phát hiện và countdown native, đã có kiểm thử dry-run lúc khóa emulator. Chưa xác thực trên điện thoại thật, có thể bị gián đoạn do force-stop, khởi động máy hoặc tiết kiệm pin.
- “AN TOÀN” nghĩa là chưa ghi nhận chuỗi nghi ngờ, không chứng minh người dùng khỏe mạnh.
- Chưa có dữ liệu đánh giá độ chính xác/độ nhạy/độ đặc hiệu. Vị trí đặt điện thoại, nhiễu và thiết bị ảnh hưởng kết quả; có thể báo giả hoặc bỏ sót.

## 6. Sửa lỗi build

Đã tái hiện lỗi `:sensors_plus:compileDebugKotlin / Could not close incremental caches`. Log gốc có `this and base files have different roots`: Pub cache trên C: còn project trên D:.

Sửa cục bộ tại `android/gradle.properties`:

```properties
kotlin.incremental=false
```

Đã dừng Gradle daemon và build lại thành công trước khi thêm tính năng. Giữ nguyên Gradle/AGP/Kotlin và phiên bản package; không nâng cấp hàng loạt hay xóa toàn bộ Pub cache. Đổi lại, một số lần biên dịch Kotlin có thể chậm hơn vì tắt incremental. Sửa này xử lý nguyên nhân đã thấy trong project này, không bảo đảm mọi lỗi build tương lai đều hết.

Package dùng: `sensors_plus: ^7.1.1` (lock 7.1.1), Flutter SDK; `cupertino_icons` giữ từ project gốc; `flutter_test` và `flutter_lints` phục vụ kiểm tra. Không thêm package mới.

## 7. Danh sách file tạo/sửa

- `android/gradle.properties`: khắc phục Kotlin incremental khác ổ đĩa.
- `lib/main.dart`: theme, MaterialApp và màn hình chính.
- `lib/HomeScreen.dart`: export tương thích đường dẫn cũ.
- `lib/models/detection_config.dart`: ngưỡng và độ nhạy.
- `lib/models/fall_event.dart`: dữ liệu lịch sử và nhãn.
- `lib/services/sensor_service.dart`: đăng ký/hủy stream, dữ liệu và tình trạng mới/cũ.
- `lib/services/fall_detector.dart`: state machine độc lập giao diện.
- `lib/services/app_controller.dart`: phối hợp cảm biến, countdown, lịch sử, cài đặt, lifecycle.
- `lib/services/sos_service.dart`: SOS mô phỏng tách riêng.
- `lib/screens/home_screen.dart`: bốn tab, theo dõi vòng đời app.
- `lib/screens/monitor_screen.dart`: số đo, trạng thái, SOS, mô phỏng.
- `lib/screens/alert_screen.dart`: xác nhận, countdown và SOS.
- `lib/screens/history_screen.dart`: lịch sử phiên.
- `lib/screens/contact_screen.dart`: nhập và kiểm tra liên hệ.
- `lib/screens/settings_screen.dart`: giám sát, thời gian, độ nhạy.
- `lib/widgets/sensor_card.dart`: thẻ X/Y/Z dùng chung.
- `test/fall_detector_test.dart`: chuỗi đủ/thiếu bước, mẫu gián đoạn, stillness, độ nhạy.
- `test/app_controller_test.dart`: hủy, deadline, chống trùng, SOS thủ công, lifecycle, demo.
- `test/widget_test.dart`: luồng màn hình, form, tab và chữ lớn trên màn hình hẹp.
- `HUONG_DAN_DEMO.md`: tài liệu này.

Backup code trước sửa: `C:\Users\tuanv\Documents\Codex\2026-10-01\mi\work\fall-original-20261007`.

## 8. Kịch bản trình diễn ngắn

Mở app → cho xem cảm biến và magnitude → thử Device Pose → giải thích một lần rung không đủ → mô phỏng → TÔI ỔN → mô phỏng lần hai → GỬI TRỢ GIÚP NGAY → xem Lịch sử → lưu liên hệ → đổi countdown 15 giây → mô phỏng và chờ tự kích hoạt SOS.

## 9. Kết quả xác minh ngày 07/10/2026

- `flutter doctor -v`: Android toolchain và license OK; thiếu Visual Studio C++ chỉ ảnh hưởng build Windows desktop.
- `flutter pub get`: thành công, không nâng cấp package.
- `dart format lib test`: hoàn tất.
- `flutter analyze`: **No issues found**.
- `flutter test`: **16 kiểm thử thành công**.
- `flutter build apk --debug --target-platform android-x64`: thành công.
- `flutter build apk --debug`: thành công; kiểm tra APK có ARM32/ARM64/x86_64.
- Đã cài và chạy trên Pixel 7 emulator API 37.2, thao tác cảnh báo → Tôi ổn, cảnh báo → trợ giúp, xem hai kết quả trong lịch sử.
- Đã chọn countdown 15 giây trên máy ảo, chờ và quan sát SOS tự kích hoạt.
- Đã cấp dữ liệu qua cảm biến ảo Android: accelerometer (3,4,12), gyro (0.1,0.2,0.3); UI hiển thị đúng từng trục và magnitude **13.00 m/s²**.
- Đã cấp chuỗi thấp gia tốc → va chạm + xoay → yên tĩnh qua cảm biến emulator, ứng dụng tự mở cảnh báo **không cần nhấn nút mô phỏng**. Sau thử nghiệm đã trả dữ liệu cảm biến emulator về giá trị trước đó.
- Kiểm thử tự động xác minh thêm form liên hệ, cài đặt, SOS khi tắt giám sát, lifecycle và chữ lớn 150% trên màn hình 360×800.
- Chưa thử điện thoại vật lý hoặc đánh giá phát hiện té ngã ngoài thực tế.
