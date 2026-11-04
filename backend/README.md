# MealGo Backend

Spring Boot 3.5.14 / Java 21 / Maven / PostgreSQL. N-tier monolith, **không dùng Flyway**.

## Cấu trúc

```text
src/main/java/com/mealgo/monolith/
  auth/          controller → service → repository → entity
  customer/      controller, DTO đặt/hủy đơn
  restaurant/    controller → service → repository → entity
  order/         service → repository → entity, DTO, mapper, enums
  driver/        controller → service → repository → entity, DTO, mapper
  delivery/      controller → service → repository → entity, DTO, mapper, scheduler
  common/        config, security, exception, storage, DTO phân trang
```

CustomerOrderController sử dụng OrderService; không tạo CustomerService/CustomerRepository chuyển tiếp hoặc lưu đơn trùng. Controller không truy cập repository. Một ứng dụng, một database; giao tiếp liên module qua service, không HTTP nội bộ.

## Chạy toàn bộ bằng Docker

Yêu cầu Docker Desktop đang chạy (Linux containers).

```powershell
Set-Location D:\prm\mealgo\backend
Copy-Item .env.example .env
docker compose up -d --build
docker compose ps
docker compose logs -f backend
```

- API: http://localhost:8080
- Health: http://localhost:8080/actuator/health
- PostgreSQL: localhost:5433, database `mealgo_db`
- MinIO API: http://localhost:9000
- MinIO Console: http://localhost:9001
- Credentials và cổng: `.env`. Các cổng chỉ bind loopback cho phát triển local.
- `minio-init` tạo bucket private `delivery-evidence` và kết thúc thành công (Exited 0 là bình thường).
- MinIO và mc build từ source upstream với release tag cố định trong `docker/`, vì image upstream không còn pull được tại thời điểm kiểm tra. Lần build đầu cần tải Go dependencies, có thể mất vài phút. MinIO/mc thuộc giấy phép AGPL-3.0 của upstream; cần xem xét nghĩa vụ giấy phép khi phân phối/triển khai.
- Named volumes lưu database và ảnh. `docker compose down` giữ dữ liệu. Không dùng `down -v` nếu muốn giữ dữ liệu.

## Chạy backend bằng IntelliJ

```powershell
docker compose up -d postgres minio minio-init
```

