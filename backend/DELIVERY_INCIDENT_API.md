# Giao hàng và xử lý sự cố

Database PostgreSQL cũ: chạy `migrations/20261104_delivery_incident_status.sql`
để mở rộng CHECK constraint trạng thái. Hibernate update không tự mở rộng constraint cũ.
Script chạy trong transaction, không xóa dữ liệu; database mới được Hibernate tạo đủ trạng thái.

Tất cả API dưới đây yêu cầu Bearer token DRIVER. Không gọi UI giữa module;
frontend dùng DeliveryIncidentRepository và DriverController, phát invalidation
cho AccountState sau thành công.

## Chuyển đơn hoặc hủy vì quán đóng cửa

`POST /api/v1/drivers/me/deliveries/{deliveryId}/incident` (multipart/form-data):

- assignmentId: UUID phân công hiện tại, không phải orderId.
- requestId: UUID giữ nguyên khi retry cùng nội dung.
- reason: PERSONAL, RESTAURANT_DELAY, RESTAURANT_CLOSED.
- note: tối đa 1000 ký tự.
- image: bắt buộc cho RESTAURANT_CLOSED, PNG/JPEG tối đa 5 MB, 25 megapixel.

Chỉ được thực hiện trước khi lấy hàng (ASSIGNED/AT_PICKUP), đơn PREPARING/READY.
Quán đóng cửa cần GPS mới và chính xác gần quán; ảnh chỉ được kiểm tra định dạng,
không có AI xác minh nội dung ảnh. Chính sách đã chọn: hủy ngay không chờ duyệt.

PERSONAL/RESTAURANT_DELAY: kết quả PENDING_REASSIGNMENT, xóa phân công trên
chuyến, trả về PENDING_ASSIGNMENT; đơn vẫn PREPARING/READY. Không hứa đã có
tài xế khác nhận. Dispatcher không mời lại tài xế cũ trên cùng chuyến.

RESTAURANT_CLOSED: kết quả CANCELLED, đơn và chuyến CANCELLED; bằng chứng
lưu trong object storage. Không ghi tiền công hay bồi thường.

Response: id, deliveryId, assignmentId, reason, outcome, note, createdAt.
Unique assignmentId và khóa driver/delivery bảo vệ thao tác trùng; retry cùng nội dung
trả cùng biên nhận ngay cả sau khi đổi tài xế. Nội dung khác trả 409.

`GET /api/v1/drivers/me/deliveries/incidents`: biên nhận sự cố của tài xế hiện tại.
`GET /api/v1/drivers/me/deliveries/incidents/{incidentId}/evidence`: ảnh riêng tư của
tài xế đã báo cáo, no-store. Biên nhận chuyển đơn vẫn tồn tại sau khi đổi tài xế.
Chuyến CANCELLED xuất hiện trong lịch sử và chi tiết lịch sử của tài xế hủy.

## Báo giao thất bại

API failure-report hiện có chỉ chấp nhận AT_DROPOFF. Frontend hiển thị điều kiện
chưa đạt trước khi đến khách, preview ảnh và giữ nội dung/requestId khi lỗi mạng.
Checkbox đã liên hệ là khai báo của tài xế, chưa kiểm chứng thời gian chờ/liên hệ.
Gửi thành công chuyển FAILED, không tự sinh trạng thái chờ bồi thường.

## Giới hạn

Chưa có quy trình duyệt/chi trả bồi thường, push notification, hoặc kiểm chứng nội dung
ảnh quán đóng cửa. UI dùng kết quả máy chủ, không tự cộng tiền và không giả chuyển đơn thành công.
