# SOS qua SIM trên Android

Ứng dụng có hai chế độ. Mặc định là **mô phỏng**, không gửi SMS. SOS thật chỉ bật sau khi người dùng lưu liên hệ, vào **Cài đặt → Thiết lập SOS qua SIM**, nhập tên và đồng ý bật SMS tự động.

## Chuẩn bị trên điện thoại

1. Cài APK mới; mở tab **Liên hệ → Chọn từ danh bạ** hoặc nhập thủ công, rồi bấm **Lưu liên hệ**. Android chia sẻ số do người dùng chọn, không cần quyền đọc toàn bộ danh bạ. Liên hệ lưu trong vùng riêng của ứng dụng và còn sau khi đóng/mở app.
2. Điện thoại phải có accelerometer, gyroscope và SIM đang hoạt động; chọn SIM SMS mặc định trong cài đặt Android. Máy ảo bị chặn bật SMS thật.
3. Vào **Cài đặt → Thiết lập SOS qua SIM**, nhập tên của bạn, đọc thông tin người nhận và xác nhận **Bật SMS tự động**. Chỉ lúc này app mới đề nghị quyền SMS, vị trí và thông báo. Quyền SMS là bắt buộc. Vị trí/thông báo bị từ chối không làm app giả vờ đã có quyền; trạng thái hiển thị riêng.
4. Bật công tắc **Giám sát**. Dịch vụ Android hiển thị thông báo thường trực, xử lý cảm biến và thời hạn độc lập với Flutter. Đã kiểm thử bộ đếm ngược ở chế độ không gửi trên emulator khi màn hình khóa; chưa xác thực khả năng phát hiện té ngã và gửi SMS trên điện thoại thật.

## Khi có cảnh báo

- Chuỗi cảm biến nghi ngờ mở cảnh báo, âm thanh và rung, chờ 15–30 giây. Bấm **Tôi ổn** để hủy; cũng có hành động xác nhận trong thông báo Android nếu thông báo được phép hiển thị.
- Không phản hồi: dịch vụ Android yêu cầu SIM gửi SMS. **Gửi SOS qua SIM** là hành động thủ công gửi ngay, không cần chờ bộ đếm.
- SMS nêu tên người dùng, thời điểm sự kiện, việc chưa xác nhận; nếu có vị trí gần nhất thì thêm liên kết bản đồ, thời điểm lấy vị trí và sai số. Không có vị trí vẫn gửi nội dung cảnh báo. Nội dung dùng chữ không dấu để giảm số phần SMS; nhà mạng có thể tính phí nhiều phần.
- Không có suy luận người dùng đã bất tỉnh. Không cần người dùng nói, mở trình soạn tin hay bấm gửi SMS sau khi hết giờ. Chưa có cuộc gọi đọc thông báo tự động.
- Nút **MÔ PHỎNG TÉ NGÃ** luôn mô phỏng, ngay cả khi SMS thật đang bật. Khi mô phỏng trong chế độ thật, bộ phát hiện thật tạm nghỉ để tránh trộn hai luồng; kết thúc mô phỏng sẽ khôi phục, hoặc hết tối đa 120 giây nếu giao diện không kết thúc được.

## Hiểu trạng thái gửi

Danh sách SOS hiện hỗ trợ tối đa 10 người nhận. Native lưu JSON danh sách và tự đọc lại liên hệ đơn của bản cũ. Mỗi sự kiện chụp danh sách vào `eventRecipients`; mỗi người nhận có mã dispatch riêng dạng `<eventId>:r<index>`, claim bền vững và callback từng phần tin riêng. Kết quả được gộp thành trạng thái sự kiện nhưng vẫn giữ từng người; có trạng thái hỗn hợp `partial`, không báo cả nhóm thành công khi chỉ một người nhận thành công. Lỗi SIM/quyền hoặc một số lỗi không làm vòng gửi đến người tiếp theo dừng lại. Không tự gửi lại khi chưa rõ kết quả.

Âm báo không dừng khi chuyển từ đếm ngược sang gửi SMS. Native tiếp tục phát qua luồng báo thức đến khi người dùng đóng SOS/dừng dịch vụ; mô phỏng dùng âm cục bộ và không gọi API SMS. Thông báo SOS có nút **DỪNG ÂM SOS**. Đây là âm trên điện thoại chạy Motion, không phải âm thanh nhúng trong SMS. `113/114/115` chỉ mở `ACTION_DIAL`, không cần quyền gọi trực tiếp và không được đưa vào SMS vì danh sách chỉ nhận số liên hệ 9–15 chữ số.

Integration dry-run tạm lưu hai số thử nghiệm, kích hoạt countdown, đổi cấu hình để kiểm tra danh sách đã chốt không đổi, rồi xác nhận cả hai kết quả `dryRun`. Không chạm API gửi SMS; khôi phục danh sách ban đầu trong `finally`.

- **Đang xử lý/đang yêu cầu gửi**: chưa biết kết quả.
- **SMS đã gửi đến nhà mạng**: Android xác nhận tất cả phần đã gửi; chưa biết người nhận nhận/đọc.
- **SMS được nhà mạng báo phát**: có báo phát cho tất cả phần; không chứng minh người thân đã đọc hoặc đang đến giúp.
- **Gửi SMS thất bại** hoặc **chưa xác nhận kết quả**: hiển thị đúng lỗi/thiếu phản hồi, không chuyển thành thành công và không tự gửi lặp vô hạn.