Chạy `MealGoApplication` với JDK 21, profile `local` (mặc định). Profile local có cấu hình phát triển mặc định khớp `.env.example`. Nếu thay credentials/cổng trong `.env`, phải đặt tương ứng các environment variables cho IntelliJ: `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `JWT_SECRET`.

Spring Boot **không tự đọc `.env`** khi chạy ngoài Compose. Đặt `APP_SEED_ENABLED=true` trong Run Configuration nếu cần dữ liệu demo.

## Build và test

Máy có Maven/JDK 21:

```powershell
mvn verify
```

Hoặc không cần cài Java/Maven:

```powershell
docker run --rm --mount "type=bind,source=${PWD},target=/app" --mount "type=volume,source=mealgo-maven-cache,target=/root/.m2" -w /app maven:3.9.11-eclipse-temurin-21 mvn -B verify
```

Test tích hợp dùng H2, MockMvc, JWT thật và mock MinIO. Bao phủ luồng giao thành công, thất bại kèm ảnh và retry, kiểm tra quyền sở hữu/vai trò, không cho lấy món trước READY, không cho hủy sau khi quán nhận, yêu cầu GPS và tính tiền server-side. Không cần database/MinIO đang chạy để chạy test.

## Dữ liệu demo

`.env.example` bật `APP_SEED_ENABLED=true`. **Chỉ dùng local**, tắt khi triển khai thật. Không có tài khoản admin hoặc public API tạo merchant.

| Phone number | Password | Role |
|---|---|---|
| 0900000003 | Mealgo123! | CUSTOMER |
| 0900000002 | Mealgo123! | MERCHANT |
| 0900000001 | Mealgo123! | DRIVER |

Demo tạo một quán và món Cơm gà giá 45.000 VND. Tài xế ban đầu offline. Lấy ID để gọi API bằng SQL (không mở rộng API CRUD menu/profile ngoài phạm vi đã chốt):

```powershell
docker compose exec postgres psql -U mealgo -d mealgo_db -c "select id, name, latitude, longitude from restaurants;"
docker compose exec postgres psql -U mealgo -d mealgo_db -c "select id, restaurant_id, name, price from menu_items;"
```

## Auth

## Đối soát tiền công tài xế

Tiền công hiện do DriverAccountService trong monolith ghi vào driver_earnings, không phải Wallet Service riêng. `APP_DRIVER_EARNING_PER_DELIVERY` là mức tiền công cố định được vận hành xác nhận; không phải phí ship hoặc tiền thu hộ. Không tự đặt giá trị này nếu chưa có chính sách được duyệt.

Nếu cấu hình không dương, hoàn tất giao hàng vẫn thành công nhưng khoản tiền công được lưu riêng vào pending_driver_earnings. Không tạo giao dịch 0đ, không cộng ví và không đưa khoản chờ vào tổng thu nhập. Trạng thái resolved/resolvedAt/resolvedBy ghi nhận đối soát; khóa tài xế và unique deliveryId bảo vệ cộng trùng.

- ADMIN: `GET /api/v1/admin/driver-earnings/pending` (page, size) xem khoản chờ.
- ADMIN: `POST /api/v1/admin/driver-earnings/{deliveryId}/reconcile`, body `{"amount": SO_TIEN_DA_DUOC_XAC_NHAN}`. Phải nhập số nguyên VND dương theo chính sách đã xác nhận, không suy ra từ phí ship. Gọi lại khoản đã xử lý không cộng lần hai. Ghi nhận vào ví/thu nhập tại thời điểm đối soát, không sửa tổng lịch sử của ngày giao.
- Job mỗi 60 giây chuyển các placeholder cũ amount=0/rateConfigured=false sang khoản chờ, xóa placeholder khỏi ledger; không xóa/sửa khoản có tiền. Restart/retry không tự cộng tiền. Các khoản chờ được xử lý thủ công qua API admin, không tự lấy cấu hình mới áp cho chuyến cũ. Vận hành phải theo dõi danh sách pending và log lỗi.
- DTO ví/giao dịch hiện có không đổi. Số tiền chờ chưa xác định không được hiển thị như 0đ hoặc cộng vào balance. `completedDeliveries` trong earnings là số chuyến đã ghi nhận tiền công, không bao gồm khoản đang chờ; lịch sử giao hàng vẫn giữ trạng thái giao thành công.

### Access token và refresh token

- Login/đăng ký trả thêm `refreshToken`. Access token mặc định sống 1 giờ (`app.jwt.ttl-seconds`); phiên refresh sống tối đa 30 ngày kể từ đăng nhập (`app.jwt.refresh-ttl-seconds`), không kéo dài hạn khi đổi token.
- `POST /api/v1/auth/refresh`, body `{ "refreshToken": "..." }`: không gửi Authorization; trả access token và refresh token mới. Token cũ dùng một lần; dùng lại sẽ thu hồi cả phiên refresh đó. Refresh token là chuỗi ngẫu nhiên, chỉ lưu SHA-256 trong database, khóa dòng khi đổi token.
- `POST /api/v1/auth/logout`, cùng body: thu hồi phiên refresh hiện tại, trả 204. Các phiên trên thiết bị khác không bị ảnh hưởng. Access JWT đã phát vẫn hợp lệ đến khi hết hạn; chưa có blacklist access token.
- Flutter lưu hai token bằng FlutterSecureStorage. Khi nhận 401 ở yêu cầu đã đăng nhập, app đổi token và thử lại đúng một lần; các yêu cầu đồng thời dùng chung một lần đổi token. Áp dụng cho JSON, upload ảnh và kết nối lại SSE. Lỗi kết nối/5xx khi gia hạn không tự xóa phiên.
- Đăng xuất offline xóa phiên trên thiết bị nhưng không bảo đảm thu hồi refresh token phía backend. Cần HTTPS khi triển khai thực tế. Trên web, storage không thay thế được HttpOnly cookie và không bảo vệ trước mã JavaScript độc hại/XSS; các tab không đồng bộ khóa gia hạn, nên tránh dùng chung phiên qua nhiều tab. Nếu phản hồi đổi token bị mất sau khi backend đã lưu, lần dùng lại token cũ sẽ thu hồi phiên và yêu cầu đăng nhập lại.
- Backend cần khởi động/rebuild để có bảng `refresh_sessions` theo cơ chế schema hiện tại. Người dùng đăng nhập trước bản cập nhật cần đăng nhập lại một lần để nhận refresh token.

### Đăng ký đối tác tài xế (OTP giả lập phát triển)

Flutter: Đăng nhập → Đăng ký làm đối tác tài xế → OTP → hồ sơ cá nhân → phương tiện và 4 ảnh giấy tờ → kiểm tra/gửi → chờ admin duyệt. Tài khoản chưa có hồ sơ được duyệt không thể vào ca. Tài xế demo/đã tồn tại giữ nguyên trạng thái active, không tự động khóa dữ liệu cũ.

- `POST /api/v1/auth/register/start`: `{ "phoneNumber": "0934567890", "password": "Password123!" }`.
- Response chứa `registrationId`, `mode=MOCK_DEVELOPMENT_ONLY`, `devOtp`, `expiresAt`, `resendAt`. Không gửi SMS thật. Phiên OTP lưu trong RAM, mất khi backend restart; triển khai này chỉ dành cho một instance phát triển.
- `POST /api/v1/auth/register/verify`: `{ "registrationId": "UUID", "otp": "12345" }`; OTP giả lập cố định 5 số cho cả gửi đầu và gửi lại, chỉ dành cho phát triển. Thành công trả JWT DRIVER. Chỉ tạo tài khoản sau OTP hợp lệ.
- `POST /api/v1/auth/register/resend`: `{ "registrationId": "UUID" }`. Mỗi mã sống 5 phút, chờ 60 giây gửi lại, tối đa 5 lần nhập sai. OTP/mật khẩu lưu dạng hash trong phiên. Chưa tích hợp SMS/rate limit phân tán cho production.
- Public `/auth/register` chỉ tạo CUSTOMER; không tạo DRIVER/MERCHANT/ADMIN để tránh bỏ qua OTP.
- Mock OTP: local bật mặc định, Docker Compose phát triển bật qua `APP_OTP_MOCK_ENABLED` (đặt false khi không cần). Mặc định ứng dụng tắt; từ chối mock nếu có profile prod/production.

API hồ sơ dùng JWT DRIVER:

- `GET /api/v1/drivers/me/application`: tạo/lấy bản nháp, trả `applicationId` và trạng thái.
- `PUT /api/v1/drivers/me/application`: fullName, birthDate (`YYYY-MM-DD`), address, identityNumber (12 số), vehicleType, licensePlate, drivingLicense.
- `POST /api/v1/drivers/me/application/documents/{type}` multipart `image`; type: IDENTITY_FRONT, IDENTITY_BACK, VEHICLE_REGISTRATION, DRIVING_LICENSE. PNG/JPEG thật, tối đa 5 MB/25 megapixels. Lưu bucket private `driver-documents`; không trả object key.
- `POST /api/v1/drivers/me/application/submit`: đủ thông tin/4 ảnh mới chuyển DRAFT → PENDING_REVIEW, khóa chỉnh sửa.
- Bản hiện tại lưu nháp khi đủ thông tin cá nhân và xe; chưa tự lưu từng trường/ảnh xem trước. Ảnh thay thế có thể còn object mồ côi, cần retention/cleanup trước production.

Admin dùng Postman collection `postman/driver-onboarding.postman_collection.json`. Bật seed development tạo SĐT `0900000004`, mật khẩu `Mealgo123!`, role ADMIN; không dùng tài khoản này ở production. Login để lấy `adminToken`, điền `applicationId` từ màn chờ duyệt.

- `GET /api/v1/admin/driver-applications/{id}` xem hồ sơ.
- `GET /api/v1/admin/driver-applications/{id}/documents/{type}` tải ảnh private (chỉ ADMIN).
- `POST /api/v1/admin/driver-applications/{id}/approve` body `{ "note": "Hồ sơ hợp lệ" }`: duyệt PENDING_REVIEW, lưu reviewedBy/reviewedAt, tạo/kích hoạt hồ sơ tài xế. Gọi lại APPROVED không tạo hồ sơ trùng.
- Tài xế bấm Kiểm tra trạng thái sau khi admin duyệt để vào trang chính. Chưa triển khai từ chối/yêu cầu bổ sung, OTP thật, UI admin.

```http
POST /api/v1/auth/login
Content-Type: application/json

