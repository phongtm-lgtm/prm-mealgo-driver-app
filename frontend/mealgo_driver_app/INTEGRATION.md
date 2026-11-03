# Tích hợp giao diện gốc

Source UI được copy từ `D:\my-project\MSS\group-project\frontend\mealgo_driver_app`; không sửa source tại đường dẫn gốc.

## Chạy web

```powershell
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5173 --dart-define=API_BASE_URL=http://localhost:8080
```

Đăng nhập `0900000001` (hoặc `+84900000001`) / `Mealgo123!`. Backend demo cần đang chạy trên cổng 8080. Token lưu bằng flutter_secure_storage trên mobile; lưu trữ web không có mức bảo vệ tương đương Keychain/Keystore. Phiên hết hạn yêu cầu đăng nhập lại, chưa có refresh token.

`AppDependencies.backend` sử dụng adapter trong `lib/app/backend_repositories.dart` để giữ cấu trúc và các màn hình gốc. Mock repositories chỉ dùng khi được inject rõ ràng (ví dụ widget tests).

Đã nối: JWT, khôi phục phiên, online/offline, offer dành cho tài xế, nhận offer, khôi phục chuyến, 4 thao tác giao hàng, GPS thật, báo thất bại bằng ảnh thật, lịch sử (100 chuyến gần nhất). Backend chưa có free-pick công khai: danh sách FREE-PICK hiển thị offer được phân cho tài xế hiện tại, không phải mọi đơn hệ thống.

## Giới hạn giữ từ prototype

- Bản đồ vẫn là minh họa; không hiển thị vị trí GPS thật trên map. Nút vị trí gửi GPS thật lên máy chủ. Cần quyền vị trí, accuracy ≤50m, cách điểm xác nhận ≤200m. Tracking chỉ chạy khi app/tab hoạt động.
- Ví, thu nhập, đánh giá và thông tin xe chưa có API. Adapter trả 0/rỗng, KHÔNG phải xác nhận số dư/thu nhập thực. Phí giao hàng của khách không được tự coi là thu nhập tài xế.
- Settings chỉ lưu trong bộ nhớ phiên, không đồng bộ backend; không có auto-accept hay khóa tài xế thật. Nút mô phỏng offer không tạo dữ liệu ở chế độ backend.
- Vào ca dùng camera thật (package camera): nhấn mở camera để xin quyền, xem trước, chụp và xác nhận gửi ảnh qua API face-verification trước khi bật online. Từ chối quyền/hủy/lỗi API không bật online. Không thu âm; camera dừng sau khi chụp, rời màn hình hoặc app inactive. Backend luôn trả success cho file không rỗng, KHÔNG xác thực danh tính thật, không lưu ảnh. Web cần localhost/127.0.0.1 hoặc HTTPS; nếu đã từ chối quyền thì bật lại Camera trong cài đặt trang. Android có khai báo CAMERA; repo chưa có project iOS. Chức năng gọi/chat vẫn là thông báo minh họa, chưa thực hiện liên hệ.
- Backend không hỗ trợ hủy sau khi nhận: thao tác này báo lỗi và giữ nguyên chuyến.
- Backend không cung cấp đủ chi tiết món/COD trong offer: chi tiết đầy đủ chỉ có sau khi nhận chuyến.
- Tài khoản chưa có hồ sơ cần đăng ký hồ sơ qua backend; UI hiện dùng tài xế đã có hồ sơ. Chưa bổ sung UI chỉnh sửa hồ sơ/đăng xuất vào thiết kế gốc.
- Chỉ xác minh bản web; chưa xác minh Android/iOS.

Thư mục backup trước khi thay UI: `D:\prm\mealgo\frontend\mealgo_driver_backup_20261102_170953`.
