package com.mealgo.monolith.common.docs;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.media.Schema;
import io.swagger.v3.oas.models.responses.ApiResponse;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import java.util.*;
import org.springframework.web.method.HandlerMethod;

/** Danh mục mô tả tập trung; schema và validation vẫn suy ra từ DTO thật. */
public final class ApiDocumentation {
    private ApiDocumentation() {}
    private record Doc(String title, String detail, String errors) {}
    private static final Map<String, Doc> OPERATIONS = new LinkedHashMap<>();
    private static final Map<String, String> TAGS = Map.ofEntries(
        Map.entry("AuthController", "01. Xác thực"),
        Map.entry("RegistrationController", "02. Đăng ký tài xế qua OTP"),
        Map.entry("DriverApplicationController", "03. Hồ sơ đăng ký đối tác"),
        Map.entry("AdminDriverApplicationController", "04. Quản trị duyệt đối tác"),
        Map.entry("DriverController", "05. Hồ sơ và vị trí tài xế"),
        Map.entry("DriverOfferController", "06. Đề nghị nhận chuyến"),
        Map.entry("DriverDeliveryController", "07. Giao hàng và sự cố"),
        Map.entry("DriverEventController", "08. Sự kiện thời gian thực"),
        Map.entry("DriverAccountController", "09. Ví, thu nhập và thông báo"),
        Map.entry("AdminEarningController", "10. Quản trị tiền công"),
        Map.entry("CustomerCartController", "11. Giỏ hàng khách hàng"),
        Map.entry("CustomerMenuController", "11. Thực đơn khách hàng"),
        Map.entry("CustomerOrderController", "12. Đơn hàng khách hàng"),
        Map.entry("RestaurantOrderController", "13. Đơn hàng nhà hàng"));

