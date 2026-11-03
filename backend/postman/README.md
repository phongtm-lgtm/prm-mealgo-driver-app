# Postman: đặt hàng để thử app tài xế

Import `MealGo.postman_collection.json` vào Postman (Import → Files).
Không cần environment riêng: cấu hình tại collection → Variables.
Customer và restaurant không có UI, toàn bộ thao tác thực hiện trong collection;
tài xế đăng nhập và xử lý giao hàng trên app.

## Chuẩn bị

- Backend chạy tại `http://localhost:8080` (đổi `baseUrl` nếu cần).
- Tài khoản seed local: customer `0900000003`, merchant `0900000002`,
  driver `0900000001`; mật khẩu `Mealgo123!`.
- Collection đã điền ID quán/món từ database local hiện tại. Máy khác hoặc database
  mới phải thay `restaurantId`, `menuItemId`. Chưa có API duyệt menu.
  Lấy ID bằng:

```powershell
docker compose exec -T postgres psql -U mealgo -d mealgo_db -c "select id, name, latitude, longitude from restaurants; select id, restaurant_id, name, price from menu_items;"
```

- Đổi người nhận và tọa độ giao tại Variables. Giá trị ban đầu đặt điểm giao gần
  quán để dễ thử. GPS tài xế phải ở gần điểm lấy/giao tương ứng; không bỏ qua kiểm tra GPS.
- Giả lập Pixel 7: Extended Controls → Location → đặt vị trí gần quán
  `10.7626, 106.6823`, sau đó cập nhật GPS trên app. Điện thoại thật:
  dùng tọa độ quán/điểm giao phù hợp địa điểm kiểm thử thực tế.

## Luồng thành công

1. Folder **01**: Health, Customer login, Restaurant login. Token tự lưu vào collection.
2. Trên app: đăng nhập driver → sidebar → Bắt đầu ca → cập nhật GPS.
3. Folder **02**: xem giỏ, thêm món. POST cộng số lượng; PUT thay số lượng.
   Giỏ chỉ hỗ trợ một quán. Nếu còn món quán khác, xóa giỏ thủ công ở folder 05.
4. Folder **03**: chạy lần lượt bước 1 → 2 → 3.
   - Bước 1 chụp giỏ và thông tin người nhận, tạo key mới.
   - Bước 2 tạo đơn, tự lưu `orderId`, `restaurantId`.
   - Bước 3 xóa giỏ sau thành công, không xóa nếu chưa có orderId.
5. Folder **04**: quán nhận đơn. Đợi dispatcher gửi đề nghị (thường khoảng 5 giây).
   Trên app driver: nhận đơn, đến quán.
6. Postman: gửi **Món đã sẵn sàng**. Trên app: xác nhận lấy hàng.
7. Đến điểm giao (giả lập: đổi vị trí sang `dropoffLatitude`, `dropoffLongitude`),
   cập nhật GPS, xác nhận đến khách và giao thành công/thu COD trên app.
8. Folder **05**: xem chi tiết đơn và tracking để kiểm tra kết quả.

## Lưu ý

- **Không Run toàn bộ collection**: folder 05 có thao tác hủy/từ chối/xóa giỏ.
- Đặt hàng timeout: gửi lại **bước 2** với cùng key/body, không chạy lại bước 1.
  Bước 1 luôn tạo key mới, chỉ dùng khi muốn đặt một đơn mới.
- Token hết hạn (401): đăng nhập lại đúng role. Không export/chia sẻ token thật.
- Không thay collection variables bằng environment variables trùng tên token/orderId;
  environment có thể che giá trị script vừa lưu.
- 409 có thể do quán không nhận đơn, món hết hàng, trạng thái đơn không hợp lệ
  hoặc key dùng với body khác; đọc response trước khi thử lại.
- Không có request tự bật online hay giả GPS driver trong Postman: tài xế dùng app.
- Collection dùng tài khoản/dữ liệu seed local để kiểm thử, không phải cấu hình production.
