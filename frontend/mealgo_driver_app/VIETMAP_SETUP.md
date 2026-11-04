# Vietmap setup (Android Emulator & Local development)

Ứng dụng tài xế sử dụng 2 build-time variables từ Vietmap:
- `VIETMAP_TILEMAP_KEY`: Key hiển thị bản đồ nền (vector style map).
- `VIETMAP_ROUTE_KEY`: Key tính toán tuyến đường (routing) xe máy.

---

## 1. Chạy trên Android Emulator

Đảm bảo:
1. Docker backend đang chạy (`mealgo-backend-1` cổng 8080).
2. Android Emulator đang bật (`emulator-5554`).

Từ thư mục `frontend/mealgo_driver_app`, chạy PowerShell:

```powershell
flutter run -d emulator-5554 `
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 `
  --dart-define=VIETMAP_TILEMAP_KEY=YOUR_TILEMAP_KEY `
  --dart-define=VIETMAP_ROUTE_KEY=YOUR_ROUTE_KEY
```

> **Lưu ý:** Thay `YOUR_TILEMAP_KEY` và `YOUR_ROUTE_KEY` bằng 2 key thực tế của bạn.

---

## 2. Lưu ý vị trí GPS trên Android Emulator

Mặc định, Android Emulator thường giả lập vị trí tại California (Mỹ).
Vì Vietmap chỉ hỗ trợ routing và dữ liệu bản đồ tại **Việt Nam**, đồng thời backend kiểm tra vị trí tài xế phải cách quán/khách `<= 200m`, bạn cần đặt tọa độ GPS của emulator về khu vực quán/khách tại TP. Hồ Chí Minh.

### Cách 1: Qua giao diện Emulator
- Nhấn vào biểu tượng **`...`** (Extended controls) trên thanh công cụ của Emulator.
- Chọn mục **Location**.
- Nhập toạ độ demo của quán:
  - **Latitude**: `10.7626`
  - **Longitude**: `106.6823`
- Nhấn **Save Point** hoặc **Send**.

### Cách 2: Bằng lệnh PowerShell qua ADB
```powershell
& "D:\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 emu geo fix 106.6823 10.7626
```
*(Cú pháp `emu geo fix <longitude> <latitude>`)*

---

## 3. Các tính năng Vietmap đã hoàn thiện trên App
1. **Bản đồ vector Vietmap (`VietmapGL`)**: Hiển thị mượt mà với style chính thức từ Vietmap.
2. **Marker Widget chuẩn Flutter**:
   - Vị trí tài xế (icon xe máy nổi bật với hiệu ứng viền/bóng).
   - Điểm lấy hàng Quán ăn (icon cửa hàng kèm tên quán).
   - Điểm giao hàng Khách hàng (icon vị trí kèm tên người nhận).
3. **Vẽ tuyến đường xe máy (Polyline)**: Tự động vẽ lộ trình thực tế đường bộ từ vị trí tài xế đến quán hoặc đến khách.
4. **Auto-fit Camera Bounds**: Tự động căn chỉnh và zoom bản đồ bao quát toàn bộ lộ trình di chuyển.
5. **Thẻ thông tin hành trình**: Hiển thị khoảng cách (`km`) và thời gian dự kiến (`phút`) ngay góc trên bản đồ.
6. **Nút định vị & Theo dõi vị trí**: Nút FAB góc dưới cho phép bật chế độ theo dõi (follow) vị trí tài xế khi di chuyển.
