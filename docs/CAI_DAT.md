# Hướng dẫn cài đặt ứng dụng Cảm biến té ngã

## Giới thiệu và chuẩn bị

Tài liệu hướng dẫn lấy mã nguồn bằng Git và cài đặt ứng dụng Cảm biến té ngã trên Windows để chạy Android Emulator. Người thực hiện cần có Internet trong lần tải SDK, thư viện và build đầu tiên.
Ứng dụng học tập đọc accelerometer và gyroscope, kiểm tra chuỗi chuyển động nghi ngờ, hiển thị cảnh báo xác nhận và SOS. Mặc định mô phỏng, không gửi ra ngoài. Tùy chọn SOS qua SIM trên Android có thể tự gửi SMS sau khi người dùng thiết lập và cấp quyền; chưa có cuộc gọi tự động. Xem [hướng dẫn SOS qua SIM](SOS_SMS.md). Không phải thiết bị y tế.
## Môi trường đã kiểm chứng
- Flutter 3.47.4 stable đi kèm Dart 3.13.3. pubspec.yaml yêu cầu Dart ^3.13.3; nên dùng cùng phiên bản Flutter để tái lập bản đã kiểm tra.
- sensors_plus 7.1.1; giữ pubspec.lock để dùng phiên bản dependency đã chốt.
- Android Gradle Plugin 9.1.0, Gradle Wrapper 9.3.1 và Kotlin 2.4.0 theo project. Không cần cài Gradle riêng.
- compileSdk 36, minSdk 24, NDK 28.2.13676358 theo Flutter SDK hiện tại. Điện thoại cần Android API 24 trở lên.
- Bản debug đã chạy trên Pixel 7 emulator API 37.2. Thiết bị thật chưa được kiểm chứng trong lần triển khai này.
## Cài công cụ
1. Cài Git for Windows từ https://git-scm.com/install/windows và mở PowerShell mới. Kiểm tra bằng git --version.
2. Lấy Flutter SDK từ https://docs.flutter.dev/install/archive. Giải nén, ví dụ D:\DevTools\flutter; thêm D:\DevTools\flutter\bin vào PATH. Không đặt SDK trong Program Files. Mở lại terminal sau khi chỉnh PATH.
3. Cài Android Studio từ https://developer.android.com/studio. Cài plugin Flutter và Dart trong Settings → Plugins; plugin không thay thế Flutter SDK.
4. Trong SDK Manager, cài Android SDK Platform 36, SDK Build-Tools, Platform-Tools, Command-line Tools và Android Emulator. Nếu Gradle yêu cầu NDK, cài đúng 28.2.13676358 trong SDK Tools → Show Package Details.
5. Dùng JDK kèm Android Studio; không tự thay JDK chỉ vì project đặt bytecode target Java 17.
```powershell
git --version
flutter --version
flutter doctor -v
flutter doctor --android-licenses
```
Đọc và chấp nhận license nếu đồng ý. Android toolchain cần được doctor nhận diện; cảnh báo Visual Studio C++ không chặn build Android. Nếu flutter chưa được nhận diện, kiểm tra PATH và mở terminal mới.


## Lấy mã nguồn và chạy ứng dụng