    private static void doc(String controller, String method, String title, String detail, String errors) {
        OPERATIONS.put(controller + "." + method, new Doc(title, detail, errors));
    }
    static {
        doc("CustomerMenuController", "list", "Tìm thực đơn theo tên nhà hàng", "Trả các nhà hàng đang nhận đơn có tên khớp, cùng mã món còn bán và đơn giá VND để thêm vào giỏ hoặc đặt đơn.", "400");
        doc("AuthController", "register", "Đăng ký tài khoản khách hàng", "Chỉ chấp nhận role=CUSTOMER. Không tạo DRIVER, MERCHANT hoặc ADMIN qua API này. Số điện thoại được chuẩn hóa về +84; mật khẩu 8–72 ký tự. Trả cặp access/refresh token sau khi tạo tài khoản.", "400,409");
        doc("AuthController", "login", "Đăng nhập bằng số điện thoại và mật khẩu", "Trả JWT và refreshToken của một phiên mới. Access token mặc định 3600 giây. Refresh session có hạn cố định mặc định 30 ngày. Không cần access token để gọi.", "400,401");
        doc("AuthController", "refresh", "Đổi refresh token lấy cặp token mới", "Mỗi lần thành công xoay vòng refreshToken; phải thay thế cả hai token ở client. Hạn 30 ngày của phiên không được gia hạn. Dùng lại token cũ sai hash sẽ thu hồi cả phiên và trả 401. Không gửi đồng thời nhiều yêu cầu refresh cùng phiên; nếu mất response xoay vòng có thể phải đăng nhập lại.", "400,401");
        doc("AuthController", "logout", "Thu hồi phiên đăng nhập", "Gửi refreshToken hiện tại trong JSON. Token khớp thì thu hồi phiên; token không khớp hash của một phiên tồn tại không thay đổi phiên. Token sai định dạng/không tìm thấy phiên trả 401. Thành công trả 204, không có body. Access JWT đã cấp vẫn dùng được đến hết hạn; client phải tự xóa token. Đăng xuất offline không bảo đảm thu hồi từ xa.", "400,401");
        doc("RegistrationController", "start", "Bắt đầu đăng ký tài xế và cấp OTP giả lập", "Chỉ hoạt động khi bật mock OTP trong local/docker/test. Mã luôn là 12345, không gửi SMS. OTP có hạn 5 phút, chờ 60 giây trước khi gửi lại. Số điện thoại phải là di động Việt Nam và chưa đăng ký. Mật khẩu 8–72 ký tự. Chưa tạo tài khoản ở bước này; không gửi xác nhận mật khẩu lên backend. Bắt đầu lại thay thế phiên cũ cùng số điện thoại. Có giới hạn số phiên trong RAM.", "400,409");
        doc("RegistrationController", "verify", "Xác minh OTP và tạo tài khoản tài xế", "Gửi registrationId từ bước start và otp=12345. Sau 5 lần thử sai, cần gửi lại mã. Chỉ tạo tài khoản DRIVER sau khi mã đúng; trả cặp token và xóa phiên OTP. Tài khoản mới vẫn phải hoàn thiện hồ sơ và được ADMIN duyệt. Phiên mất sau restart hoặc hết hạn trả 400.", "400,409");
        doc("RegistrationController", "resend", "Cấp lại OTP cho phiên đăng ký", "Cần phiên chưa hết hạn và đã qua 60 giây từ lần cấp trước. Mã vẫn là 12345; đặt lại hạn 5 phút và số lần thử về 0. Sử dụng expiresAt/resendAt mới từ response.", "400,409");

        doc("DriverApplicationController", "get", "Xem hồ sơ đăng ký đối tác của tôi", "Nếu chưa có hồ sơ, tạo bản DRAFT rỗng rồi trả về. Có thể gọi ngay sau xác minh OTP, chưa cần có hồ sơ Driver đang hoạt động. Trạng thái: DRAFT → PENDING_REVIEW → APPROVED.", "");
        doc("DriverApplicationController", "save", "Lưu thông tin hồ sơ đối tác", "Chỉ sửa khi DRAFT. Dù là lưu nháp, request phải đủ các trường bắt buộc: họ tên, ngày sinh trong quá khứ, địa chỉ, CCCD đúng 12 chữ số, loại xe, biển số và số giấy phép lái xe. Không tự chuyển sang chờ duyệt.", "400,409");
        doc("DriverApplicationController", "upload", "Tải ảnh giấy tờ cá nhân", "Gửi multipart/form-data với trường image. type là IDENTITY_FRONT (CCCD trước), IDENTITY_BACK (CCCD sau), VEHICLE_REGISTRATION (đăng ký xe), DRIVING_LICENSE (giấy phép lái xe). Chỉ DRAFT được tải; tải lại cùng loại thay thế tham chiếu ảnh. Chấp nhận ảnh PNG/JPEG không rỗng, tối đa 5 MiB và 25 triệu pixel. Lưu riêng tư, response chỉ có danh sách loại giấy tờ, không có URL công khai.", "400,409,413");
        doc("DriverApplicationController", "submit", "Gửi hồ sơ đối tác để xét duyệt", "Phải lưu thông tin và có đủ 4 loại ảnh giấy tờ. Chuyển DRAFT thành PENDING_REVIEW; gửi lại khi đang chờ duyệt trả hồ sơ hiện có. Hồ sơ đã gửi không thể sửa. Hiện chưa có API từ chối hoặc yêu cầu bổ sung hồ sơ.", "400,409");
        doc("AdminDriverApplicationController", "get", "Xem hồ sơ đối tác theo mã", "ADMIN dùng applicationId lấy từ hồ sơ của tài xế. Hiện không có API danh sách hồ sơ cần duyệt.", "400,404");
        doc("AdminDriverApplicationController", "document", "Tải giấy tờ riêng tư của hồ sơ", "ADMIN tải một giấy tờ theo applicationId và type. Trả dữ liệu nhị phân application/octet-stream, Content-Disposition attachment và Cache-Control no-store. Không trả URL bucket công khai.", "400,404");
        doc("AdminDriverApplicationController", "approve", "Phê duyệt tài xế hoạt động", "Chỉ duyệt hồ sơ PENDING_REVIEW có đủ giấy tờ. Tạo hoặc cập nhật Driver, kích hoạt tài khoản và ghi người duyệt, thời điểm, ghi chú. Gửi JSON {} nếu không có ghi chú. Duyệt lại hồ sơ APPROVED trả hồ sơ hiện tại, không duyệt lại. Không tự bật online.", "400,404,409");

        doc("DriverController", "register", "Tạo hồ sơ tài xế chưa kích hoạt", "API tương thích luồng cũ: tạo Driver cho tài khoản DRIVER hiện tại, active=false. Không thay thế quy trình duyệt đối tác và không cho phép tự kích hoạt. Chỉ tạo một hồ sơ trên mỗi tài khoản. Trả JSON driverId, HTTP 201.", "400,409");
        doc("DriverController", "profile", "Xem hồ sơ tài xế", "Trả thông tin tài xế hiện tại cùng trạng thái tài khoản và online. Tài khoản mới chưa có Driver sẽ nhận 404; dùng API application để hoàn thiện hồ sơ.", "404");
        doc("DriverController", "verifyFace", "Kiểm tra ảnh khuôn mặt giả lập", "Multipart part image phải không rỗng và phải có hồ sơ Driver. Đây chỉ là stub: trả success=true, mode=MOCK_ALWAYS_SUCCESS; KHÔNG phải nhận diện sinh trắc học, không phải bằng chứng danh tính và không kích hoạt tài khoản.", "400,404,413");
        doc("DriverController", "update", "Cập nhật tên và số liên hệ tài xế", "Cập nhật hồ sơ Driver, không thay đổi số điện thoại đăng nhập trong UserAccount và không đổi trạng thái phê duyệt.", "400,404");
        doc("DriverController", "online", "Bật hoặc tắt trạng thái nhận chuyến", "online=true chỉ được chấp nhận khi Driver active (đã được duyệt hoặc là tài xế cũ đang hoạt động). online=false không tự hủy chuyến đang nhận.", "400,404,409");
        doc("DriverController", "session", "Mở phiên cập nhật vị trí mới", "Tạo trackingSessionId mới và vô hiệu phiên cũ; đặt sequence về 0 và xóa vị trí trước đó. Client phải dùng mã phiên mới, sequence bắt đầu từ 1.", "404");
        doc("DriverController", "location", "Cập nhật vị trí có thứ tự", "Phiên phải khớp phiên hiện hành. sequence dương và tăng dần; sequence cũ/trùng trả applied=false, không ghi đè. recordedAt mặc định không cũ quá 30 giây, không vượt tương lai 10 giây và không lùi so với lần trước. Giới hạn độ mới có thể cấu hình. accuracyMeters không âm. applied=true chỉ xác nhận lưu vị trí, không bảo đảm đủ điều kiện thao tác giao hàng.", "400,404,409");

        doc("DriverOfferController", "list", "Danh sách lời mời nhận chuyến còn hạn", "Chỉ trả assignment OFFERED chưa hết expiresAt của tài xế hiện tại. Mảng rỗng nếu không có lời mời. Không phải danh sách tất cả đơn trong hệ thống.", "404");
        doc("DriverOfferController", "refresh", "Bỏ qua lời mời đang xem và tìm chuyến mới", "Bỏ qua các lời mời còn hạn của tài xế có assignmentId trong danh sách gửi lên. Giữ lời mời mới chưa hiển thị và tìm chuyến phù hợp nếu tài xế đang rảnh, online.", "400,404");
        doc("DriverOfferController", "get", "Xem một lời mời nhận chuyến", "id ở đường dẫn là assignmentId, không phải deliveryId. Chỉ xem lời mời thuộc tài xế; kiểm tra canRespond và expiresAt trước khi hiển thị thao tác.", "400,404");
        doc("DriverOfferController", "accept", "Chấp nhận lời mời nhận chuyến", "id là assignmentId. Cần tài xế active, online, chưa có chuyến đang giao; lời mời OFFERED còn hạn và chuyến còn PENDING_ASSIGNMENT. Thành công gán chuyến cho tài xế, chuyển ASSIGNED. Lặp lại khi assignment đã ACCEPTED trả dữ liệu hiện tại.", "400,404,409");
        doc("DriverOfferController", "reject", "Từ chối lời mời nhận chuyến", "id là assignmentId. Chỉ từ chối lời mời OFFERED còn hạn. Không hủy đơn khách; hệ thống có thể mời tài xế khác. Lặp lại khi đã REJECTED trả dữ liệu hiện tại.", "400,404,409");

        doc("DriverDeliveryController", "current", "Lấy chuyến đang thực hiện", "Trả chuyến thuộc tài xế có trạng thái ASSIGNED, AT_PICKUP, PICKED_UP hoặc AT_DROPOFF. Không có chuyến trả 204 không body, không phải lỗi.", "404");
        doc("DriverDeliveryController", "history", "Lịch sử chuyến đã kết thúc", "Phân trang chuyến DELIVERED, FAILED, CANCELLED thuộc tài xế, mới cập nhật trước. Chuyến đã được giải phóng để phân công lại không nằm ở đây; xem danh sách incidents.", "400,404");
        doc("DriverDeliveryController", "historyDetail", "Chi tiết chuyến trong lịch sử", "id là deliveryId. Chỉ trả chuyến kết thúc và còn thuộc tài xế hiện tại.", "400,404");
        doc("DriverDeliveryController", "arrivePickup", "Xác nhận đã đến nhà hàng", "Chuyển ASSIGNED → AT_PICKUP. Phải có vị trí mới, chính xác và gần điểm lấy hàng (mặc định tối đa 30 giây, sai số 50 m, bán kính 200 m; có thể cấu hình). Gọi lại khi AT_PICKUP trả trạng thái hiện tại.", "400,404,409");
        doc("DriverDeliveryController", "pickup", "Xác nhận đã lấy hàng", "Cần AT_PICKUP và đơn hàng READY; kiểm tra vị trí gần nhà hàng. Chuyển chuyến và đơn sang PICKED_UP, ghi pickedUpAt. Không cho lấy hàng khi nhà hàng mới PREPARING. Gọi lại khi PICKED_UP trả dữ liệu hiện tại.", "400,404,409");
        doc("DriverDeliveryController", "arriveDropoff", "Xác nhận đã đến điểm giao", "Chuyển PICKED_UP → AT_DROPOFF; cần vị trí mới, chính xác và gần điểm giao. Gọi lại khi AT_DROPOFF trả dữ liệu hiện tại.", "400,404,409");
        doc("DriverDeliveryController", "deliver", "Xác nhận giao hàng thành công", "Cần AT_DROPOFF và vị trí hợp lệ gần điểm giao. Chuyển DELIVERED và kết thúc assignment. Ghi tiền công đúng một lần nếu có cấu hình dương, nếu không ghi khoản chờ quản trị xác nhận. Không lấy phí giao khách trả làm tiền công. Gọi lại khi DELIVERED không cộng tiền lần nữa.", "400,404,409");
        doc("DriverDeliveryController", "fail", "Báo giao hàng thất bại kèm bằng chứng", "Chỉ khi AT_DROPOFF; assignmentId phải đúng phân công hiện tại. Multipart gồm requestId UUID do client tạo, reason, image bắt buộc và note tối đa 1000 ký tự. PNG/JPEG tối đa 5 MiB, 25 triệu pixel. Chuyển đơn/chuyến sang FAILED. Gửi lại phải giữ nguyên requestId, lý do, ghi chú và nội dung ảnh; khác dữ liệu trả 409.", "400,404,409,413");
        doc("DriverDeliveryController", "report", "Xem báo cáo giao thất bại", "id là deliveryId thuộc tài xế hiện tại. Trả lý do, ghi chú và metadata ảnh. Cache-Control no-store; ảnh tải qua endpoint bảo vệ bằng token.", "400,404");
        doc("DriverDeliveryController", "evidence", "Tải ảnh bằng chứng giao thất bại", "id là deliveryId, không phải reportId. Trả nhị phân PNG/JPEG đúng Content-Type, Cache-Control no-store và X-Content-Type-Options nosniff. Chỉ tài xế sở hữu chuyến được xem.", "400,404");
        doc("DriverDeliveryController", "incident", "Báo sự cố và giải phóng chuyến trước lấy hàng", "Tài xế có thể trả chuyến ASSIGNED/AT_PICKUP khi đơn PREPARING. Chuyến trở về PENDING_ASSIGNMENT. CUSTOMER_UNREACHABLE yêu cầu ảnh cuộc gọi cho khách. RESTAURANT_CLOSED yêu cầu ảnh và vị trí gần quán. Ảnh PNG/JPEG tối đa 5 MiB, 25 triệu pixel. Dùng lại requestId và dữ liệu giống hệt khi thử lại.", "400,404,409,413");
        doc("DriverDeliveryController", "incidents", "Danh sách sự cố đã báo của tôi", "Trả mảng sự cố tài xế đã tạo, mới nhất trước; hiện không phân trang. outcome=PENDING_REASSIGNMENT mô tả kết quả tại lúc giải phóng, không phải trạng thái phân công hiện tại của chuyến.", "404");
        doc("DriverDeliveryController", "incidentEvidence", "Tải ảnh sự cố của tôi", "id là mã sự cố (IncidentResult.id), không phải deliveryId. Chỉ người báo xem được; trả 404 nếu sự cố không có ảnh. Trả nhị phân PNG/JPEG, không cho cache.", "400,404");
        doc("DriverEventController", "subscribe", "Kết nối luồng sự kiện tài xế (SSE)", "Trả text/event-stream, không phải JSON thông thường. Dùng Authorization: Bearer accessToken; EventSource trình duyệt mặc định không hỗ trợ header này, có thể dùng fetch streaming. Sự kiện connected khi mở, heartbeat mỗi 15 giây, orders-changed sau khi dữ liệu liên quan thay đổi; data của mỗi sự kiện là {}. Client phải tải lại offers/current để lấy trạng thái chính thức. Kết nối hết hạn sau khoảng 5 phút: làm mới token nếu cần rồi kết nối lại. Không có event ID/replay/Last-Event-ID; mất kết nối có thể bỏ lỡ sự kiện. Chỉ thông báo trong một instance, không phải message broker đa máy. Swagger UI không phù hợp hiển thị luồng dài; dùng curl -N với header Bearer.", "404");

        doc("DriverAccountController", "settings", "Xem hoặc cập nhật thiết lập nhận chuyến", "GET đọc thiết lập; PUT thay thế đầy đủ thiết lập. Khoảng cách 0.1–100 km, số món 1–5000, mức ứng trước nhà hàng 0–100000000 VND. Các giá trị là bộ lọc nhận chuyến, không phải số tiền đã ứng, số dư hay quyền rút tiền.", "400,404");
        doc("DriverAccountController", "appSettings", "Xem hoặc cập nhật thông báo trong ứng dụng", "GET đọc, PUT cập nhật inAppNotificationsEnabled. Tùy chọn này điều khiển việc tạo thông báo tiền công trong ứng dụng; không khẳng định có push notification, SMS hoặc email.", "400,404");
        doc("DriverAccountController", "wallet", "Xem số dư tiền công", "balance tổng tiền công đã ghi nhận, đơn vị VND, không phải số dư có thể rút. Không gồm tiền thu hộ hoặc nghĩa vụ chờ xác nhận. earningsConfigured chỉ phản ánh cấu hình mức tiền công hiện tại > 0, không phản ánh mọi chuyến quá khứ đã thanh toán. Chưa có API rút tiền.", "404");
        doc("DriverAccountController", "transactions", "Lịch sử giao dịch tiền công", "Phân trang bản ghi tiền công đã xác định, mới nhất trước. type=DELIVERY_EARNING. Không trả giao dịch giả 0 đồng do thiếu cấu hình, không trả khoản chờ xử lý. balanceAfter là số dư ngay sau giao dịch, không phải số dư hiện tại.", "400,404");
        doc("DriverAccountController", "transaction", "Chi tiết một giao dịch tiền công", "id là mã giao dịch, không phải deliveryId. Chỉ xem giao dịch đã xác định thuộc chính tài xế.", "400,404");
        doc("DriverAccountController", "earnings", "Thống kê thu nhập theo ngày, tuần hoặc tháng", "period=DAY/WEEK/MONTH, mặc định DAY; date=yyyy-MM-dd, mặc định ngày hiện tại ở Asia/Ho_Chi_Minh. Tuần từ thứ Hai, tháng từ ngày 1. fromDate/toDate gồm cả hai đầu. chart là số liệu theo NGÀY, không phải theo giờ, gồm cả ngày 0. Chỉ tính tiền công đã ghi nhận theo createdAt; khoản đối soát được tính tại ngày xử lý, không hồi tố ngày giao. completedDeliveries ở đây là số bản ghi tiền công đã xác định, không phải tất cả chuyến thành công đang chờ tiền. Không có thưởng.", "400,404");
        doc("DriverAccountController", "notifications", "Danh sách thông báo của tôi", "Phân trang thông báo mới nhất trước. read=true khi đã đánh dấu đọc; referenceId có thể là deliveryId và có thể rỗng. Thời gian trả ISO-8601, client tự định dạng giờ Việt Nam.", "400,404");
        doc("DriverAccountController", "unread", "Đếm thông báo chưa đọc", "Trả count số thông báo chưa đọc của tài xế hiện tại.", "404");
        doc("DriverAccountController", "read", "Đánh dấu một thông báo đã đọc", "id là notificationId thuộc tài xế. Gọi lại không làm thay đổi thời điểm đã đọc lần đầu; trả thông báo read=true.", "400,404");
        doc("DriverAccountController", "readAll", "Đánh dấu tất cả thông báo đã đọc", "Đánh dấu các thông báo chưa đọc hiện có của tài xế. Thành công trả 204 không body; không xóa thông báo.", "404");
        doc("AdminEarningController", "pending", "Danh sách khoản tiền công chưa xác định", "Chỉ ADMIN. Phân trang nghĩa vụ chưa giải quyết (resolved=false), giao lâu nhất trước. Không có amount vì số tiền chưa được xác nhận; không dùng phí vận chuyển hoặc tự suy ra mức tiền công.", "400");
        doc("AdminEarningController", "reconcile", "Xác nhận và ghi nhận tiền công cho một chuyến", "Chỉ ADMIN; amount phải là số nguyên VND dương, tối đa 12 chữ số và được phê duyệt thực tế. Khóa theo tài xế để tránh ghi trùng; ghi giao dịch, cộng số dư và đánh dấu nghĩa vụ đã xử lý. HTTP 200 không body. Gọi lại khoản đã resolved là no-op, không cộng thêm và không thay thế số tiền trước. Nếu có giao dịch nhưng nghĩa vụ chưa resolved trả 409 để rà soát. Không tự áp dụng cấu hình mới cho chuyến cũ.", "400,404,409");

        doc("CustomerCartController", "get", "Xem giỏ hàng của tôi", "Trả giỏ hiện tại cùng giá và tình trạng khả dụng; giỏ trống có items rỗng. Giỏ chỉ chứa món của một nhà hàng. Đây chưa phải đơn đã đặt. Nếu món đã bị xóa khỏi thực đơn trả 409, cần xóa món đó khỏi giỏ.", "409");
        doc("CustomerCartController", "add", "Thêm món vào giỏ hàng", "Gửi menuItemId, quantity 1–100 và note tối đa 500 ký tự. Nếu đã có món, cộng thêm số lượng, tổng vượt 100 trả 400; ghi chú mới thay ghi chú cũ. Giỏ tối đa 50 dòng món. Món phải khả dụng, nhà hàng đang nhận đơn và cùng nhà hàng với giỏ hiện tại; vi phạm các điều kiện này trả 409. Giá được đọc từ máy chủ, không nhận giá từ client.", "400,404,409");
        doc("CustomerCartController", "update", "Cập nhật số lượng và ghi chú món trong giỏ", "menuItemId là mã món trong giỏ hiện tại; quantity 1–100. Muốn xóa món hãy gọi DELETE, không gửi quantity=0.", "400,404,409");
        doc("CustomerCartController", "remove", "Xóa một món khỏi giỏ", "menuItemId là mã món; món không có trong giỏ cũng thành công. Trả 204 không body.", "400,404");
        doc("CustomerCartController", "clear", "Xóa toàn bộ giỏ hàng", "Chỉ xóa giỏ của khách hiện tại, không hủy đơn đã đặt. Thành công trả 204 không body.", "404");
        doc("CustomerOrderController", "place", "Đặt đơn hàng COD", "Header Idempotency-Key bắt buộc, không trắng, tối đa 100 ký tự, duy nhất theo khách hàng. Gửi lại cùng khóa và cùng request trả đơn cũ (vẫn 201); khác request trả 409. Request trực tiếp chứa 1–50 dòng món, mỗi dòng 1–100 phần, cùng nhà hàng, món khả dụng. Không tự lấy nội dung từ giỏ. Máy chủ chốt giá; phí giao khách trả hiện cố định 15000 VND, KHÔNG phải mức tiền công tài xế. Hiện chỉ hỗ trợ paymentMethod=COD.", "400,404,409");
        doc("CustomerOrderController", "list", "Danh sách đơn hàng của tôi", "Phân trang các đơn của khách đăng nhập, mới tạo trước; không có bộ lọc thời gian ở endpoint này.", "400");
        doc("CustomerOrderController", "detail", "Chi tiết đơn hàng của tôi", "id là orderId. Chỉ chủ đơn được xem; tài nguyên ngoài quyền sở hữu trả 404.", "400,404");
        doc("CustomerOrderController", "tracking", "Theo dõi trạng thái và vị trí tài xế", "Chỉ chủ đơn. driver và driverLocation chỉ được điền khi chuyến đang thực hiện và đã gán tài xế; có thể null trước phân công hoặc sau kết thúc. Vị trí có recordedAt để client kiểm tra độ mới; không khẳng định định vị liên tục theo thời gian thực.", "400,404");
        doc("CustomerOrderController", "cancel", "Khách hàng hủy đơn chưa được nhận", "Khách hủy đơn PENDING bằng lý do tối đa 500 ký tự. Máy chủ lưu CUSTOMER_CANCELLED, hủy chuyến và thu hồi các lời mời nếu đã phân phối sớm. Khách có thể thử lại thao tác đã thành công.", "400,404,409");

        doc("RestaurantOrderController", "list", "Danh sách đơn của nhà hàng", "MERCHANT phải sở hữu restaurantId; không sở hữu trả 404. Có thể lọc status theo enum OrderStatus, phân trang từ 0 và mới tạo trước.", "400,404");
        doc("RestaurantOrderController", "detail", "Chi tiết đơn và thông tin tài xế", "Chỉ nhà hàng thuộc MERCHANT hiện tại, orderId phải thuộc nhà hàng đó. Có thể chưa có tài xế hoặc chuyến (giá trị null).",
            "400,404");
        doc("RestaurantOrderController", "accept", "Nhà hàng nhận đơn và bắt đầu chuẩn bị", "Chuyển PENDING → PREPARING, ước tính thời gian chuẩn bị 1–180 phút, tạo chuyến chờ phân công. Gọi lại khi PREPARING trả hiện trạng, không thay lại thời gian chuẩn bị.", "400,404,409");
        doc("RestaurantOrderController", "reject", "Nhà hàng từ chối đơn mới", "Chỉ PENDING; reason bắt buộc tối đa 500 ký tự. Chuyển REJECTED. Gọi lại khi REJECTED trả hiện trạng.", "400,404,409");
        doc("RestaurantOrderController", "ready", "Báo món đã sẵn sàng lấy", "Chuyển PREPARING → READY, ghi readyAt. Gọi lại khi READY trả hiện trạng. Sau READY, tài xế không được giải phóng chuyến qua báo sự cố trước lấy hàng.", "400,404,409");
        doc("RestaurantOrderController", "cancel", "Nhà hàng hủy đơn đang chuẩn bị", "Áp dụng khi PREPARING. Lưu lý do hủy, hủy chuyến và các lời mời liên quan, gửi cập nhật sau khi giao dịch hoàn tất. Tài xế đã nhận chuyến có thể xem nguồn hủy trong lịch sử.", "400,404,409");
    }

