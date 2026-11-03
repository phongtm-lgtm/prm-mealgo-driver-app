# API tài khoản tài xế

Prefix `http://localhost:8080/api/v1`. Tất cả endpoint yêu cầu Bearer JWT role DRIVER,
hồ sơ tài xế tồn tại. ID tài xế lấy từ token, không từ body. Trả 401 nếu thiếu token,
403 nếu sai role, 404 nếu tài nguyên không thuộc tài xế hiện tại.

## Hồ sơ (đã có)

- `GET /drivers/me`
- `PUT /drivers/me/profile`: `{ "fullName": "Nguyễn Văn A", "phoneNumber": "0901234567" }`

Điện thoại liên hệ không đổi số đăng nhập.

## Cấu hình nhận đơn

`GET /drivers/me/order-settings`, `PUT /drivers/me/order-settings`:

```json
{
  "autoAcceptEnabled": false,
  "maxDeliveryDistanceKm": 5,
  "maxItemQuantity": 10,
  "maxRestaurantAdvanceAmount": 200000
}
```

PUT thay toàn bộ cấu hình; số km 0.1–100, tổng số phần ăn 1–5000, tiền ứng 0–100.000.000 VND.
Khoảng cách dùng để lọc là đường chim bay từ quán đến khách, không phải tài xế đến quán.
Dispatcher áp dụng khoảng cách và tổng số phần. Luồng COD hiện không ứng tiền quán (0 VND),
nên luôn thỏa giới hạn tiền ứng không âm.
`autoAcceptEnabled` hiện chỉ lưu tùy chọn để bàn giao; KHÔNG tự nhận đơn, vẫn phải accept offer.
Chưa chốt chính sách tự chấp nhận đơn nên không thay đổi cơ chế nhận đơn hiện tại.
Mặc định khi chưa cấu hình: 100 km, 5000 phần, 0 tiền ứng, autoAccept=false.

## Cài đặt ứng dụng

`GET /drivers/me/app-settings`, `PUT /drivers/me/app-settings`:

```json
{"inAppNotificationsEnabled": true}
```

Lưu database. Tắt sẽ ngừng tạo thông báo hoàn tất giao hàng mới, không xóa thông báo cũ.
Không thay đổi quyền camera/GPS/notification Android, không đăng ký push notification.

## Thu nhập

`GET /drivers/me/earnings?period=DAY&date=2026-11-03`

- period: DAY, WEEK, MONTH; mặc định DAY.
- date: ISO yyyy-MM-dd; mặc định hôm nay theo Asia/Ho_Chi_Minh.
- Tuần bắt đầu thứ Hai. Khoảng ngày trả về là bao gồm hai đầu.
- Response: period, fromDate, toDate, timezone, completedDeliveries, totalEarnings,
  currency=VND, earningsConfigured, chart (date, completedDeliveries, earnings).
- Chart gồm đủ từng ngày, kể cả ngày 0 đơn. Đếm các lần hoàn tất được ghi nhận từ khi tính năng này triển khai.

## Ví và giao dịch

- `GET /drivers/me/wallet`: balance, currency, earningsConfigured.
- `GET /drivers/me/wallet/transactions?page=0&size=20`
- `GET /drivers/me/wallet/transactions/{id}`

Giao dịch gồm id, type=DELIVERY_EARNING, amount, balanceAfter, deliveryId, description, createdAt.
Ví chỉ ghi tiền công, chưa nạp/rút, khấu trừ, ngân hàng, đối soát COD. Số dư tính từ sổ tiền công.

### Chính sách tiền công

Đặt `APP_DRIVER_EARNING_PER_DELIVERY` trong .env Docker rồi `docker compose up -d backend`.
Mặc định **0** (chưa chốt chính sách), `earningsConfigured=false`; không tự lấy phí giao/tiền COD làm thu nhập.
Ví dụ nếu thống nhất 15.000 VND/chuyến thành công thì đặt biến thành `15000`.
Mỗi chuyến ghi đúng một lần trong cùng transaction với confirm-delivery, có unique deliveryId;
retry không cộng trùng, chuyến FAILED không cộng. Số tiền được chốt tại thời điểm hoàn tất,
đổi cấu hình không tính lại lịch sử. Các chuyến DELIVERED trước triển khai không tự backfill.
Nếu hoàn tất lúc chưa cấu hình tiền công, sổ ghi amount=0 kèm mô tả chưa cấu hình; không tự trả bù sau đó.

## Thông báo

- `GET /drivers/me/notifications?page=0&size=20`
- `GET /drivers/me/notifications/unread-count`: `{ "count": 0 }`
- `PATCH /drivers/me/notifications/{id}/read`: trả thông báo sau cập nhật.
- `PATCH /drivers/me/notifications/read-all`: 204.

Thông báo gồm id, type, title, message, referenceId (deliveryId), read, createdAt.
Hiện tạo thông báo DELIVERY_COMPLETED khi giao thành công; chưa có các nguồn thông báo khác.

## Lịch sử giao hàng

- `GET /drivers/me/deliveries/history?page=0&size=20` (đã có).
- `GET /drivers/me/deliveries/history/{deliveryId}`: chỉ chuyến DELIVERED/FAILED thuộc tài xế.

Chi tiết sử dụng DTO chuyến giao hiện có. Tiền công xem giao dịch ví theo deliveryId;
chưa bổ sung tiền công vào DTO chuyến giao để không phá hợp đồng tích hợp hiện tại.

## Phân trang và tích hợp

Danh sách dùng PageResponse chung (items và metadata phân trang), size 1–100, page >=0.
FE lưu/đọc qua repository; sau confirm-delivery tải lại wallet, earnings, notifications và history.
Không cộng tiền ở FE. Không phụ thuộc trực tiếp giữa giao diện giao hàng và giao diện tài khoản.
