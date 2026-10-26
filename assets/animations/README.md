# Motion startup

`motion_startup.json` được biến tấu từ **Smart TB.json** do người dùng cung cấp tại `D:/Downloads/Smart TB.json`.

- SHA-256 của file nguồn: `7efef030398d1d3043e24a4d72758149738c47771a69a2278a8031156dc4a0c8`.
- Giữ 5 lớp vector chấm tròn với quỹ đạo xoay và nhịp trễ của bản gốc.
- Bỏ precomposition, logo, chữ và toàn bộ ảnh bitmap của ứng dụng gốc.
- Chỉnh bán kính quỹ đạo, kích thước chấm, màu và khoảng phát thành 110 frame / 60 fps; file còn khoảng 6 KB.
- Flutter dùng `lottie` để phát asset ngoại tuyến, đổi màu qua `LottieDelegates`, bổ sung logo Morphicons và chữ Motion bằng widget native.
- Animation dài 1.85 giây, chỉ khi mở mới thông thường. Giám sát khởi động đồng thời. SOS, ngữ cảnh mở khẩn hoặc chế độ giảm chuyển động bỏ qua phần giới thiệu.
- Thời gian phát tính từ sau khung hình Flutter đầu tiên được rasterize. Android đưa cờ mở SOS qua initial route `/motion-alert` trước khi Dart chạy; không dùng timeout MethodChannel để quyết định bỏ qua animation.

Hai link tham khảo người dùng gửi:
https://app.lottiefiles.com/share/077eef8e-eac1-4cf5-82a6-e0f0020d1a9d
https://app.lottiefiles.com/share/c5f26bb7-5c30-4314-a49e-fb4aa0e8b91d

File JSON nguồn không có thông tin tác giả/giấy phép; tài liệu này ghi nhận nguồn do người dùng cung cấp, không gán giấy phép MIT của thư viện phát Lottie cho animation nguồn. Hai file gốc trong Downloads được giữ nguyên.