    public static Operation describeOperation(Operation operation, HandlerMethod handler) {
        String controller = handler.getBeanType().getSimpleName();
        Doc doc = OPERATIONS.get(controller + "." + handler.getMethod().getName());
        if (doc == null) return operation;
        String method = handler.getMethod().getName();
        String key = controller + "." + method;
        boolean writingSettings = handler.getMethod().getParameterCount() > 0;
        boolean publicApi = controller.equals("AuthController") || controller.equals("RegistrationController");
        String requiredRole = controller.startsWith("Admin") ? "ADMIN" : controller.startsWith("Customer") ? "CUSTOMER" :
            controller.startsWith("Restaurant") ? "MERCHANT" : "DRIVER";
        String role = publicApi ? "Không cần đăng nhập." : "Yêu cầu quyền **" +
            (controller.startsWith("Admin") ? "ADMIN" : controller.startsWith("Customer") ? "CUSTOMER" :
             controller.startsWith("Restaurant") ? "MERCHANT" : "DRIVER") + "** và Bearer JWT hợp lệ.";
        operation.setSummary(doc.title());
        operation.setDescription(role + "\n\n" + doc.detail());
        if (controller.equals("DriverAccountController") && (method.equals("settings") || method.equals("appSettings"))) {
            operation.setSummary((writingSettings ? "Cập nhật " : "Xem ") + (method.equals("settings") ? "thiết lập nhận chuyến" : "thiết lập thông báo trong ứng dụng"));
            operation.setDescription(role + "\n\n" + (writingSettings
                ? "Gửi thiết lập trong JSON. Máy chủ lưu các giá trị được gửi và trả thiết lập sau cập nhật. "
                : "Trả thiết lập hiện tại của hồ sơ Driver; không cập nhật dữ liệu. ") + (method.equals("settings")
                ? "Các ngưỡng dùng để lọc nhận chuyến, không phải số tiền đã ứng hoặc số dư."
                : "inAppNotificationsEnabled điều khiển việc tạo thông báo tiền công trong ứng dụng, không phải push notification, SMS hoặc email."));
        }
        operation.setTags(List.of(TAGS.get(controller)));
        // Giữ mã ổn định, riêng biệt kể cả hai overload GET/PUT của settings/appSettings.
        operation.setOperationId(controller.replace("Controller", "") + "_" + handler.getMethod().getName()
            + (handler.getMethod().getParameterCount() == 0 ? "" : "_" + handler.getMethod().getParameterCount()));
        if (!publicApi) {
            operation.setSecurity(List.of(new SecurityRequirement().addList("bearerAuth")));
            error(operation, "401", "Chưa đăng nhập, JWT sai hoặc hết hạn. Lỗi bộ lọc bảo mật có thể không có JSON body.", false);
            error(operation, "403", "JWT đã được xác thực nhưng tài khoản không có quyền " + requiredRole + " để " + operation.getSummary().toLowerCase(java.util.Locale.ROOT) + ". Lỗi bảo mật có thể không có JSON body.", false);
        } else operation.setSecurity(List.of());
        EndpointDocumentation.errors(key, writingSettings).forEach((code, description) -> error(operation, code, description, true));
        if (operation.getParameters() != null) operation.getParameters().forEach(p -> {
            p.setDescription(parameterDescription(controller, handler.getMethod().getName(), p.getName()));
            if (p.getSchema() != null && p.getName().equals("page")) p.getSchema().minimum(java.math.BigDecimal.ZERO);
            if (p.getSchema() != null && p.getName().equals("size")) p.getSchema().minimum(java.math.BigDecimal.ONE).maximum(java.math.BigDecimal.valueOf(100));
        });
        if (operation.getRequestBody() != null) operation.getRequestBody().setDescription(EndpointDocumentation.request(key));
        addRequestExample(operation, controller, handler.getMethod().getName());
        if (operation.getResponses() != null) operation.getResponses().forEach((code, response) -> {
            if (code.startsWith("2")) response.setDescription(EndpointDocumentation.success(key, writingSettings));
            if (code.equals("204") || key.equals("AdminEarningController.reconcile") && code.equals("200")) response.setContent(null);
        });
        if (controller.equals("DriverDeliveryController") && handler.getMethod().getName().equals("current"))
            operation.getResponses().addApiResponse("204", new ApiResponse().description("Không có chuyến đang thực hiện; không có body."));
        if (controller.equals("DriverEventController")) operation.getResponses().get("200").setContent(
            new Content().addMediaType("text/event-stream", new MediaType().schema(new Schema<>().type("string"))
                .example("event: connected\ndata: {}\n\nevent: heartbeat\ndata: {}\n\nevent: orders-changed\ndata: {}\n\n")));
        if (handler.getMethod().getName().equals("evidence") || handler.getMethod().getName().equals("incidentEvidence"))
            operation.getResponses().get("200").setContent(new Content()
                .addMediaType("image/png", new MediaType().schema(new Schema<>().type("string").format("binary")))
                .addMediaType("image/jpeg", new MediaType().schema(new Schema<>().type("string").format("binary"))));
        if (controller.equals("AdminDriverApplicationController") && handler.getMethod().getName().equals("document"))
            operation.getResponses().get("200").setContent(new Content().addMediaType("application/octet-stream",
                new MediaType().schema(new Schema<>().type("string").format("binary"))));
        return operation;
    }

