# Tài khoản tài xế — tích hợp API

Luồng dữ liệu: `AccountPage → AccountState → AccountDataRepository → BackendRepositories → ApiClient`.
`DriverController` giữ `AccountState` dùng chung trong phiên đăng nhập và phát invalidation
sau khi hoàn tất hoặc báo thất bại chuyến giao. Mở lại trang luôn đọc dữ liệu máy chủ;
có nút làm mới, kéo để làm mới, tải thêm danh sách và hiển thị lỗi/thử lại.

- Hồ sơ: đọc hồ sơ đang đăng nhập, PUT sửa tên/điện thoại liên hệ.
- Cấu hình: GET/PUT order-settings và app-settings. Hai request lưu độc lập, không phải
  một transaction chung; nếu request thứ hai lỗi, request thứ nhất có thể đã được lưu.
- Thu nhập: DAY/WEEK/MONTH và ngày được chọn; biểu đồ lấy chart từ API, không cộng phí
  giao hàng tại frontend. Ngày mặc định và thời gian hiển thị theo giờ Việt Nam.
- Ví/giao dịch: số dư và lịch sử từ sổ tiền công, phân trang và xem chi tiết.
- Thông báo: số chưa đọc, đọc từng thông báo hoặc đọc tất cả, phân trang.
- Lịch sử: danh sách/chi tiết chuyến từ API; COD ghi là khoản phải thu, không phải tiền công.

Tiền công chưa cấu hình được ghi rõ. Không có chức năng nạp/rút/ngân hàng.
Tự động nhận đơn chỉ lưu tùy chọn; tài xế vẫn xác nhận nhận đơn thủ công.
Check-in/check-out vẫn chỉ nằm trong sidebar.

Chạy với backend local:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

Android emulator dùng `http://10.0.2.2:8080`. Điện thoại thật cần địa chỉ backend mà
thiết bị truy cập được; Docker mặc định chỉ bind localhost, cần cấu hình mạng phù hợp.

Kiểm thử: `flutter test`; build web: `flutter build web`.
Test account API sử dụng HTTP giả lập để kiểm chứng hợp đồng request/state/UI,
không thay dữ liệu thật trên database. Chưa kiểm thử tương tác bằng thiết bị Android thật.
