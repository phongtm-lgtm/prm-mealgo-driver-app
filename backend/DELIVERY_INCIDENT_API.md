# Giao hàng và xử lý sự cố

Database PostgreSQL cũ: chạy `migrations/20261104_delivery_incident_status.sql`
để mở rộng CHECK constraint trạng thái. Hibernate update không tự mở rộng constraint cũ.
Script chạy trong transaction, không xóa dữ liệu; database mới được Hibernate tạo đủ trạng thái.

Với PostgreSQL đã có dữ liệu, chạy thêm `migrations/20261105_order_cancellation.sql`
để thêm mã nguồn hủy và mở rộng danh sách lý do sự cố.

Tất cả API dưới đây yêu cầu Bearer token DRIVER. Không gọi UI giữa module;
frontend dùng DeliveryIncidentRepository và DriverController, phát invalidation
cho AccountState sau thành công.

## Báo sự cố và giải phóng chuyến trước lấy hàng

`POST /api/v1/drivers/me/deliveries/{deliveryId}/incident` (multipart/form-data):

- assignmentId: UUID phân công hiện tại, không phải orderId.
- requestId: UUID giữ nguyên khi retry cùng nội dung.
- reason: PERSONAL, VEHICLE_BREAKDOWN, BAD_WEATHER, RESTAURANT_DELAY, RESTAURANT_CLOSED, CUSTOMER_UNREACHABLE.
- note: tối đa 1000 ký tự.
- image: bắt buộc cho RESTAURANT_CLOSED và CUSTOMER_UNREACHABLE, PNG/JPEG tối đa 5 MB, 25 megapixel. Với khách không nghe máy, đính kèm ảnh lịch sử cuộc gọi cho khách.

Chỉ được thực hiện trước khi lấy hàng (ASSIGNED/AT_PICKUP), đơn phải PREPARING; READY bị từ chối với 409.
Quán đóng cửa cần GPS mới và chính xác gần quán; ảnh chỉ được kiểm tra định dạng,
không có AI xác minh nội dung ảnh. API này giải phóng chuyến, không hủy đơn khách.

Mọi reason, kể cả RESTAURANT_CLOSED: kết quả PENDING_REASSIGNMENT, xóa phân công trên
chuyến, trả về PENDING_ASSIGNMENT; đơn vẫn PREPARING. Không hứa đã có
tài xế khác nhận. Dispatcher không mời lại tài xế cũ trên cùng chuyến.

RESTAURANT_CLOSED bắt buộc ảnh được lưu trong object storage và kiểm tra vị trí gần quán.
Với PERSONAL, VEHICLE_BREAKDOWN, BAD_WEATHER và RESTAURANT_DELAY, bỏ trường ảnh.

Response: id, deliveryId, assignmentId, reason, outcome, note, createdAt.
Unique assignmentId và khóa driver/delivery bảo vệ thao tác trùng; retry cùng nội dung
trả cùng biên nhận ngay cả sau khi đổi tài xế. Nội dung khác trả 409.

`GET /api/v1/drivers/me/deliveries/incidents`: biên nhận sự cố của tài xế hiện tại.
`GET /api/v1/drivers/me/deliveries/incidents/{incidentId}/evidence`: ảnh riêng tư của
tài xế đã báo cáo, no-store. Biên nhận chuyển đơn vẫn tồn tại sau khi đổi tài xế.
Chuyến đã giải phóng không còn thuộc tài xế nên không xuất hiện trong lịch sử chuyến của người báo;
tra cứu biên nhận bằng danh sách incidents. outcome ghi kết quả lúc báo, không phản ánh phân công mới nhất.

### HTTP response của thao tác báo sự cố

- `200`: trả JSON biên nhận; retry cùng assignmentId, requestId, reason, note và nội dung ảnh trả biên nhận đã lưu.
- `400`: UUID/tham số bắt buộc thiếu hoặc sai; reason không hợp lệ; note quá 1000 ký tự;
  ảnh thiếu khi RESTAURANT_CLOSED hoặc CUSTOMER_UNREACHABLE, hoặc gửi ảnh cho lý do không cần bằng chứng; ảnh rỗng, không phải PNG/JPEG,
  vượt 5 MiB hoặc 25 triệu pixel.
- `401`: thiếu Bearer JWT, JWT không hợp lệ hoặc hết hạn; body từ security filter không được bảo đảm là ProblemDetail.
- `403`: tài khoản đã xác thực nhưng không có quyền DRIVER.
- `404`: thiếu hồ sơ Driver, không tìm thấy chuyến thuộc tài xế, assignmentId không khớp,
  hoặc bản ghi retry không thuộc tài xế/chuyến được yêu cầu.
- `409`: trạng thái chuyến/đơn không cho giải phóng; retry khác dữ liệu; với RESTAURANT_CLOSED,
  GPS không đủ mới/chính xác/gần nhà hàng.
- `413`: multipart vượt giới hạn tiếp nhận (5 MB mỗi tệp, 6 MB toàn request).
- `503`: kho bằng chứng không khả dụng khi lưu ảnh.

## Báo giao thất bại

API failure-report hiện có chỉ chấp nhận AT_DROPOFF. Frontend hiển thị điều kiện
chưa đạt trước khi đến khách, preview ảnh và giữ nội dung/requestId khi lỗi mạng.
Checkbox đã liên hệ là khai báo của tài xế, chưa kiểm chứng thời gian chờ/liên hệ.
Với `CUSTOMER_UNREACHABLE`, đính kèm ảnh lịch sử cuộc gọi cho khách bằng trường
`image`. Gửi thành công kết thúc đơn và chuyến với trạng thái FAILED. Tài xế
đang online quay lại màn hình tìm đơn.

## Giới hạn

Chưa có quy trình duyệt/chi trả bồi thường, push notification, hoặc kiểm chứng nội dung
ảnh quán đóng cửa. UI dùng kết quả máy chủ, không tự cộng tiền và không giả chuyển đơn thành công.