    private static void addRequestExample(Operation operation, String controller, String method) {
        if (operation.getRequestBody() == null || operation.getRequestBody().getContent() == null) return;
        var content = operation.getRequestBody().getContent();
        String uuid = "00000000-0000-4000-8000-000000000001";
        Object example = switch (controller + "." + method) {
            case "AuthController.register" -> Map.of("phoneNumber", "0901234567", "password", "MatKhauViDu123!", "role", "CUSTOMER");
            case "AuthController.login", "RegistrationController.start" -> Map.of("phoneNumber", "0901234567", "password", "MatKhauViDu123!");
            case "AuthController.refresh", "AuthController.logout" -> Map.of("refreshToken", "Thay_bang_refreshToken_thuc_te_tu_response");
            case "RegistrationController.verify" -> Map.of("registrationId", uuid, "otp", "12345");
            case "RegistrationController.resend" -> Map.of("registrationId", uuid);
            case "DriverApplicationController.save" -> Map.of("fullName", "Nguyễn Văn An", "birthDate", "1995-05-20",
                "address", "Địa chỉ minh họa", "identityNumber", "012345678901", "vehicleType", "Xe máy",
                "licensePlate", "59A1-12345", "drivingLicense", "GPLX-MINH-HOA");
            case "AdminDriverApplicationController.approve" -> Map.of("note", "Đã kiểm tra đầy đủ hồ sơ");
            case "DriverController.register", "DriverController.update" -> Map.of("fullName", "Nguyễn Văn An", "phoneNumber", "0901234567");
            case "DriverController.online" -> Map.of("online", true);
            case "DriverOfferController.refresh" -> Map.of("skippedAssignmentIds", List.of(uuid));
            case "DriverController.location" -> Map.of("trackingSessionId", uuid, "sequence", 1,
                "latitude", 10.7769, "longitude", 106.7009, "accuracyMeters", 10, "recordedAt", "2026-11-04T03:07:00Z");
            case "DriverAccountController.settings" -> Map.of("autoAcceptEnabled", false, "maxDeliveryDistanceKm", 10,
                "maxItemQuantity", 20, "maxRestaurantAdvanceAmount", 0);
            case "DriverAccountController.appSettings" -> Map.of("inAppNotificationsEnabled", true);
            case "AdminEarningController.reconcile" -> Map.of("amount", 15000);
            case "CustomerCartController.add" -> Map.of("menuItemId", uuid, "quantity", 1, "note", "Ít cay");
            case "CustomerCartController.update" -> Map.of("quantity", 2, "note", "Không hành");
            case "CustomerOrderController.place" -> Map.of("restaurantId", uuid,
                "items", List.of(Map.of("menuItemId", "00000000-0000-4000-8000-000000000002", "quantity", 1, "note", "Ít cay")),
                "recipient", Map.of("name", "Nguyễn Văn An", "phone", "0901234567"),
                "dropoff", Map.of("address", "Địa chỉ giao minh họa", "latitude", 10.7769, "longitude", 106.7009),
                "deliveryNote", "Gọi khi đến nơi", "paymentMethod", "COD");
            case "RestaurantOrderController.cancel" -> Map.of("reasonCode","RESTAURANT_OUT_OF_STOCK","reason","Quán đã hết món");
            case "CustomerOrderController.cancel", "RestaurantOrderController.reject" -> Map.of("reason", "Lý do minh họa, thay bằng lý do thực tế");
            case "RestaurantOrderController.accept" -> Map.of("estimatedPreparationMinutes", 20);
            default -> null;
        };
        if (example != null && content.get("application/json") != null) content.get("application/json").setExample(example);
        if (controller.equals("DriverApplicationController") && method.equals("upload")) {
            var schema = new Schema<>().type("object");
            schema.addProperty("image", new Schema<>().type("string").format("binary").description(FIELDS.get("image")));
            schema.setRequired(List.of("image"));
            operation.getRequestBody().setContent(new Content().addMediaType("multipart/form-data", new MediaType().schema(schema)));
        }
    }