Mỗi sự kiện có mã riêng, được đánh dấu bền vững trước khi gọi API modem để không gửi trùng khi tiến trình khởi động lại. Khi không chắc lần gửi đã đi hay chưa, app ghi nhận chưa xác nhận thay vì tự gửi lại. Lịch sử thật lưu tối đa 200 sự kiện trên Android; lịch sử mô phỏng Flutter chỉ nằm trong phiên.

## Giới hạn cần kiểm tra trên thiết bị

Màn hình **Bắt đầu giám sát** là lối vào chính: thiết lập SOS, kiểm tra trạng thái, rồi **Về Home · Giữ giám sát**. Dịch vụ Android tiếp tục đọc cảm biến; Flutter chỉ dừng luồng cảm biến dùng cho giao diện. Thông báo thường trực có nút dừng dịch vụ. Nếu có cảnh báo khi đang ở một trang thiết lập hoặc lịch sử, app quay về trang cảnh báo.

Thông báo khẩn có nút **TÔI ỔN**, **MỞ CẢNH BÁO** và full-screen intent khi được cho phép. Android 14+ kiểm tra `canUseFullScreenIntent()`; người dùng có thể mở quyền đặc biệt từ màn hình giám sát. Android quyết định hiển thị toàn màn hình hoặc heads-up theo trạng thái khóa/sử dụng thiết bị. Không tự mở bằng `startActivity` từ service, không tự bỏ khóa bảo mật, không dùng quyền lớp phủ hoặc Accessibility. Nếu quyền toàn màn hình bị từ chối, vẫn đếm ngược và gửi SMS. Dry-run không mở toàn màn hình và không phát âm thanh.

Sự kiện mới lưu thêm lý do, người nhận chụp tại thời điểm cảnh báo, thời gian chờ, độ nhạy và vị trí kèm thời điểm/sai số nếu có. Trường vị trí cập nhật tại lúc chuẩn bị SMS để khớp vị trí trong nội dung tin. Các phản hồi gửi/báo phát giữ nguyên những dữ liệu này. Bản cũ thiếu dữ liệu sẽ được hiển thị là chưa lưu thông tin.

Tài liệu full-screen intent: https://developer.android.com/develop/ui/views/notifications/time-sensitive · https://source.android.com/docs/core/permissions/fsi-limits

Ứng dụng học tập, ngưỡng chưa được đánh giá y tế; có thể báo giả hoặc bỏ sót. Buộc dừng app, khởi động lại máy, thu hồi quyền, lỗi SIM/sóng, chế độ tiết kiệm pin hoặc cơ chế của hãng có thể gián đoạn dịch vụ. Sau khi mở lại, app hiển thị dịch vụ đang chạy hay cần bật lại. Không có cơ chế tự bật giám sát ngay sau khởi động máy. Việc dùng SMS qua SIM không cần máy chủ, nhưng phụ thuộc dịch vụ nhà mạng và có thể mất phí.

Trước khi phát hành qua Google Play, cần khai báo quyền SMS theo quy trình của Play; chức năng an toàn/cảnh báo có cơ chế xét ngoại lệ, không mặc nhiên được duyệt. Không xin quyền đọc SMS, lịch sử cuộc gọi hoặc toàn bộ danh bạ.

## Kiểm thử đã chuẩn bị (không gửi SMS)

```powershell
flutter analyze
flutter test
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
.\android\gradlew.bat -p android :app:testDebugUnitTest --console=plain
flutter test integration_test/device_safety_test.dart -d emulator-5554
```

Integration test chỉ chạy khi SOS thật đang tắt. Chế độ dry-run có hai lớp chặn API SMS (cờ của dịch vụ và cờ bền vững của sự kiện), không xin quyền SMS và không gửi tin. Có thể khóa màn hình trong khoảng log `MOTION_NATIVE_DRY_RUN_COUNTDOWN_STARTED` đến `MOTION_NATIVE_DRY_RUN_COMPLETED_WITHOUT_SMS`. Các điểm vào dry-run chỉ được phép ở APK debug.

Người dùng đã xác nhận SMS kèm vị trí của bản trước gửi được thật trên điện thoại đã thử. Muốn kiểm thử cuộc gọi mới cần điện thoại có SIM và người nhận đã đồng ý trước. Không thả rơi điện thoại hoặc yêu cầu ai té ngã để thử thuật toán. Các phiên kiểm thử tự động của tác nhân phát triển không gửi SMS hoặc gọi thật. Xem [tự gọi SOS](AUTO_CALL.md).

## Tài liệu Android

- Chọn một số liên hệ: https://developer.android.com/guide/components/intents-common#PickContactDat
- Dịch vụ foreground: https://developer.android.com/develop/background-work/services/fgs/service-types
- SMS và kết quả gửi: https://developer.android.com/reference/android/telephony/SmsManager
- Khai báo quyền SMS khi phát hành: https://support.google.com/googleplay/android-developer/answer/10208820