{"phoneNumber":"0900000003","password":"Mealgo123!"}
```

Response có `accessToken`, `tokenType`, `expiresIn`, `userId`, `role`. Dùng `Authorization: Bearer <accessToken>` cho API nghiệp vụ. Token HS256, issuer `mealgo`, hạn 1 giờ. Không dùng user cố định hoặc header giả lập.

`POST /api/v1/auth/register`: `{ "phoneNumber": "0912345678", "password": "Password123!", "role": "CUSTOMER" }`. API này chỉ tạo CUSTOMER; DRIVER đăng ký qua luồng OTP giả lập rồi hoàn thiện hồ sơ và chờ ADMIN duyệt. Refresh token và duyệt hồ sơ đã được triển khai; chưa có API quên mật khẩu.

Số di động Việt Nam nhận dạng `0[35789]xxxxxxxx` hoặc `+84[35789]xxxxxxxx`, chuẩn hóa về `+84` và duy nhất giữa các tài khoản. Đăng ký CUSTOMER chưa xác minh OTP; OTP đăng ký DRIVER chỉ là giả lập, không gửi SMS. JWT không chứa số điện thoại; `sub` vẫn là UUID. Logout thu hồi phiên refresh khi token khớp, nhưng không thu hồi access token đã phát; client tự xóa token trên thiết bị.

Migration: giữ cột username nội bộ và UUID để không mất liên kết dữ liệu cũ. Cột phone_number cho phép null tạm thời với tài khoản cũ; demo initializer gán số trong bảng trên cho tài khoản demo chưa có số. Tài khoản cũ khác cần được quản trị viên gán số đã chuẩn hóa, không trùng trước khi đăng nhập lại. Không tự lấy số liên hệ trong hồ sơ làm số đăng nhập; sửa hồ sơ không thay đổi số đăng nhập. Không xóa database để migration. Chỉ đặt NOT NULL sau khi đã bổ sung số cho toàn bộ tài khoản.

## API Customer — giỏ hàng và đặt đơn

Đăng nhập: `POST /api/v1/auth/login` với `phoneNumber`, `password`. Dùng token role `CUSTOMER`
qua header `Authorization: Bearer <accessToken>`. Customer ID lấy từ JWT, không nhận từ client.

### Giỏ hàng lưu trong database

| Method | URL | Nội dung |
|---|---|---|
| GET | /api/v1/customers/me/cart | Xem giỏ và giá hiện tại |
| POST | /api/v1/customers/me/cart/items | `{ "menuItemId": "UUID", "quantity": 2, "note": "Không cay" }`; cộng số lượng |
| PUT | /api/v1/customers/me/cart/items/{menuItemId} | `{ "quantity": 1, "note": "Không cay" }`; thay số lượng/ghi chú |
| DELETE | /api/v1/customers/me/cart/items/{menuItemId} | Xóa món, trả 204 |
| DELETE | /api/v1/customers/me/cart | Xóa giỏ, trả 204 |

Một giỏ chỉ chứa món từ một quán; đổi quán phải xóa giỏ trước (409 nếu khác quán).
Tối đa 50 món khác nhau, mỗi món 1–100 phần. Giá luôn lấy từ database.
Response gồm `restaurantId`, `items` (menuItemId, name, quantity, note, unitPrice, lineTotal, available),
`subtotal`, `deliveryFee`, `total`. Giỏ rỗng có phí giao/tổng bằng 0; phí giao giỏ có món là 15.000 VND.
Món hết hàng vẫn hiển thị với `available=false`; đặt hàng sẽ kiểm tra lại giá và tình trạng món/quán.

### Đặt hàng từ giỏ

GET giỏ rồi gửi `restaurantId`, `items` (menuItemId, quantity, note) sang API đặt hàng bên dưới,
kèm người nhận, địa chỉ, `paymentMethod=COD` và `Idempotency-Key` duy nhất cho lần đặt.
Sau khi đặt thành công mới DELETE giỏ. Nếu mạng lỗi, retry cùng key/body để tránh tạo đơn trùng.
API đặt hàng hiện có không tự xóa giỏ. Chưa có API duyệt menu; ID món/quán để thử local xem phần Dữ liệu demo.

| Method | URL | Nội dung |
|---|---|---|
| POST | /api/v1/customers/me/orders | Đặt đơn, bắt buộc header `Idempotency-Key` |
| GET | /api/v1/customers/me/orders?page=0&size=20 | Danh sách đơn |
| GET | /api/v1/customers/me/orders/{id} | Chi tiết |
| GET | /api/v1/customers/me/orders/{id}/tracking | Tiến độ, tài xế và vị trí |
| POST | /api/v1/customers/me/orders/{id}/cancel | `{ "reason": "Đặt nhầm" }` |

Body đặt đơn:

```json
{
  "restaurantId": "RESTAURANT_UUID",
  "items": [{"menuItemId": "MENU_ITEM_UUID", "quantity": 2, "note": "Không cay"}],
  "recipient": {"name": "Nguyễn Văn A", "phone": "0901234567"},
  "dropoff": {"address": "Địa chỉ khách", "latitude": 10.78, "longitude": 106.70},
  "deliveryNote": "Gọi trước khi giao",
  "paymentMethod": "COD"
}
```

Backend lưu snapshot món, giá, quán và địa chỉ. Giá từ database, phí giao **cố định 15.000 VND cho MVP**. Chỉ hỗ trợ COD; không giả lập thanh toán online. Cùng idempotency key và body trả đơn cũ; khác body trả 409. Request cùng key đồng thời có thể trả 409 do unique constraint; retry sẽ lấy đơn đã tạo. Chỉ được hủy khi PENDING. Không có API profile/địa chỉ/giỏ hàng.

## API Restaurant — xử lý đơn

Prefix `/api/v1/merchant/restaurants/{restaurantId}/orders`.

| Method | Suffix | Body |
|---|---|---|
| GET | ?page=0&size=20&status=PENDING | Không bắt buộc status |
| GET | /{orderId} | Chi tiết đơn, tài xế và trạng thái giao |
| POST | /{orderId}/accept | `{ "estimatedPreparationMinutes": 20 }` |
| POST | /{orderId}/reject | `{ "reason": "Hết nguyên liệu" }` |
| POST | /{orderId}/cancel | `{ "reason": "Hết nguyên liệu" }`; chỉ PENDING/PREPARING, từ READY trả 409 |
| POST | /{orderId}/ready | Không cần body |

Chỉ owner của quán có quyền. Accept tạo chuyến giao trong cùng transaction. Không có API CRUD menu/quán hoặc báo cáo doanh thu.

Quy tắc hủy: khách chỉ hủy khi PENDING (trước khi quán nhận). Nhà hàng dùng `/cancel` khi PENDING hoặc PREPARING; hủy đồng thời chuyến giao và các offer còn hiệu lực, thông báo SSE cho tài xế liên quan. `/reject` vẫn chỉ từ chối đơn PENDING. Tài xế báo incident/bỏ chuyến chỉ khi Order PREPARING và chưa lấy hàng; từ READY trả 409. Mọi lý do incident, kể cả RESTAURANT_CLOSED, chỉ bỏ chuyến để tìm tài xế khác, không hủy đơn khách; lý do quán đóng vẫn yêu cầu ảnh/GPS. Dispatcher không mời lại tài xế đã bỏ chuyến. Frontend phải xử lý 409 nếu quán chuyển READY cùng lúc thao tác hủy.

## API Driver / Delivery

Prefix driver `/api/v1/drivers`:

| Method | Suffix | Body |
|---|---|---|
| POST | (rỗng) | `{ "fullName": "...", "phoneNumber": "..." }` |
| GET | /me | Hồ sơ |
| PUT | /me/profile | fullName, phoneNumber |
| PUT | /me/online-status | `{ "online": true }` |
| POST | /me/tracking-session | Không cần body; trả session ID |
| PUT | /me/location | Body dưới đây |
| GET | /me/offers | Các offer chưa hết hạn |
| GET | /me/offers/{assignmentId} | Chi tiết, gồm điểm lấy/giao |
| POST | /me/offers/{assignmentId}/accept | Nhận đơn |
| POST | /me/offers/{assignmentId}/reject | Từ chối |
| GET | /me/deliveries/current | Chuyến hiện tại; 204 nếu không có |
| GET | /me/deliveries/history?page=0&size=20 | Chuyến đã giao/thất bại |
| POST | /me/deliveries/{id}/arrive-at-pickup | Đến quán |
| POST | /me/deliveries/{id}/confirm-pickup | Lấy hàng; Order phải READY |
| POST | /me/deliveries/{id}/arrive-at-dropoff | Đến khách |
| POST | /me/deliveries/{id}/confirm-delivery | Giao thành công, xác nhận đã thu COD |
| POST | /me/deliveries/{id}/failure-report | Multipart: assignmentId, requestId, reason, note?, image |
| GET | /me/deliveries/{id}/failure-report | Báo cáo thất bại |
| GET | /me/deliveries/{id}/failure-report/evidence | Ảnh có kiểm tra quyền |

### API khuôn mặt (stub luôn thành công)

`POST /api/v1/drivers/me/face-verification`, Bearer JWT role DRIVER, hồ sơ tài xế phải tồn tại.
Gửi `multipart/form-data` với file `image` không rỗng. Response HTTP 200:

```json
{"success":true,"mode":"MOCK_ALWAYS_SUCCESS","checkedAt":"2026-11-02T08:00:00Z"}
```

Đây là endpoint thật nhưng **không nhận diện khuôn mặt, không kiểm tra liveness hay nội dung ảnh**;
mọi file không rỗng đều cho kết quả thành công. Không lưu ảnh hoặc dữ liệu sinh trắc học.
Không dùng làm bằng chứng danh tính hoặc điều kiện phân quyền. JWT không hợp lệ/sai role,
thiếu hồ sơ, thiếu file/rỗng hoặc vượt giới hạn multipart vẫn trả lỗi HTTP, không phải success.
API không tự bật online. Frontend dùng camera xin quyền, chụp và gửi ảnh trước khi gọi API online-status; đây chỉ là luồng UI, không phải điều kiện phân quyền server-side.

### Cập nhật vị trí

Body vị trí:

```json
{
  "trackingSessionId": "SESSION_UUID",
  "sequence": 1,
  "latitude": 21.038214,
  "longitude": 105.547018,
  "accuracyMeters": 10,
  "recordedAt": "2026-11-02T08:00:00Z"
}
```

`recordedAt` phải là thời gian UTC hiện tại (ví dụ chỉ minh họa). Sequence tăng trong session; session mới thay session cũ. GPS tối đa cũ 30 giây, lệch tương lai tối đa 10 giây; thao tác đến/lấy/giao cần accuracy <= 50 m và trong 200 m của điểm tương ứng.

Failure reason: `CUSTOMER_UNREACHABLE`, `CUSTOMER_REFUSED`, `OTHER`. Chỉ báo khi AT_DROPOFF. PNG/JPEG thực, tối đa 5 MB/25 megapixels. Giữ nguyên requestId và nội dung khi retry. Bucket private; không trả object key ra client. Upload và DB không có distributed transaction: có thể còn object mồ côi nếu upload thành công nhưng DB lỗi, cần tác vụ dọn object khi production.

## Luồng kiểm thử thủ công

1. Login ba tài khoản lấy ba token.
2. Customer đặt đơn (ID quán/món lấy bằng SQL ở trên).
3. Merchant accept.
4. Driver online; chờ tối đa khoảng 5 giây, poll offers rồi accept.
5. Driver tạo tracking session, gửi GPS điểm quán, arrive-at-pickup.
6. Merchant ready, Driver confirm-pickup.
7. Driver gửi GPS điểm khách, arrive-at-dropoff.
8. Driver confirm-delivery hoặc failure-report.
9. Customer xem order/tracking; merchant xem detail; driver xem history.

Dispatcher MVP chọn tài xế online đầu tiên còn rảnh, offer 60 giây, mỗi chuyến không mời lại tài xế đã từ chối/hết hạn. Không có tối ưu khoảng cách, push notification hoặc retry vô hạn: nếu hết ứng viên chuyến ở PENDING_ASSIGNMENT. Dự kiến chạy một replica backend cho MVP; cần harden concurrency/dispatch trước khi scale nhiều instance.

### SSE cho tài xế

`GET /api/v1/drivers/me/events`, header `Authorization: Bearer <JWT>`, role DRIVER và hồ sơ tài xế bắt buộc. Response `text/event-stream`: `connected` khi kết nối, `orders-changed` khi offer được tạo/hết hạn/nhận/từ chối, `heartbeat` mỗi 15 giây. Sự kiện chỉ gửi cho đúng driver, sau transaction commit; payload `{}` chỉ yêu cầu client tải lại offers/current, không chứa dữ liệu đơn. Không truyền JWT trên URL.

Flutter Android tự reconnect với backoff 2–32 giây và tải lại dữ liệu sau mỗi kết nối để bù sự kiện bị lỡ; polling dự phòng mỗi 30 giây. Stream hết hạn sau 5 phút để kết nối lại và xác thực JWT. Không có replay/event log, không thay thế FCM khi app chạy nền. Subscription hiện lưu trong bộ nhớ một backend instance; nhiều replica cần pub/sub dùng chung. Nếu triển khai reverse proxy, tắt buffering cho endpoint SSE. Flutter web với HTTP client mặc định chưa được xác minh khả năng stream; bản này ưu tiên Android và vẫn giữ polling dự phòng.

## Lưu ý triển khai

- Hibernate `ddl-auto=update` chỉ dành cho phát triển. Production dùng schema được quản lý rõ ràng và `DDL_AUTO=validate`; không bật Flyway.
- Đổi secrets, tắt seed demo, cấu hình HTTPS và secret manager trước khi public.
- Chưa gồm payments online, ví/thu nhập, đánh giá, hoàn tiền, quản trị hoặc refresh/revoke JWT.
- API mới chuẩn hóa `/api/v1`; không tương thích nguyên đường dẫn `/drivers/me/...` thiếu prefix của delivery-service cũ.
- Lỗi nghiệp vụ: 400 input, 401 chưa xác thực, 403 sai role, 404 không tồn tại/không sở hữu, 409 xung đột trạng thái. Phân trang size 1..100.
- Source delivery-service cũ không bị chỉnh sửa; đây là implementation N-tier mới, không chạy hai service cùng sở hữu một đơn/chuyến.

File `requests.http` chứa request mẫu theo luồng cho IntelliJ HTTP Client/VS Code REST Client; thay token, UUID và thời gian GPS trước khi gửi.

Sau khi stack đã healthy và có seed demo, có thể chạy `powershell -ExecutionPolicy Bypass -File scripts/smoke-test.ps1` để kiểm thử một đơn thật qua HTTP và PostgreSQL. Script tạo dữ liệu đơn mới; dùng database thử nghiệm không có đơn pending khác. Không kiểm tra upload MinIO trong script này (test tích hợp upload dùng mock storage).
# Tài liệu Swagger / OpenAPI bằng tiếng Việt

Sau khi build và chạy backend:

- **Swagger UI:** <http://localhost:8080/swagger-ui/index.html>
- **OpenAPI JSON:** <http://localhost:8080/v3/api-docs>
- **OpenAPI YAML:** <http://localhost:8080/v3/api-docs.yaml>

Tài liệu bao phủ 69 thao tác của 13 controller nghiệp vụ `/api/v1/**`, chia nhóm theo vai trò.
Không đưa endpoint vận hành Actuator vào danh mục nghiệp vụ.
Mỗi thao tác có mô tả tiếng Việt về điều kiện, quyền, request/response, lỗi và quy tắc thử lại.
Schema được sinh trực tiếp từ DTO và Bean Validation, bổ sung diễn giải tiếng Việt từng trường.
Tên trường JSON và enum vẫn giữ nguyên để tương thích ứng dụng hiện tại.

## Gọi thử API

1. Mở nhóm **01. Xác thực**, gọi `POST /api/v1/auth/login` bằng tài khoản trên môi trường của bạn.
2. Sao chép `accessToken` trong response. Bấm **Authorize**, chỉ dán giá trị token, không thêm chữ `Bearer`.
3. Chọn endpoint phù hợp quyền CUSTOMER / MERCHANT / DRIVER / ADMIN và bấm **Try it out**.
4. Với tham số UUID, thay UUID minh họa bằng mã tài nguyên thực tế. Với vị trí, thay `recordedAt`
   bằng thời gian hiện tại; thời gian minh họa cố định sẽ bị từ chối vì quá cũ.
5. Khi JWT hết hạn, gọi refresh, thay cả accessToken và refreshToken, rồi Authorize lại.
   Không gọi refresh đồng thời bằng cùng token và không dùng lại refreshToken cũ.
6. Với ảnh, chọn tệp trong trường `image`; không gửi đường dẫn tệp dưới dạng JSON.

**Cảnh báo:** Try it out gọi API thật, có thể đặt/hủy đơn, duyệt tài xế và ghi nhận tiền công.
Mọi số tiền, số điện thoại và UUID minh họa chỉ để giải thích định dạng, không phải dữ liệu nghiệp vụ
hay mức tiền công đã được chấp thuận. Chỉ reconcile khi số tiền thực đã được người có thẩm quyền xác nhận.
Swagger không lưu authorization qua lần tải lại trang. Không chia sẻ token, ảnh giấy tờ hay thông tin cá nhân.
Trang tài liệu được mở không cần JWT; các API nghiệp vụ vẫn kiểm tra quyền như trước.
Khi triển khai công khai, cần đánh giá có nên tắt `springdoc.api-docs.enabled` và
`springdoc.swagger-ui.enabled`, hoặc bảo vệ tài liệu ở reverse proxy theo chính sách môi trường.

## Luồng cần chú ý

- Tài xế mới: OTP `12345` (chỉ mock local/docker/test, không SMS) → hoàn thiện application → tải đủ
  4 giấy tờ → submit → ADMIN approve → bật online. Phiên OTP trong RAM mất khi backend restart.
- API đăng ký trực tiếp `/auth/register` chỉ tạo CUSTOMER; không dùng để tự cấp ADMIN/MERCHANT/DRIVER.
- SSE `/drivers/me/events` trả sự kiện `connected`, `heartbeat`, `orders-changed`, data `{}`.
  Client phải tải lại offers/current, kết nối lại sau timeout khoảng 5 phút; không có replay sự kiện.
  Swagger không phải trình xem SSE; ví dụ PowerShell:

  ```powershell
  curl.exe -N -H "Authorization: Bearer <accessToken>" http://localhost:8080/api/v1/drivers/me/events
  ```

- Giải phóng chuyến trước lấy hàng không phải hủy đơn khách, chỉ cho phép khi đơn PREPARING, chặn READY.
- Tiền COD thu hộ, phí giao khách trả và tiền công tài xế là các khái niệm khác nhau.
  Ví không gồm khoản chờ xác nhận, chưa có API rút tiền hoặc thưởng.
- Phân trang từ 0, size 1–100; response chỉ có `items`, `page`, `size`, `hasNext`.
- Lỗi nghiệp vụ dùng ProblemDetail; lỗi JWT ở security filter không bảo đảm cùng cấu trúc body.

## Bảo trì tài liệu và kiểm thử

- Cấu hình: `common/config/OpenApiConfig.java`, `springdoc` trong `application.yaml`.
  Tài liệu được xuất theo OpenAPI 3.1 (`springdoc.api-docs.version=OPENAPI_3_1`).
- Summary, nghiệp vụ, tham số và schema: `common/docs/ApiDocumentation.java`.
  Request body, kết quả thành công và lỗi theo endpoint: `common/docs/EndpointDocumentation.java`.
  Bổ sung cả hai danh mục khi có API mới; đối chiếu với controller, service, DTO và exception handler.
- Dùng tên schema đầy đủ (`use-fqn`) để tránh trùng các record `Profile`, `View`, `Item`, `Location`.
- `OpenApiDocumentationTest` kiểm tra toàn bộ thao tác có mô tả, operationId không trùng, từng trường
  có diễn giải, tài liệu truy cập công khai và API tiền công vẫn yêu cầu JWT.
- Chạy `mvn verify` (Java 21/Maven), hoặc `docker build -t mealgo-backend:swagger-check .`.
  Build Docker chạy cả test; không cần thay đổi dữ liệu PostgreSQL hiện có để kiểm tra tài liệu.

### Ranh giới hợp đồng và điểm cần xác minh

- Mô tả HTTP trong Swagger phản ánh các nhánh xử lý hiện tại, không phải đề xuất thêm mã lỗi.
  `503` trên API lưu/tải ảnh đã được `EvidenceStorage` xử lý thực tế, không phải mã mới của bản tài liệu.
- Handler chung còn ánh xạ lỗi ràng buộc database và optimistic locking thành `409`.
  Nếu không có nhánh nghiệp vụ cụ thể, cần kiểm tra log/ràng buộc bị vi phạm; không suy ra số điện thoại trùng,
  đơn sai trạng thái hoặc retry khác dữ liệu chỉ từ mã `409`.
- Cần xác minh tình huống dữ liệu nội bộ bị thiếu: ví dụ nghĩa vụ tiền công còn nhưng Driver đã mất,
  hoặc hồ sơ đối tác còn nhưng UserAccount không tồn tại. Một số nhánh dùng `orElseThrow()` không có
  ánh xạ lỗi nghiệp vụ; tài liệu không cam kết `404`/ProblemDetail cho các trường hợp này.
- `200` của API đối soát và toàn bộ `204` không có body. Không gọi JSON parser cho các response này.
  SSE và tải ảnh/giấy tờ dùng media type riêng, không phải JSON.