    private static void error(Operation operation, String code, String description, boolean problem) {
        var response = new ApiResponse().description(description);
        if (problem) response.content(new Content().addMediaType("application/problem+json",
            new MediaType().schema(new Schema<>().$ref("#/components/schemas/ApiProblem"))));
        operation.getResponses().addApiResponse(code, response);
    }

    private static String parameterDescription(String controller, String method, String name) {
        return switch (name) {
            case "page" -> "Chỉ số trang, bắt đầu từ 0; mặc định 0.";
            case "size" -> "Số bản ghi mỗi trang, từ 1 đến 100; mặc định 20.";
            case "date" -> "Ngày tham chiếu yyyy-MM-dd theo Asia/Ho_Chi_Minh; bỏ trống dùng ngày hiện tại.";
            case "period" -> "Kỳ thống kê: DAY (ngày), WEEK (tuần từ thứ Hai), MONTH (tháng); mặc định DAY.";
            case "Idempotency-Key" -> "Khóa chống đặt đơn trùng, không trắng, tối đa 100 ký tự; dùng lại cùng nội dung khi retry.";
            case "restaurantId" -> "UUID nhà hàng thuộc MERCHANT hiện tại.";
            case "restaurantName" -> "Tên đầy đủ của nhà hàng, so khớp không phân biệt chữ hoa và chữ thường.";
            case "orderId" -> "UUID đơn hàng thuộc nhà hàng đang thao tác.";
            case "menuItemId" -> "UUID món ăn trong giỏ hiện tại.";
            case "deliveryId" -> "UUID chuyến giao có nghĩa vụ tiền công chờ xác nhận.";
            case "type" -> "Loại giấy tờ: IDENTITY_FRONT, IDENTITY_BACK, VEHICLE_REGISTRATION hoặc DRIVING_LICENSE.";
            case "status" -> "Lọc chính xác theo trạng thái đơn; bỏ trống để lấy mọi trạng thái.";
            case "id" -> controller.equals("DriverOfferController") ? "UUID phân công/lời mời (assignmentId), không phải deliveryId."
                : controller.contains("Application") ? "UUID hồ sơ đối tác (applicationId)."
                : controller.equals("CustomerOrderController") ? "UUID đơn hàng của khách (orderId)."
                : controller.equals("DriverAccountController") ? (method.equals("read") ? "UUID thông báo của tôi." : "UUID giao dịch tiền công của tôi.")
                : method.equals("incidentEvidence") ? "UUID bản ghi sự cố, không phải deliveryId." : "UUID chuyến giao (deliveryId).";
            default -> FIELDS.getOrDefault(name, "Tham số " + name + "; xem quy tắc trong mô tả thao tác.");
        };
    }

