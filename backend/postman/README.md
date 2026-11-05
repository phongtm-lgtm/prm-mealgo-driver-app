# Postman: đặt hàng để thử app tài xế

Import `MealGo.postman_collection.json`. Để thử hai khách đặt đơn, import thêm
`MealGo-demo-local.postman_environment.json` và chọn **MealGo local — Hai khách, bốn món** ở góc trên của Postman.

## Hai khách đặt đơn để thử Free-Pick

1. Bật seed local (`APP_SEED_ENABLED=true`). Trong folder **06**, chạy hai request đăng nhập Customer A (`0900000003`) và Customer B (`0900000005`) để lưu riêng `token_customer_a` và `token_customer_b` vào environment đang chọn. Tiếp theo, chạy request đọc menu để lấy ID thực tế và giá của các món từ backend. Muốn tạo nhanh cả hai đơn theo mẫu mặc định, chạy nguyên folder **06** một lần rồi sang bước 4.
2. Bấm **Thêm món kế tiếp** nhiều lần để thêm vào giỏ của khách trong biến `demo_customer` (`a` hoặc `b`). A bắt đầu ở món 1, B bắt đầu ở món 3. Mỗi lần thành công chuyển sang món kế tiếp, sau món 4 quay lại món 1. Bộ đếm và giỏ tách riêng cho hai khách.
3. **Chuẩn bị** rồi **Đặt đơn** cho từng khách. Mặc định `demo_dishes_a=1,2` và `demo_dishes_b=3,4`. Đổi sang một danh sách như `2,4`, `random` để chọn hai món khác nhau, hoặc `cart` để dùng số lượng và ghi chú trong giỏ thực tế của khách đó. Mỗi lần **Chuẩn bị** tạo một body và khóa đặt đơn mới. Khi gửi **Đặt đơn** bị timeout, gửi lại chính request đó với cùng khóa. Xem JSON đã chuẩn bị ở `demo_order_body_a` và `demo_order_body_b`, kết quả ở `demo_order_id_a` và `demo_order_id_b`.
4. Chạy folder **07** để quán nhận hai đơn. Tài xế vào ca trên app rồi bấm ↻ khi thấy đơn đầu tiên. Đơn thứ hai xuất hiện nếu còn phù hợp và chưa được mời cho tài xế khác.
5. Folder **08** dùng riêng theo từng trường hợp. Thử khách hủy sau bước đặt và trước bước quán nhận. Thử quán hủy khi đơn đang chuẩn bị. Để thử báo khách không nghe máy, chạy **Đọc chuyến hiện tại**, sau đó chọn một trong hai request theo trạng thái.
   - **Trước READY, chưa lấy hàng** — gửi `/incident` với `reason=CUSTOMER_UNREACHABLE` và chọn ảnh JPEG/PNG của nhật ký cuộc gọi trong `Body → image`. Response `PENDING_REASSIGNMENT` xác nhận chuyến đã quay lại hàng chờ tìm tài xế khác.
   - **Đã đến điểm giao (AT_DROPOFF)** — gửi `/failure-report` với cùng lý do và bằng chứng cuộc gọi để báo giao thất bại. Khi gửi lại sau timeout, giữ nguyên `requestId`, nội dung và ảnh của báo cáo đó.

| Món trong biến chọn | Tên ở menu demo | Giá seed | Tùy chọn đi kèm gửi ở `items[].note` |
| --- | --- | ---: | --- |
| 1 | Com ga (Cơm gà) | 45.000 đ | Cơm ít, kèm dưa leo, sốt gừng để riêng |
| 2 | Bún bò Huế | 55.000 đ | Ít cay, kèm hành và rau thơm |
| 3 | Bánh mì thịt | 30.000 đ | Thêm dưa leo và đồ chua, không ớt |
| 4 | Trà sữa trân châu | 35.000 đ | 50% đường, ít đá, kèm trân châu đen |

Các tùy chọn trong mẫu đã gồm trong giá món. Backend tính tiền từ menu hiện tại. Đơn mẫu A gồm một Cơm gà và một Bún bò Huế (100.000 đ tiền món). Đơn mẫu B gồm một Bánh mì thịt và một Trà sữa trân châu (65.000 đ tiền món). Phí giao tính riêng.

## Chuẩn bị cho luồng một khách (folder 01–05)

- Backend chạy tại `http://localhost:8080` (đổi `baseUrl` nếu cần).
- Tài khoản seed local: customer `0900000003`, merchant `0900000002`,
  driver `0900000001`; mật khẩu `Mealgo123!`.
- Folder 01–05 dùng collection variables `restaurantId`, `menuItemId`. Máy khác hoặc database
  mới có thể lấy ID từ request đọc menu trong folder 06 hoặc bằng SQL:

```powershell
docker compose exec -T postgres psql -U mealgo -d mealgo_db -c "select id, name, latitude, longitude from restaurants; select id, restaurant_id, name, price from menu_items;"
```

- Đổi người nhận và tọa độ giao tại Variables. Giá trị ban đầu đặt điểm giao gần
  quán để dễ thử. GPS tài xế phải ở gần điểm lấy/giao tương ứng; không bỏ qua kiểm tra GPS.
- Giả lập Pixel 7: Extended Controls → Location → đặt vị trí gần quán
  `21.038214, 105.547018`, sau đó cập nhật GPS trên app. Điện thoại thật:
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
- Collection dùng tài khoản/dữ liệu seed local để kiểm thử, không phải cấu hình production.

---

## Kiểm thử tự động: Tài xế ấn Reload (↻) để đổi đơn mới (`MealGo-Driver-Reload-Offers`)

Collection `MealGo-Driver-Reload-Offers.postman_collection.json` mô phỏng đầy đủ kịch bản:
- Tạo sẵn 3 đơn hàng pending từ khách và quán xác nhận để đưa vào hàng chờ `PENDING_ASSIGNMENT`.
- Tài xế online và nhận đơn đề xuất #1.
- Tài xế không muốn nhận đơn đang hiển thị nên bấm nút Reload (↻) -> Gửi `POST /api/v1/drivers/me/offers/refresh` với `skippedAssignmentIds = [offer1_assignmentId]`.
- Hệ thống đánh dấu `REJECTED` cho đơn 1 và tự động đề xuất đơn #2.
- Tài xế tiếp tục Reload lần 2 -> Đơn 2 chuyển `REJECTED` và hệ thống đề xuất đơn #3.
- Tài xế ưng ý và bấm nhận đơn #3 (`ACCEPT`) -> Bắt đầu chuyến đi giao hàng.

### Cách chạy:
1. **Chạy bằng Postman Runner**: Import file `MealGo-Driver-Reload-Offers.postman_collection.json` -> Bấm **Run collection** (tất cả các test assertion đều tự động pass 100%).
2. **Chạy 1 lệnh tự động bằng batch file (Newman CLI)**:
   ```cmd
   .\run-driver-reload-test.bat
   ```
   hoặc:
   ```cmd
   npx --yes newman run backend/postman/MealGo-Driver-Reload-Offers.postman_collection.json --env-var "baseUrl=http://localhost:8080"
   ```
3. **Chạy 1 lệnh tự động bằng PowerShell**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File backend/scripts/test-driver-reload-flow.ps1
   ```

