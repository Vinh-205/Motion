# Icon và animation morphicons trong Flutter

Toàn bộ icon do ứng dụng Flutter tự vẽ dùng dữ liệu vector Lucide và kế hoạch chuyển hình tạo bởi **morphicons 2.0.0**. Gói npm không có widget Flutter chính thức; dự án dùng lõi pure-JavaScript khi sinh mã, rồi vẽ native qua Flutter CustomPainter. Không có WebView, CDN hoặc JavaScript runtime trong APK. Icon của hộp thoại hệ thống, bàn phím và trình danh bạ do Android quản lý.

- `tool/morphicons/package.json` và `package-lock.json`: khóa morphicons 2.0.0, Lucide 1.57.0.
- `tool/morphicons/generate.mjs`: dùng `iconToCubics`, `resampleIcon`, `buildPlan`, `interpPolar`, `SPRING_PRESETS` thật của morphicons.
- `lib/generated/morphicons_data.g.dart`: 38 icon vector, 24 kế hoạch morph và preset spring; được commit để Flutter build không cần npm. Bao gồm cặp mặt trời/mặt trăng cho nút sáng/tối.
- `lib/widgets/morph_icon.dart`: dựng đường cubic chính xác khi đứng yên, nội suy polar và block transport theo dữ liệu đã sinh khi chuyển trạng thái. Có hiệu ứng vẽ nét khi xuất hiện, morph có thể đảo giữa chừng và hỗ trợ giảm chuyển động của hệ điều hành.
- `test/fixtures/morphicons_reference.json`: tọa độ tham chiếu do thư viện npm tạo, bao gồm overshoot.
- `test/morph_icon_test.dart`: đối chiếu renderer Flutter với chính đầu ra npm, kiểm tra tất cả glyph, đảo animation và giảm chuyển động.
- Android launcher/notification dùng vector từ cùng nguồn Lucide, sinh cùng lúc với dữ liệu Flutter.

## Sinh lại khi thay icon

```powershell
Set-Location tool/morphicons
npm ci --ignore-scripts
npm run generate
Set-Location ../..
flutter test test/morph_icon_test.dart
```

Thêm icon trong bảng `glyphs` của generator và enum `AppGlyph`; thêm cặp state trong `pairs` nếu cần morph. Dùng `MorphIcon(AppGlyph.play, alternate: AppGlyph.pause, active: playing)`; thay `active` sẽ chạy spring theo preset của morphicons. Nút hành động morph khi nhấn; bốn mục điều hướng có cặp hình inactive/active riêng.

Giữ `THIRD_PARTY_NOTICES.md` cùng dự án. MIT của morphicons và ISC của Lucide nằm trong file này và được đưa vào màn hình giấy phép của Flutter.

Nguồn: https://www.morphicons.com/docs · https://github.com/guillermolg00/morphicons