    private static final Map<String, String> FIELDS = new LinkedHashMap<>();
    private static void fields(String description, String... names) { for (String name : names) FIELDS.put(name, description); }
    static {
        fields("Số di động Việt Nam; đăng nhập/đăng ký chấp nhận đầu 0 hoặc +84 và chuẩn hóa về +84. Trường liên hệ trong hồ sơ không tự đổi số đăng nhập.", "phoneNumber");
        fields("Mật khẩu dạng chuỗi; đăng ký 8–72 ký tự. Không gửi trường xác nhận mật khẩu và không ghi mật khẩu vào log.", "password");
        fields("Quyền tài khoản: CUSTOMER (khách), DRIVER (tài xế), MERCHANT (nhà hàng), ADMIN (quản trị). Đăng ký công khai trực tiếp chỉ cho CUSTOMER.", "role");
        fields("JWT truy cập, dùng trong header Authorization: Bearer <accessToken>.", "accessToken");
        fields("Loại token, hiện là Bearer.", "tokenType");
        fields("Thời hạn access token tính bằng giây kể từ khi cấp; mặc định 3600.", "expiresIn");
        fields("Refresh token bí mật. Xoay vòng sau mỗi lần làm mới; thay thế bản cũ ngay khi nhận response.", "refreshToken");
        fields("UUID tài khoản đăng nhập, khác với driverId.", "userId");
        fields("UUID tài xế, không phải UUID tài khoản đăng nhập.", "driverId");
        fields("UUID hồ sơ đăng ký đối tác; dùng cho quản trị xét duyệt.", "applicationId");
        fields("UUID phiên đăng ký tạm trong RAM; mất khi backend khởi động lại.", "registrationId");
        fields("Mã OTP giả lập 5 chữ số, luôn 12345 trong môi trường phát triển.", "otp", "devOtp");
        fields("Chế độ giả lập trả về: MOCK_DEVELOPMENT_ONLY cho OTP hoặc MOCK_ALWAYS_SUCCESS cho ảnh khuôn mặt; không chứng minh xác thực thực tế.", "mode");
        fields("Thời điểm hết hạn ISO-8601. OTP có hạn 5 phút; lời mời có hạn theo cấu hình điều phối.", "expiresAt");
        fields("Thời điểm sớm nhất được gửi lại OTP, 60 giây sau lần cấp trước.", "resendAt");
        fields("UUID chuyến giao hàng; khác orderId và assignmentId.", "deliveryId");
        fields("UUID phân công tài xế/lời mời nhận chuyến. Mỗi lần phân công lại có thể thay đổi.", "assignmentId");
        fields("Danh sách mã lời mời tài xế muốn bỏ qua khi tìm chuyến mới.", "skippedAssignmentIds");
        fields("UUID yêu cầu do client tạo, giữ nguyên khi thử lại cùng thao tác và cùng nội dung.", "requestId");
        fields("UUID đơn hàng của khách.", "orderId");
        fields("UUID nhà hàng.", "restaurantId");
        fields("Tên nhà hàng tại thời điểm đặt đơn.", "restaurantName");
        fields("Giá một phần món đang bán tại nhà hàng, đơn vị VND.", "price");
        fields("UUID món ăn trong thực đơn.", "menuItemId");
        fields("UUID phiên theo dõi vị trí hiện hành; phiên mới vô hiệu phiên trước.", "trackingSessionId");
        fields("Số thứ tự vị trí dương và tăng dần trong một phiên; trùng/cũ bị bỏ qua.", "sequence");
        fields("Số thứ tự vị trí mới nhất máy chủ đang giữ.", "currentSequence");
        fields("true nếu vị trí được áp dụng; false nếu sequence không mới hơn.", "applied");
        fields("Vĩ độ theo độ thập phân, từ -90 đến 90.", "latitude");
        fields("Kinh độ theo độ thập phân, từ -180 đến 180.", "longitude");
        fields("Độ chính xác GPS tính bằng mét, không âm; số nhỏ hơn thể hiện vị trí chính xác hơn.", "accuracyMeters");
        fields("Thời điểm thiết bị ghi nhận vị trí ISO-8601, phải đủ mới và không lùi thời gian.", "recordedAt");
        fields("Họ và tên tài xế, tối đa 150 ký tự.", "fullName");
        fields("Ngày sinh yyyy-MM-dd, phải trong quá khứ.", "birthDate");
        fields("Địa chỉ văn bản, tối đa 500 ký tự trong request.", "address");
        fields("Số căn cước công dân đúng 12 chữ số; là dữ liệu cá nhân nhạy cảm.", "identityNumber");
        fields("Loại phương tiện, tối đa 50 ký tự.", "vehicleType");
        fields("Biển số xe, tối đa 20 ký tự.", "licensePlate");
        fields("Số giấy phép lái xe, tối đa 30 ký tự.", "drivingLicense");
        fields("Tập các loại giấy tờ đã tải lên; không chứa ảnh hay URL công khai.", "documents");
        fields("Ghi chú duyệt hồ sơ, tối đa 1000 ký tự; có thể rỗng.", "reviewNote");
        fields("UUID quản trị đã xử lý; null nếu chưa xử lý.", "reviewedBy", "resolvedBy");
        fields("Trạng thái tài khoản tài xế: ACTIVE (đang được kích hoạt) hoặc SUSPENDED (chưa kích hoạt/bị ngừng hoạt động).", "accountStatus");
        fields("Trạng thái nhận chuyến: ONLINE hoặc OFFLINE.", "onlineStatus");
        fields("true để bật nhận chuyến, false để tắt; chỉ tài xế active được bật.", "online");
        fields("Kết quả kiểm tra giả lập; không phải kết quả nhận diện sinh trắc học.", "success");
        fields("Tùy chọn tự động nhận chuyến được lưu trong hồ sơ; hiện chưa tự accept lời mời, tài xế vẫn phải gọi API accept.", "autoAcceptEnabled");
        fields("Khoảng cách giao tối đa, đơn vị km; từ 0.1 đến 100.", "maxDeliveryDistanceKm");
        fields("Tổng số phần món tối đa cho một đơn, từ 1 đến 5000.", "maxItemQuantity");
        fields("Ngưỡng tiền ứng nhà hàng theo bộ lọc, 0–100000000 VND; không phải số tiền đã ứng.", "maxRestaurantAdvanceAmount");
        fields("Bật/tắt việc tạo thông báo trong ứng dụng; không phải cấu hình push/SMS.", "inAppNotificationsEnabled");
        fields("Số dư tiền công đã ghi nhận, đơn vị VND; không gồm khoản chờ xác nhận và không cam kết có thể rút.", "balance");
        fields("Số dư tiền công ngay sau giao dịch này, không phải số dư hiện tại.", "balanceAfter");
        fields("Mã tiền tệ, hiện là VND.", "currency");
        fields("true khi cấu hình mức tiền công mỗi chuyến hiện tại lớn hơn 0; không nói lên tình trạng từng khoản quá khứ.", "earningsConfigured");
        fields("Số tiền nguyên VND dương do ADMIN xác nhận (1–999999999999) trong request đối soát; trong giao dịch là tiền công thực đã ghi nhận.", "amount");
        fields("Kỳ thống kê DAY, WEEK hoặc MONTH.", "period");
        fields("Ngày bắt đầu kỳ, có tính ngày này.", "fromDate");
        fields("Ngày cuối kỳ, có tính ngày này.", "toDate");
        fields("Múi giờ thống kê, Asia/Ho_Chi_Minh.", "timezone");
        fields("Số bản ghi tiền công đã xác định trong kỳ/ngày, không bao gồm chuyến còn chờ xác nhận tiền.", "completedDeliveries");
        fields("Tổng tiền công đã ghi nhận trong kỳ, đơn vị VND; không có thưởng hoặc tiền thu hộ.", "totalEarnings");
        fields("Danh sách điểm biểu đồ theo ngày, bao gồm ngày không có thu nhập.", "chart");
        fields("Ngày thống kê yyyy-MM-dd theo múi giờ Việt Nam.", "date");
        fields("Tiền công đã ghi nhận của ngày, VND.", "earnings");
        fields("Số lượng thông báo chưa đọc.", "count");
        fields("true nếu thông báo đã được đánh dấu đọc.", "read");
        fields("Tiêu đề thông báo hoặc tiêu đề lỗi HTTP.", "title");
        fields("Nội dung thông báo hiển thị cho tài xế.", "message");
        fields("UUID tham chiếu của thông báo, thường là deliveryId, có thể null.", "referenceId");
        fields("Mô tả giao dịch tiền công.", "description");
        fields("UUID tài nguyên hiện tại: giao dịch, thông báo hoặc sự cố tùy schema.", "id");
        fields("Loại bản ghi: giao dịch hiện là DELIVERY_EARNING, thông báo hiện là DELIVERY_COMPLETED; trong lỗi là URI loại lỗi.", "type");
        fields("Trạng thái nghiệp vụ theo schema; xem enum hoặc mô tả quy trình. Đây không phải thông báo dành cho người dùng.", "status");
        fields("Lý do nghiệp vụ: enum khi báo sự cố/thất bại; chuỗi bắt buộc tối đa 500 ký tự khi hủy/từ chối đơn.", "reason");
        fields("Ghi chú tùy chọn; món tối đa 500 ký tự, sự cố/thất bại/duyệt hồ sơ tối đa 1000 ký tự.", "note");
        fields("Tệp ảnh nhị phân gửi multipart; PNG/JPEG tối đa 5 MiB và 25 triệu pixel với giấy tờ/bằng chứng. Xem mô tả riêng của API ảnh khuôn mặt giả lập.", "image");
        fields("UUID báo cáo giao hàng thất bại.", "reportId");
        fields("Kết quả giải phóng tại thời điểm báo sự cố: PENDING_REASSIGNMENT; không phải trạng thái hiện tại.", "outcome");
        fields("Metadata bằng chứng; tải ảnh bằng endpoint riêng có xác thực.", "evidence");
        fields("MIME của ảnh, image/png hoặc image/jpeg.", "contentType");
        fields("Dung lượng tệp ảnh tính bằng byte.", "sizeBytes");
        fields("Đường dẫn API tải ảnh có bảo vệ JWT, không phải URL bucket công khai.", "url");
        fields("Thông tin điểm lấy hàng từ địa chỉ nhà hàng tại thời điểm đặt đơn.", "pickup");
        fields("Thông tin điểm giao hàng do khách cung cấp.", "dropoff");
        fields("Thông tin người nhận hàng.", "recipient");
        fields("Thông tin liên hệ nhà hàng.", "restaurant");
        fields("Thông tin tài xế; có thể null nếu chưa phân công hoặc không trong chuyến đang thực hiện.", "driver");
        fields("Vị trí gần nhất của tài xế, có thể null; kiểm tra recordedAt để đánh giá độ mới.", "driverLocation");
        fields("Trạng thái đơn hàng, độc lập trạng thái chuyến giao.", "orderStatus");
        fields("Trạng thái chuyến giao, có thể null khi chưa tạo chuyến.", "deliveryStatus");
        fields("Danh sách phần tử trong response phân trang, món trong giỏ hoặc món của đơn tùy schema.", "items");
        fields("Chỉ số trang hiện tại, bắt đầu từ 0.", "page");
        fields("Kích thước trang yêu cầu, từ 1 đến 100; không phải tổng số phần tử.", "size");
        fields("true nếu còn trang tiếp theo; không có totalElements/totalPages.", "hasNext");
        fields("Tên người nhận, nhà hàng hoặc món ăn tùy schema. Tên người nhận tối đa 150 ký tự.", "name");
        fields("Số điện thoại liên hệ; số người nhận bắt buộc, tối đa 20 ký tự.", "phone");
        fields("Số phần món, từ 1 đến 100 trong request.", "quantity");
        fields("Đơn giá món do máy chủ xác định, đơn vị VND.", "unitPrice");
        fields("Thành tiền món bằng đơn giá nhân số lượng, VND.", "lineTotal");
        fields("Món có đang khả dụng để đặt hay không.", "available");
        fields("Tổng tiền món chưa gồm phí giao, VND.", "subtotal");
        fields("Phí giao hàng khách phải trả, VND; không được coi là tiền công tài xế.", "deliveryFee");
        fields("Tổng khách thanh toán = subtotal + deliveryFee, VND; không phải thu nhập tài xế.", "total");
        fields("Ghi chú giao hàng của khách, tối đa 1000 ký tự.", "deliveryNote");
        fields("Phương thức thanh toán, hiện chỉ COD (thu tiền khi giao).", "paymentMethod", "method");
        fields("Thông tin thanh toán và số tiền cần thu của khách; không phải tiền công.", "payment");
        fields("Tiền phải thu từ khách (COD), VND; đây là tiền thu hộ, không phải thu nhập tài xế.", "amountToCollect");
        fields("Thời gian chuẩn bị dự kiến tính bằng phút, số nguyên từ 1 đến 180.", "estimatedPreparationMinutes");
        fields("Có thể phản hồi lời mời tại thời điểm đọc; server vẫn kiểm tra hạn/trạng thái lúc nhận yêu cầu.", "canRespond");
        fields("Lý do đơn bị hủy hoặc bị từ chối; có thể null.", "cancellationReason");
        fields("Mã nguồn hủy để tài xế nhận biết khách đổi ý, quán hết món hoặc sự cố khác tại quán. Có thể null với đơn cũ.", "cancellationCode");
        fields("Mã lý do quán hủy đơn đang chuẩn bị. Chọn RESTAURANT_OUT_OF_STOCK (mặc định) hoặc RESTAURANT_ISSUE.", "reasonCode");
        fields("Nghĩa vụ đã được quản trị xác nhận tiền công hay chưa.", "resolved");
        fields("Đơn hàng kèm snapshot giá và thông tin giao nhận.", "order");
        for (String name : List.of("createdAt", "updatedAt", "startedAt", "submittedAt", "reviewedAt", "resolvedAt",
                "checkedAt", "offeredAt", "respondedAt", "pickedUpAt", "deliveredAt", "failedAt", "estimatedReadyAt", "readyAt")) {
            FIELDS.put(name, switch (name) {
                case "createdAt" -> "Thời điểm tạo bản ghi ISO-8601. Tiền công đối soát dùng thời điểm xử lý, không hồi tố ngày giao.";
                case "updatedAt" -> "Thời điểm cập nhật gần nhất ISO-8601.";
                case "deliveredAt" -> "Thời điểm giao thành công ISO-8601; nghĩa vụ tiền công giữ lại thời điểm giao gốc.";
                default -> "Thời điểm " + switch (name) {
                    case "startedAt" -> "mở phiên vị trí"; case "submittedAt" -> "gửi hồ sơ";
                    case "reviewedAt" -> "duyệt hồ sơ"; case "resolvedAt" -> "xác nhận tiền công";
                    case "checkedAt" -> "kiểm tra giả lập"; case "offeredAt" -> "gửi lời mời";
                    case "respondedAt" -> "phản hồi lời mời"; case "pickedUpAt" -> "lấy hàng";
                    case "failedAt" -> "giao thất bại"; case "estimatedReadyAt" -> "dự kiến món sẵn sàng";
                    default -> "món sẵn sàng";
                } + " ISO-8601, có thể null nếu chưa xảy ra.";
            });
        }
    }