## Lấy mã nguồn bằng Git
Repository của nhóm: https://github.com/Vinh-205/LapTrinhDiDong. Mã nguồn Flutter nằm trên nhánh main, với pubspec.yaml ở gốc repository.
```powershell
$repoUrl = 'https://github.com/Vinh-205/LapTrinhDiDong.git'
git clone $repoUrl cam_bien_te_nga
Set-Location cam_bien_te_nga
Test-Path pubspec.yaml
flutter pub get
```
Test-Path phải trả True. Nếu repository chứa thêm một lớp thư mục, chuyển vào thư mục có pubspec.yaml trước khi chạy Flutter. Repository private cần được chủ nhóm cấp quyền đọc.
## Cấu hình riêng của máy
Không sao chép android/local.properties từ máy khác vì file này chứa đường dẫn SDK riêng. Chạy lệnh Flutter tại thư mục gốc project để công cụ tạo/cập nhật cấu hình. Nếu chưa nhận Android SDK, thay đường dẫn ví dụ bằng đường dẫn trong SDK Manager:
```powershell
flutter config --android-sdk 'D:\DevTools\Android\Sdk'
flutter doctor -v
```
Đường dẫn Flutter SDK trong Android Studio phải là thư mục SDK, không phải thư mục bin. Mở project bằng File → Open và chọn thư mục có pubspec.yaml, không chỉ mở thư mục android.
## Mở máy ảo và chạy
1. Android Studio → Device Manager → Create Virtual Device, chọn Pixel 7 hoặc thiết bị tương đương.
2. Tải system image Android API 24 trở lên phù hợp máy tính; cấu hình đã thử là Pixel 7 API 37.2 x86_64. Nhấn nút Play để khởi động và chờ vào màn hình chính.
3. Chọn máy ảo trên thanh công cụ Android Studio và Run lib/main.dart; hoặc dùng PowerShell dưới đây.
```powershell
flutter devices
flutter run -d emulator-5554
```
Thay emulator-5554 bằng ID thực trong flutter devices. Không cần máy của người cài có đúng cùng ID.
## Chạy điện thoại hoặc tạo APK
Điện thoại: bật Developer options → USB debugging, kết nối USB, chấp nhận thông báo cho phép debug và chọn thiết bị qua flutter devices. Dùng flutter run -d kèm ID điện thoại. Cảm biến dùng cùng code; máy thiếu gyroscope vẫn dùng được nút mô phỏng.
```powershell
flutter build apk --debug
```
APK nằm tại build/app/outputs/flutter-apk/app-debug.apk. Đây là bản debug thử nghiệm, không phải bản phát hành cửa hàng. Bản build mặc định chứa ARM32, ARM64 và x86_64; tránh dùng APK chỉ build android-x64 cho điện thoại ARM.


## Kiểm tra cài đặt và xử lý lỗi

## Xác nhận project hoạt động
```powershell
flutter analyze
flutter test
```
Kết quả kiểm chứng trước khi viết tài liệu: analyze không có issue, 16 kiểm thử đạt, build APK debug thành công. Đây là kết quả trên máy phát triển, không thay thế chạy kiểm tra trên máy mới.
## Kịch bản demo
1. Mở Theo dõi, bật giám sát, quan sát X/Y/Z của Accelerometer và Gyroscope. Cuộn xuống xem tổng gia tốc.
2. Nhấn MÔ PHỎNG TÉ NGÃ → cảnh báo đếm ngược → TÔI ỔN. Mở Lịch sử để thấy xác nhận an toàn.
3. Mô phỏng lần nữa → GỬI TRỢ GIÚP NGAY → thấy SOS mô phỏng và sự kiện mới trong lịch sử.
4. Cài đặt → chọn 15 giây → mô phỏng và chờ hết thời gian; SOS tự kích hoạt.
5. Liên hệ → nhập họ tên và số điện thoại → Lưu. SOS tiếp theo hiển thị liên hệ đã lưu nhưng không gửi gì ra ngoài.
6. Tắt giám sát và thử SOS thủ công. Bốn tab Theo dõi, Lịch sử, Liên hệ, Cài đặt phải chuyển đúng màn hình.
Mở Extended Controls → Virtual Sensors → Device Pose để đổi Pitch/Roll/Yaw và quan sát dữ liệu. Khi chỉ xoay rồi giữ yên, tổng gia tốc có thể vẫn gần 9,81 m/s² vì có trọng lực. Nút mô phỏng độc lập với cảm biến; không cần thả rơi điện thoại.
## Lỗi thường gặp
- Không thấy thiết bị: kiểm tra Device Manager đã chạy máy ảo, chờ Android khởi động rồi chạy flutter devices. Điện thoại cần đồng ý USB debugging và driver phù hợp.
- Dart SDK không phù hợp: kiểm tra flutter --version và where.exe flutter; dùng SDK đáp ứng Dart ^3.13.3. Đừng hạ constraint để che lỗi.
- SDK hoặc license chưa đủ: mở SDK Manager cài thành phần thiếu, chạy flutter doctor -v và flutter doctor --android-licenses.
- Kotlin báo Could not close incremental caches hoặc different roots C và D: project đã đặt kotlin.incremental=false trong android/gradle.properties. Giữ cấu hình đó. Nếu còn lỗi, đọc phần What went wrong trước khi làm sạch build.
```powershell
# Tại thư mục gốc project và sau khi dừng phiên Run
Push-Location android
.\gradlew.bat --stop
Pop-Location
flutter clean
flutter pub get
flutter build apk --debug
```
Nếu chưa có gradlew.bat sau clone, chạy flutter build apk --debug từ gốc project để Flutter khởi tạo wrapper rồi mới dùng gradlew. Không xóa toàn bộ Android SDK hoặc Pub cache để xử lý lỗi cục bộ.
- Thiếu bộ nhớ lúc build: đóng emulator thừa. Project đang đặt heap Gradle tối đa 8 GB; máy ít RAM có thể giảm Xmx8G xuống Xmx4G và MaxMetaspaceSize=4G xuống 2G trong android/gradle.properties rồi dừng daemon trước khi build lại. Không cam kết cấu hình này phù hợp mọi máy.
## Giới hạn cần trình bày
Chế độ mô phỏng chỉ giám sát khi ứng dụng ở phía trước. SOS qua SIM dùng dịch vụ Android foreground để giám sát khi khóa màn hình; buộc dừng, khởi động lại hoặc tiết kiệm pin có thể làm gián đoạn. Liên hệ và lịch sử SMS thật lưu trên Android; lịch sử mô phỏng nằm trong phiên. Xem [SOS_SMS.md](SOS_SMS.md) trước khi bật gửi thật. Thuật toán kiểm tra bất thường → va chạm → bằng chứng xoay → ít chuyển động; ngưỡng là thử nghiệm và có thể báo giả hoặc bỏ sót. Chi tiết thuật toán và ngưỡng nằm trong HUONG_DAN_DEMO.md.