    @SuppressWarnings({"rawtypes", "unchecked"})
    public static void describeSchemas(OpenAPI api) {
        Schema problem = new Schema<>().type("object").description("Lỗi nghiệp vụ/validation theo ProblemDetail; lỗi bộ lọc bảo mật không bảo đảm schema này.");
        problem.addProperty("type", new Schema<>().type("string").description("URI loại lỗi, thường about:blank.").example("about:blank"));
        problem.addProperty("title", new Schema<>().type("string").description("Tiêu đề tương ứng HTTP status của response."));
        problem.addProperty("status", new Schema<>().type("integer").description("Mã HTTP thực tế của response lỗi, không cố định là 400."));
        problem.addProperty("detail", new Schema<>().type("string").description("Chi tiết lỗi thực tế do backend trả; có thể tiếng Anh, không phải bản dịch trong tài liệu."));
        problem.addProperty("instance", new Schema<>().type("string").description("Đường dẫn yêu cầu gây lỗi, có thể không có."));
        problem.addProperty("errors", new io.swagger.v3.oas.models.media.ArraySchema().items(new Schema<>().type("string"))
            .description("Danh sách lỗi từng trường, chỉ có khi validation request body."));
        api.getComponents().addSchemas("ApiProblem", problem);
        api.getComponents().getSchemas().forEach((name, schema) -> {
            if (!name.equals("ApiProblem")) {
                if (schema.getDescription() == null) schema.setDescription("Cấu trúc dữ liệu " + name.substring(name.lastIndexOf('.') + 1) + ". Giới hạn validation thể hiện ở từng trường; không đổi tên trường khi gửi JSON.");
                describeProperties(schema, name);
            }
        });
        // Multipart schema có thể được springdoc đặt inline, thay vì trong components.
        api.getPaths().values().forEach(path -> path.readOperations().forEach(op -> {
            if (op.getRequestBody() != null && op.getRequestBody().getContent() != null)
                op.getRequestBody().getContent().values().forEach(media -> {
                    describeProperties(media.getSchema(), "multipart");
                    if (media.getSchema() != null && media.getSchema().getProperties() != null) {
                        var reason = (Schema) media.getSchema().getProperties().get("reason");
                        if (reason != null && op.getOperationId().startsWith("DriverDelivery_incident_")) reason.setDescription(
                            "Chọn PERSONAL, VEHICLE_BREAKDOWN, BAD_WEATHER, RESTAURANT_DELAY, RESTAURANT_CLOSED hoặc CUSTOMER_UNREACHABLE. Khách không nghe máy yêu cầu ảnh cuộc gọi. Quán đóng cửa yêu cầu ảnh và vị trí gần quán.");
                        if (reason != null && op.getOperationId().startsWith("DriverDelivery_fail_")) reason.setDescription(
                            "Lý do giao thất bại: CUSTOMER_UNREACHABLE (không liên lạc được khách), CUSTOMER_REFUSED (khách từ chối), OTHER (khác).");
                    }
                });
        }));
    }

    @SuppressWarnings({"rawtypes", "unchecked"})
    private static void describeProperties(Schema schema, String schemaName) {
        if (schema == null || schema.getProperties() == null) return;
        Map<String, Schema> properties = schema.getProperties();
        properties.forEach((name, field) -> {
            if (FIELDS.containsKey(name)) field.setDescription(FIELDS.get(name));
            if (name.equals("status")) {
                if (schemaName.contains("DriverApplicationService")) field.setDescription("Trạng thái hồ sơ: DRAFT (nháp), PENDING_REVIEW (chờ duyệt), APPROVED (đã duyệt).");
                else if (schemaName.endsWith("Offer")) field.setDescription("Trạng thái phân công: OFFERED, ACCEPTED, REJECTED, EXPIRED, COMPLETED, FAILED, CANCELLED, RELEASED.");
                else if (schemaName.endsWith("Current")) field.setDescription("Trạng thái chuyến: PENDING_ASSIGNMENT → ASSIGNED → AT_PICKUP → PICKED_UP → AT_DROPOFF → DELIVERED; có thể FAILED hoặc CANCELLED.");
                else if (schemaName.endsWith("OrderResponse")) field.setDescription("Trạng thái đơn: PENDING (chờ nhà hàng), PREPARING (chuẩn bị), READY (sẵn sàng), PICKED_UP (đã lấy), DELIVERED (đã giao), REJECTED (từ chối), CANCELLED (hủy), FAILED (giao thất bại).");
            }
            if (name.equals("reason") && schemaName.endsWith("IncidentResult")) field.setDescription(
                "Lý do giải phóng chuyến gồm PERSONAL, VEHICLE_BREAKDOWN, BAD_WEATHER, RESTAURANT_DELAY, RESTAURANT_CLOSED và CUSTOMER_UNREACHABLE.");
            if (name.equals("reason") && schemaName.endsWith("Report")) field.setDescription(
                "Lý do giao thất bại: CUSTOMER_UNREACHABLE (không liên lạc được khách), CUSTOMER_REFUSED (khách từ chối), OTHER (lý do khác).");
            if (name.equals("reason") && schemaName.equals("multipart")) field.setDescription(
                "Trước khi lấy hàng chọn PERSONAL, VEHICLE_BREAKDOWN, BAD_WEATHER, RESTAURANT_DELAY, RESTAURANT_CLOSED hoặc CUSTOMER_UNREACHABLE. " +
                "giao thất bại: CUSTOMER_UNREACHABLE (không liên lạc được), CUSTOMER_REFUSED (khách từ chối), OTHER (khác). Chọn enum đúng endpoint.");
            if (name.equals("phoneNumber")) field.setExample("0901234567");
            if (name.equals("otp") || name.equals("devOtp")) field.setExample("12345");
            if (name.equals("password")) { field.setWriteOnly(true); field.setExample("MatKhauViDu123!"); }
            if (name.equals("birthDate")) field.setExample("1995-05-20");
            if (name.equals("identityNumber")) field.setExample("012345678901");
        });
    }
}