## Chuẩn bị Git và bộ nộp bài

## Đưa project lên repository của nhóm
Repository đã có lịch sử trên nhánh main. Để cập nhật mã nguồn, clone vào thư mục mới thay vì git init tại project cũ rồi ép push.
```powershell
git clone https://github.com/Vinh-205/LapTrinhDiDong.git LapTrinhDiDong-nop-bai
Set-Location LapTrinhDiDong-nop-bai
```
Sao chép nội dung project từ thư mục có pubspec.yaml vào thư mục clone. Giữ nguyên thư mục .git của bản clone. Đưa lib, test, android, các thư mục nền tảng còn lại, pubspec.yaml, pubspec.lock, analysis_options.yaml, .metadata, .gitignore, README.md, HUONG_DAN_DEMO.md và docs vào repository. Đặt pubspec.yaml ngay tại gốc LapTrinhDiDong-nop-bai, không lồng thêm thư mục cam_bien_te_nga.
Không sao chép build, .dart_tool, .idea, android/local.properties, .gradle, khóa ký hoặc thông tin đăng nhập. Cập nhật README và tài liệu tương ứng khi thay đổi cách chạy ứng dụng.
```powershell
git status --short
git add .
git diff --cached --stat
git diff --cached --name-only
git commit -m 'Add fall sensor demo and installation guide'
git push origin main
```
Rà soát danh sách đã stage trước commit. Nếu Git chưa có tên/email, đặt git config user.name và git config user.email bằng thông tin thật của bạn trong bản clone. Clone đã cấu hình origin nên không cần remote add. Nếu push bị từ chối do remote vừa thay đổi, đồng bộ lịch sử trước; không force push. Đăng nhập GitHub qua phương thức xác thực Git hỗ trợ khi được yêu cầu.
## Kiểm tra người khác cài được
Sau khi push, clone vào một thư mục thử mới, chạy flutter pub get, flutter analyze, flutter test và flutter run. Dùng thử nghiệm này để phát hiện file cần thiết bị thiếu trên Git; chạy tốt ở thư mục gốc chưa chứng minh repository đầy đủ.
## Các thành phần nộp
- Link repository Git mà giảng viên có quyền xem và tải mã nguồn.
- README.md trong repository với hướng dẫn nhanh và đường dẫn tài liệu.
- Tài liệu cài đặt này; mở bản HTML trong trình duyệt, Ctrl+P → Save as PDF nếu cần bản PDF.
- HUONG_DAN_DEMO.md để giải thích tính năng, ngưỡng và hạn chế.
Slide và phần trình diễn là các yêu cầu riêng trong đề; tài liệu cài đặt không thay thế slide. Link Git đã được điền. Thông tin nhóm, lớp và thành viên cần được bổ sung theo nhóm thực tế.
## Tài liệu chính thức
Git for Windows: https://git-scm.com/install/windows
Flutter SDK archive: https://docs.flutter.dev/install/archive
Cài Flutter: https://docs.flutter.dev/install/manual
Thiết lập Android: https://docs.flutter.dev/platform-integration/android/setup
Android Studio: https://developer.android.com/studio
Cảm biến emulator: https://developer.android.com/studio/run/emulator-extended-controls
