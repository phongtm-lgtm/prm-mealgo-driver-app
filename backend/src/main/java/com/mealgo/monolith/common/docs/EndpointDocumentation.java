package com.mealgo.monolith.common.docs;

import java.util.LinkedHashMap;
import java.util.Map;

/** Mô tả theo nhánh xử lý thực tế của controller/service; không định nghĩa thêm hành vi API. */
final class EndpointDocumentation {
    private EndpointDocumentation() {}

    private record Contract(String success, String request, Map<String, String> errors) {}
    private static final Map<String, Contract> CONTRACTS = new LinkedHashMap<>();
    private static final String PAGING = "page không phải số nguyên hoặc nhỏ hơn 0; size không phải số nguyên hoặc ngoài khoảng 1–100.";
    private static final String DRIVER = "Không tìm thấy hồ sơ Driver của tài khoản đang đăng nhập.";
    private static final String DELIVERY = DRIVER + " Hoặc không tìm thấy chuyến giao thuộc tài xế hiện tại, hoặc đơn hàng liên quan không tồn tại.";
    private static final String OFFER = DRIVER + " Hoặc assignmentId không tồn tại/không thuộc tài xế, hoặc chuyến giao/đơn hàng liên quan không tồn tại.";
    private static final String ORDER = "Không tìm thấy orderId hoặc đơn hàng không thuộc khách hàng hiện tại.";
    private static final String RESTAURANT = "Không tìm thấy restaurantId hoặc nhà hàng không thuộc MERCHANT hiện tại; với thao tác trên đơn, orderId không tồn tại hoặc không thuộc nhà hàng này.";
    private static final String IMAGE = "image rỗng, vượt 5 MiB, không giải mã được thành PNG/JPEG hoặc vượt 25 triệu pixel.";
    private static final String UPLOAD = "Vượt giới hạn multipart của máy chủ: tối đa 5 MB mỗi tệp hoặc 6 MB toàn yêu cầu. Ảnh bị service từ chối sau khi tiếp nhận trả 400.";
    private static final String GPS = "Vị trí GPS thiếu, quá cũ, sai số vượt ngưỡng hoặc nằm ngoài bán kính cho phép tại điểm cần xác nhận.";
    private static final String PROFILE = "JSON gồm fullName không trắng (tối đa 150 ký tự) và phoneNumber không trắng (tối đa 20 ký tự). Đây là số liên hệ, không thay số đăng nhập.";
    private static final String PROFILE_ERROR = "Thiếu/sai JSON; fullName trống hoặc quá 150 ký tự; phoneNumber trống hoặc quá 20 ký tự.";

    private static void contract(String key, String success, String request, String... errors) {
        Map<String, String> responses = new LinkedHashMap<>();
        for (int i = 0; i < errors.length; i += 2) responses.put(errors[i], errors[i + 1]);
        CONTRACTS.put(key, new Contract(success, request, responses));
    }

    static {
        contract("AuthController.register", "Tạo tài khoản CUSTOMER và phiên đăng nhập; body chứa accessToken, tokenType, expiresIn, userId, role và refreshToken.",
            "JSON gồm phoneNumber (số di động Việt Nam, tối đa 32 ký tự), password (8–72 ký tự) và role=CUSTOMER.",
            "400", "Thiếu/sai JSON; phoneNumber trống, quá 32 ký tự hoặc không phải số di động Việt Nam; password ngoài 8–72 ký tự; role thiếu, sai enum hoặc khác CUSTOMER.",
            "409", "Số điện thoại sau chuẩn hóa đã được đăng ký; hoặc dữ liệu tạo tài khoản/phiên vi phạm ràng buộc lưu trữ.");
        contract("AuthController.login", "Xác thực tài khoản và tạo phiên mới; body chứa cặp token, thời hạn access token, userId và role.",
            "JSON gồm phoneNumber (không trắng, tối đa 32 ký tự) và password (không trắng, tối đa 72 ký tự).",
            "400", "Thiếu/sai JSON; phoneNumber trống, quá 32 ký tự hoặc không phải số di động Việt Nam; password trống hoặc quá 72 ký tự.",
            "401", "Không có tài khoản ứng với số điện thoại đã chuẩn hóa hoặc password không khớp mật khẩu đã lưu.");
        contract("AuthController.refresh", "Xoay vòng token trong phiên hiện tại; body chứa accessToken và refreshToken mới cùng thông tin tài khoản. Client phải thay thế token cũ.",
            "JSON gồm refreshToken hiện tại, không trắng và tối đa 200 ký tự; không dùng accessToken tại đây.",
            "400", "Thiếu/sai JSON; refreshToken trống hoặc dài quá 200 ký tự.",
            "401", "refreshToken sai định dạng, không tìm thấy phiên/tài khoản, phiên hết hạn hoặc đã bị thu hồi; token không khớp hash hiện tại cũng bị từ chối.");
        contract("AuthController.logout", "Đã xử lý yêu cầu thu hồi phiên. Không có response body; token không khớp hash của phiên tồn tại cũng trả 204 nhưng không thu hồi phiên đó.",
            "JSON gồm refreshToken của phiên cần đăng xuất, không trắng và tối đa 200 ký tự.",
            "400", "Thiếu/sai JSON; refreshToken trống hoặc quá 200 ký tự.",
            "401", "refreshToken sai định dạng hoặc không tìm thấy phiên đăng nhập tương ứng.");
        contract("RegistrationController.start", "Tạo phiên OTP giả lập, chưa tạo tài khoản; body gồm registrationId, mode, devOtp, expiresAt và resendAt.",
            "JSON gồm phoneNumber là số di động Việt Nam và password dài 8–72 ký tự. Không gửi trường xác nhận mật khẩu.",
            "400", "Mock OTP chưa được bật; thiếu/sai JSON, phoneNumber trống/không phải số di động Việt Nam hoặc password ngoài 8–72 ký tự.",
            "409", "Số điện thoại đã đăng ký, chưa qua 60 giây từ lần gửi trước hoặc bộ nhớ phiên đăng ký đã đạt giới hạn.");
        contract("RegistrationController.verify", "OTP hợp lệ: tạo tài khoản DRIVER, xóa phiên OTP và trả body token đăng nhập. Tài khoản chưa được phê duyệt hoạt động.",
            "JSON gồm registrationId UUID từ start và otp không trắng; mã giả lập hiện là 12345.",
            "400", "registrationId thiếu/sai UUID; otp trống hoặc không đúng; phiên OTP không tồn tại, đã hết hạn hoặc bị mất sau khởi động lại.",
            "409", "Phiên đã đạt 5 lần thử OTP sai hoặc số điện thoại đã được đăng ký trước khi xác minh hoàn tất.");
        contract("RegistrationController.resend", "Cấp lại mã giả lập cho phiên; body gồm registrationId, mode, devOtp, expiresAt và resendAt mới; đặt lại số lần thử sai.",
            "JSON gồm registrationId UUID của phiên OTP còn hiệu lực.",
            "400", "Thiếu/sai JSON hoặc registrationId; phiên OTP không tồn tại hoặc hết hạn.",
            "409", "Chưa qua 60 giây kể từ lần cấp OTP trước của phiên này.");

        contract("DriverApplicationController.get", "Trả body hồ sơ đối tác hiện tại; nếu chưa có thì tạo hồ sơ DRAFT và trả hồ sơ mới.", null);
        contract("DriverApplicationController.save", "Lưu thông tin và trả body hồ sơ DRAFT; không tự gửi xét duyệt.",
            "JSON gồm fullName, birthDate, address, identityNumber, vehicleType, licensePlate và drivingLicense; phải đủ trường bắt buộc ngay cả khi lưu nháp.",
            "400", "Thiếu/sai JSON; fullName trống/quá 150 ký tự; birthDate thiếu hoặc không trong quá khứ; address trống/quá 500; identityNumber không đúng 12 chữ số; vehicleType trống/quá 50; licensePlate trống/quá 20; drivingLicense trống/quá 30 ký tự.",
            "409", "Hồ sơ không còn DRAFT nên không được chỉnh sửa.");
        contract("DriverApplicationController.upload", "Lưu ảnh riêng tư và trả body hồ sơ với documents đã cập nhật; tải cùng type thay tham chiếu ảnh trước, không trả URL ảnh công khai.",
            "multipart/form-data gồm image bắt buộc; type ở đường dẫn chỉ nhận IDENTITY_FRONT, IDENTITY_BACK, VEHICLE_REGISTRATION hoặc DRIVING_LICENSE.",
            "400", "type không thuộc 4 loại giấy tờ được hỗ trợ; thiếu image; " + IMAGE,
            "409", "Hồ sơ không còn DRAFT nên không được thay giấy tờ.", "413", UPLOAD,
            "503", "Kho lưu trữ giấy tờ không khả dụng khi ghi ảnh.");
        contract("DriverApplicationController.submit", "Trả body hồ sơ PENDING_REVIEW và submittedAt; nếu đã PENDING_REVIEW thì trả hồ sơ hiện tại.", null,
            "400", "Chưa lưu fullName hoặc chưa có đủ IDENTITY_FRONT, IDENTITY_BACK, VEHICLE_REGISTRATION và DRIVING_LICENSE.",
            "409", "Hồ sơ đã APPROVED hoặc không còn ở trạng thái cho phép gửi xét duyệt.");
        contract("AdminDriverApplicationController.get", "Trả body hồ sơ đối tác ứng với applicationId, gồm thông tin cá nhân, loại giấy tờ đã tải và dữ liệu xét duyệt.", null,
            "400", "id không phải UUID hợp lệ.", "404", "Không tìm thấy hồ sơ đối tác ứng với applicationId.");
        contract("AdminDriverApplicationController.document", "Trả byte của giấy tờ dưới dạng application/octet-stream, tải về dạng attachment và không lưu cache; không có JSON body.", null,
            "400", "id không phải UUID hợp lệ.", "404", "Không tìm thấy hồ sơ đối tác hoặc hồ sơ chưa có giấy tờ theo type được yêu cầu (kể cả type không được lưu).",
            "503", "Không đọc được giấy tờ từ kho lưu trữ riêng tư.");
        contract("AdminDriverApplicationController.approve", "Trả body hồ sơ APPROVED sau khi tạo/cập nhật Driver và đặt active=true; hồ sơ đã APPROVED được trả lại mà không duyệt lần nữa.",
            "JSON gồm note tùy chọn, tối đa 1000 ký tự. Gửi {} nếu không có ghi chú; request body vẫn bắt buộc.",
            "400", "id sai UUID; thiếu/sai JSON hoặc note quá 1000 ký tự.", "404", "Không tìm thấy hồ sơ đối tác cần phê duyệt.",
            "409", "Hồ sơ chưa PENDING_REVIEW, thiếu fullName hoặc thiếu loại giấy tờ bắt buộc.");

        contract("DriverController.register", "Tạo hồ sơ Driver chưa kích hoạt; body JSON chứa driverId của hồ sơ vừa tạo.", PROFILE,
            "400", PROFILE_ERROR, "409", "Tài khoản hiện tại đã có hồ sơ Driver.");
        contract("DriverController.profile", "Trả body hồ sơ Driver gồm driverId, thông tin liên hệ, accountStatus, onlineStatus và thời điểm tạo/cập nhật.", null, "404", DRIVER);
        contract("DriverController.verifyFace", "Trả body success=true, mode=MOCK_ALWAYS_SUCCESS và checkedAt; không xác minh sinh trắc học hoặc kích hoạt tài khoản.",
            "multipart/form-data với part image bắt buộc, không rỗng. Stub hiện chỉ kiểm tra ảnh không rỗng, không kiểm tra PNG/JPEG hoặc số pixel.",
            "400", "Thiếu multipart part image hoặc image rỗng.", "404", DRIVER, "413", UPLOAD);
        contract("DriverController.update", "Cập nhật và trả body hồ sơ Driver; số điện thoại đăng nhập và trạng thái kích hoạt không thay đổi.", PROFILE,
            "400", PROFILE_ERROR, "404", DRIVER);
        contract("DriverController.online", "Trả body hồ sơ Driver với onlineStatus sau cập nhật; tắt online không tự hủy chuyến đang thực hiện.",
            "JSON gồm online kiểu boolean bắt buộc: true để nhận chuyến, false để tắt nhận chuyến.",
            "400", "Thiếu/sai JSON hoặc online thiếu/không phải boolean.", "404", DRIVER,
            "409", "Yêu cầu online=true nhưng hồ sơ Driver chưa được kích hoạt (active=false).");
        contract("DriverController.session", "Tạo phiên vị trí mới; body gồm trackingSessionId và startedAt. Phiên cũ bị thay thế, sequence về 0 và vị trí cũ bị xóa.", null, "404", DRIVER);
        contract("DriverController.location", "Trả body applied và currentSequence: true nếu đã lưu vị trí; false nếu sequence cũ/trùng và dữ liệu không được ghi đè.",
            "JSON gồm trackingSessionId UUID hiện hành, sequence dương, latitude [-90,90], longitude [-180,180], accuracyMeters không âm và recordedAt ISO-8601 bắt buộc. Dùng thời điểm đo thực tế, không sao chép timestamp mẫu.",
            "400", "Thiếu/sai JSON hoặc trường bắt buộc; UUID/Instant sai định dạng; sequence không dương; latitude/longitude ngoài miền; accuracyMeters âm; với sequence mới, recordedAt quá cũ, vượt giới hạn tương lai hoặc lùi so với vị trí đã lưu.",
            "404", DRIVER, "409", "trackingSessionId không khớp phiên vị trí hiện hành của tài xế.");

        contract("DriverOfferController.list", "Trả body mảng lời mời OFFERED chưa hết hạn của tài xế; mảng rỗng nếu không có lời mời.", null, "404", OFFER);
        contract("DriverOfferController.get", "Trả body lời mời theo assignmentId, gồm trạng thái, hạn phản hồi và dữ liệu đơn; có thể trả lời mời đã hết hạn/đã phản hồi.", null,
            "400", "id (assignmentId) không phải UUID hợp lệ.", "404", OFFER);
        contract("DriverOfferController.accept", "Trả body lời mời ACCEPTED, gán chuyến ASSIGNED cho tài xế; gọi lại lời mời đã ACCEPTED trả dữ liệu hiện tại.", null,
            "400", "id (assignmentId) không phải UUID hợp lệ.", "404", OFFER,
            "409", "Lời mời không còn OFFERED hoặc hết hạn; tài xế chưa active/online; chuyến không còn PENDING_ASSIGNMENT hoặc tài xế đã có chuyến đang thực hiện.");
        contract("DriverOfferController.reject", "Trả body lời mời REJECTED; không hủy đơn khách. Gọi lại lời mời đã REJECTED trả dữ liệu hiện tại.", null,
            "400", "id (assignmentId) không phải UUID hợp lệ.", "404", OFFER,
            "409", "Lời mời không còn OFFERED hoặc đã hết hạn nên không thể từ chối.");

        contract("DriverDeliveryController.current", "Trả body chuyến đang ASSIGNED, AT_PICKUP, PICKED_UP hoặc AT_DROPOFF của tài xế; trường hợp không có chuyến dùng 204 riêng.", null, "404", DELIVERY);
        contract("DriverDeliveryController.history", "Trả body phân trang chuyến DELIVERED, FAILED hoặc CANCELLED còn thuộc tài xế, sắp xếp updatedAt giảm dần; items có thể rỗng.", null,
            "400", PAGING, "404", DELIVERY);
        contract("DriverDeliveryController.historyDetail", "Trả body chi tiết chuyến đã kết thúc trong lịch sử của tài xế.", null,
            "400", "id (deliveryId) không phải UUID hợp lệ.", "404", DELIVERY + " Chuyến chưa kết thúc cũng trả 404 tại endpoint lịch sử.");
        contract("DriverDeliveryController.arrivePickup", "Trả body chuyến AT_PICKUP sau xác nhận đến nhà hàng; nếu đã AT_PICKUP thì trả hiện trạng.", null,
            "400", "id (deliveryId) không phải UUID hợp lệ.", "404", DELIVERY,
            "409", "Chuyến không ở ASSIGNED (và chưa AT_PICKUP). " + GPS);
        contract("DriverDeliveryController.pickup", "Trả body chuyến PICKED_UP cùng pickedUpAt; đơn chuyển PICKED_UP. Gọi lại chuyến đã PICKED_UP trả hiện trạng.", null,
            "400", "id (deliveryId) không phải UUID hợp lệ.", "404", DELIVERY,
            "409", "Chuyến chưa AT_PICKUP hoặc đơn chưa READY (trừ khi chuyến đã PICKED_UP). " + GPS);
        contract("DriverDeliveryController.arriveDropoff", "Trả body chuyến AT_DROPOFF sau xác nhận đến điểm giao; nếu đã AT_DROPOFF thì trả hiện trạng.", null,
            "400", "id (deliveryId) không phải UUID hợp lệ.", "404", DELIVERY,
            "409", "Chuyến không ở PICKED_UP (và chưa AT_DROPOFF). " + GPS);
        contract("DriverDeliveryController.deliver", "Trả body chuyến DELIVERED và deliveredAt; đơn chuyển DELIVERED, assignment COMPLETED; ghi nhận tiền công hoặc khoản chờ xác nhận. Gọi lại không cộng tiền lần nữa.", null,
            "400", "id (deliveryId) không phải UUID hợp lệ.", "404", DELIVERY,
            "409", "Chuyến chưa AT_DROPOFF (và chưa DELIVERED). " + GPS);
        contract("DriverDeliveryController.fail", "Trả body chuyến FAILED và failedAt; đơn/assignment chuyển FAILED, báo cáo và ảnh được lưu. Retry cùng nội dung trả chuyến hiện tại.",
            "multipart/form-data gồm assignmentId UUID hiện tại, requestId UUID do client tạo, reason (CUSTOMER_UNREACHABLE, CUSTOMER_REFUSED hoặc OTHER), image PNG/JPEG bắt buộc và note tùy chọn tối đa 1000 ký tự. Giữ nguyên mọi dữ liệu khi retry.",
            "400", "id/assignmentId/requestId sai UUID hoặc thiếu tham số bắt buộc; reason sai enum; note quá 1000 ký tự; thiếu image; " + IMAGE,
            "404", DELIVERY + " Hoặc assignmentId không khớp phân công hiện tại.",
            "409", "Chuyến chưa AT_DROPOFF; hoặc đã có báo cáo nhưng requestId, reason, note hoặc hash nội dung ảnh khác lần trước.",
            "413", UPLOAD, "503", "Kho bằng chứng không khả dụng khi lưu ảnh giao thất bại.");
        contract("DriverDeliveryController.report", "Trả body báo cáo giao thất bại gồm lý do, ghi chú và metadata ảnh; Cache-Control: no-store, không trả byte ảnh tại đây.", null,
            "400", "id (deliveryId) không phải UUID hợp lệ.", "404", DELIVERY + " Hoặc chuyến chưa có báo cáo giao thất bại.");
        contract("DriverDeliveryController.evidence", "Trả byte ảnh báo cáo thất bại, Content-Type image/png hoặc image/jpeg; no-store và nosniff, không có JSON body.", null,
            "400", "id (deliveryId) không phải UUID hợp lệ.", "404", DELIVERY + " Hoặc chưa có báo cáo giao thất bại.",
            "503", "Không đọc được ảnh báo cáo thất bại từ kho bằng chứng.");
        contract("DriverDeliveryController.incident", "Trả body sự cố gồm id, deliveryId, assignmentId, reason, outcome, note và createdAt; giải phóng assignment và đưa chuyến về PENDING_ASSIGNMENT, không hủy đơn khách.",
            "multipart/form-data gồm assignmentId, requestId UUID, reason (PERSONAL, RESTAURANT_DELAY hoặc RESTAURANT_CLOSED), note tùy chọn tối đa 1000 ký tự. RESTAURANT_CLOSED bắt buộc image PNG/JPEG; các lý do khác không nhận ảnh không rỗng. Giữ nguyên dữ liệu khi retry.",
            "400", "id/assignmentId/requestId sai UUID hoặc thiếu; reason thiếu/sai enum; note quá 1000 ký tự; RESTAURANT_CLOSED thiếu ảnh; lý do khác gửi ảnh không rỗng; " + IMAGE,
            "404", DELIVERY + " Hoặc assignmentId không khớp phân công; sự cố retry không thuộc tài xế/chuyến hiện tại.",
            "409", "Chuyến không ở ASSIGNED/AT_PICKUP, đơn không còn PREPARING; với assignmentId đã có sự cố, retry khác requestId, reason, note hoặc hash ảnh. Với RESTAURANT_CLOSED: " + GPS,
            "413", UPLOAD, "503", "Kho bằng chứng không khả dụng khi lưu ảnh nhà hàng đóng cửa.");
        contract("DriverDeliveryController.incidents", "Trả body mảng sự cố do tài xế báo, mới nhất trước; có thể rỗng và không phân trang. outcome là kết quả tại lúc báo, không phải trạng thái chuyến hiện tại.", null, "404", DRIVER);
        contract("DriverDeliveryController.incidentEvidence", "Trả byte ảnh sự cố, Content-Type image/png hoặc image/jpeg; no-store và nosniff, không có JSON body.", null,
            "400", "id của bản ghi sự cố không phải UUID hợp lệ.",
            "404", DRIVER + " Hoặc không tìm thấy sự cố thuộc người báo hiện tại hoặc sự cố không có ảnh.",
            "503", "Không đọc được ảnh sự cố từ kho bằng chứng.");
        contract("DriverEventController.subscribe", "Mở luồng text/event-stream: connected, heartbeat và orders-changed có data={}. Kết nối duy trì mở, không trả object JSON hay danh sách chuyến.", null, "404", DRIVER);

        contract("DriverAccountController.settings", "Trả body thiết lập nhận chuyến gồm autoAcceptEnabled, maxDeliveryDistanceKm, maxItemQuantity và maxRestaurantAdvanceAmount.",
            "JSON gồm maxDeliveryDistanceKm bắt buộc 0.1–100, maxItemQuantity bắt buộc 1–5000, maxRestaurantAdvanceAmount bắt buộc 0–100000000 VND và autoAcceptEnabled boolean (bỏ qua dùng false do kiểu primitive).",
            "400", "Thiếu/sai JSON; maxDeliveryDistanceKm thiếu/ngoài 0.1–100; maxItemQuantity thiếu/ngoài 1–5000; maxRestaurantAdvanceAmount thiếu/ngoài 0–100000000; autoAcceptEnabled không phải boolean.", "404", DRIVER);
        contract("DriverAccountController.appSettings", "Trả body thiết lập inAppNotificationsEnabled của tài xế.",
            "JSON gồm inAppNotificationsEnabled boolean bắt buộc; true bật tạo thông báo trong ứng dụng, false tắt.",
            "400", "Thiếu/sai JSON hoặc inAppNotificationsEnabled thiếu/không phải boolean.", "404", DRIVER);
        contract("DriverAccountController.wallet", "Trả body balance tiền công đã ghi nhận, currency=VND và earningsConfigured phản ánh cấu hình mức tiền công hiện tại; không phải cam kết số dư rút được.", null, "404", DRIVER);
        contract("DriverAccountController.transactions", "Trả body phân trang giao dịch tiền công đã xác định của tài xế, mới nhất trước; không gồm khoản chờ xác nhận, items có thể rỗng.", null,
            "400", PAGING, "404", DRIVER);
        contract("DriverAccountController.transaction", "Trả body giao dịch tiền công đã xác định, gồm amount, balanceAfter và deliveryId; balanceAfter là số dư ngay sau giao dịch này.", null,
            "400", "id giao dịch không phải UUID hợp lệ.", "404", DRIVER + " Hoặc giao dịch không tồn tại, không thuộc tài xế hoặc chưa xác định tiền công.");
        contract("DriverAccountController.earnings", "Trả body thống kê kỳ DAY/WEEK/MONTH gồm tổng tiền công đã ghi nhận và chart theo ngày, có cả ngày 0; không tính khoản chờ xác nhận.", null,
            "400", "period không phải DAY, WEEK hoặc MONTH; date không đúng ngày hợp lệ theo yyyy-MM-dd.", "404", DRIVER);
        contract("DriverAccountController.notifications", "Trả body phân trang thông báo của tài xế, mới nhất trước, kèm trạng thái read; items có thể rỗng.", null,
            "400", PAGING, "404", DRIVER);
        contract("DriverAccountController.unread", "Trả body {count} là số thông báo chưa đọc của tài xế, bằng 0 nếu không có.", null, "404", DRIVER);
        contract("DriverAccountController.read", "Trả body thông báo với read=true; gọi lại không thay đổi thời điểm đọc lần đầu.", null,
            "400", "id thông báo không phải UUID hợp lệ.", "404", DRIVER + " Hoặc không tìm thấy thông báo thuộc tài xế hiện tại.");
        contract("DriverAccountController.readAll", "Đánh dấu mọi thông báo chưa đọc hiện có của tài xế là đã đọc, không xóa thông báo. Không có response body.", null, "404", DRIVER);
        contract("AdminEarningController.pending", "Trả body phân trang PendingDriverEarning chưa resolved, theo deliveredAt tăng dần; chưa có amount và items có thể rỗng.", null,
            "400", PAGING);
        contract("AdminEarningController.reconcile", "Đã ghi giao dịch tiền công, cộng số dư và đánh dấu khoản chờ đã xử lý; khoản đã resolved không được cộng lại. HTTP 200 không có response body.",
            "JSON gồm amount bắt buộc là số nguyên VND từ 1 đến 999999999999, do ADMIN xác nhận thực tế; deliveryId nằm ở đường dẫn.",
            "400", "deliveryId sai UUID; thiếu/sai JSON; amount thiếu, nhỏ hơn 1, có phần thập phân hoặc quá 12 chữ số nguyên.",
            "404", "Không tìm thấy nghĩa vụ tiền công theo deliveryId. Trường hợp nghĩa vụ còn nhưng Driver bị thiếu chưa có ánh xạ lỗi rõ ràng; cần xác minh riêng, không cam kết 404.",
            "409", "Đã có giao dịch cho deliveryId nhưng nghĩa vụ chưa resolved; cần rà soát, không cộng thêm tiền.");

        contract("CustomerCartController.get", "Trả body giỏ gồm restaurantId, items, subtotal, deliveryFee và total; giỏ trống có items rỗng, restaurantId=null và các tổng tiền bằng 0.", null,
            "409", "Giỏ có menuItemId đã bị xóa khỏi thực đơn; cần xóa món đó khỏi giỏ trước khi đọc lại.");
        contract("CustomerCartController.add", "Trả body toàn bộ giỏ sau khi thêm món/cộng số lượng và thay ghi chú; giá và tổng tiền do máy chủ tính.",
            "JSON gồm menuItemId UUID bắt buộc, quantity bắt buộc 1–100 và note tùy chọn tối đa 500 ký tự. Không gửi đơn giá.",
            "400", "Thiếu/sai JSON; menuItemId thiếu/sai UUID; quantity thiếu/ngoài 1–100; note quá 500 ký tự; tổng quantity sau cộng vượt 100.",
            "404", "Không tìm thấy tài khoản khách hàng, món theo menuItemId hoặc nhà hàng của món.",
            "409", "Món không khả dụng, nhà hàng không nhận đơn, giỏ có món đã bị xóa/thuộc nhà hàng khác hoặc thêm dòng mới khi đã đủ 50 dòng món.");
        contract("CustomerCartController.update", "Trả body toàn bộ giỏ sau khi thay quantity và note của món; không thêm món mới hoặc đặt lại giá.",
            "JSON gồm quantity bắt buộc 1–100 và note tùy chọn tối đa 500 ký tự; menuItemId của món trong giỏ nằm ở đường dẫn.",
            "400", "menuItemId sai UUID; thiếu/sai JSON; quantity thiếu/ngoài 1–100 hoặc note quá 500 ký tự.",
            "404", "Không tìm thấy tài khoản khách hàng hoặc dòng món theo menuItemId trong giỏ của khách hiện tại.",
            "409", "Giỏ chứa món đã bị xóa khỏi thực đơn nên không thể dựng giỏ sau cập nhật.");
        contract("CustomerCartController.remove", "Đã xóa dòng món khỏi giỏ nếu có; món không có trong giỏ cũng trả 204. Không có response body.", null,
            "400", "menuItemId không phải UUID hợp lệ.", "404", "Không tìm thấy tài khoản khách hàng để khóa giỏ; không dùng 404 cho món vắng trong giỏ.");
        contract("CustomerCartController.clear", "Đã xóa mọi dòng món của giỏ hiện tại; giỏ đã trống cũng trả 204. Không hủy đơn đã đặt và không có response body.", null,
            "404", "Không tìm thấy tài khoản khách hàng để khóa và xóa giỏ.");
        contract("CustomerOrderController.place", "Tạo đơn PENDING và trả body OrderResponse với giá được chốt; retry cùng Idempotency-Key và cùng request trả đơn cũ, vẫn HTTP 201. Không tự lấy dữ liệu từ giỏ.",
            "JSON gồm restaurantId, items (1–50 dòng: menuItemId, quantity 1–100, note tối đa 500), recipient (name, phone), dropoff (address, latitude, longitude), deliveryNote tùy chọn tối đa 1000 và paymentMethod=COD. Gửi header Idempotency-Key bắt buộc.",
            "400", "Thiếu/sai JSON hoặc Idempotency-Key trắng/quá 100 ký tự; restaurantId/menuItemId sai hoặc thiếu UUID; items thiếu/ngoài 1–50; quantity ngoài 1–100; note quá 500; recipient.name trống/quá 150, recipient.phone trống/quá 20; dropoff.address trống/quá 500, tọa độ thiếu/ngoài miền; deliveryNote quá 1000; paymentMethod thiếu/khác COD.",
            "404", "Không tìm thấy nhà hàng restaurantId hoặc món menuItemId được yêu cầu.",
            "409", "Idempotency-Key đã dùng với request khác; nhà hàng không nhận đơn; món không khả dụng hoặc không thuộc restaurantId; hoặc xung đột ràng buộc dữ liệu khi lưu đơn.");
        contract("CustomerOrderController.list", "Trả body phân trang OrderResponse của khách đăng nhập, theo createdAt giảm dần; items có thể rỗng.", null,
            "400", PAGING);
        contract("CustomerOrderController.detail", "Trả body OrderResponse của đơn thuộc khách hiện tại, gồm trạng thái, món, giá và thông tin giao nhận đã lưu.", null,
            "400", "id (orderId) không phải UUID hợp lệ.", "404", ORDER);
        contract("CustomerOrderController.tracking", "Trả body theo dõi đơn, trạng thái chuyến và thông tin/vị trí tài xế nếu chuyến đang thực hiện; driver và driverLocation có thể null.", null,
            "400", "id (orderId) không phải UUID hợp lệ.", "404", ORDER);
        contract("CustomerOrderController.cancel", "Trả body OrderResponse sau khi chuyển CANCELLED và lưu lý do; đơn đã CANCELLED được trả lại mà không hủy lần nữa.",
            "JSON gồm reason không trắng, tối đa 500 ký tự; id là orderId của khách hiện tại.",
            "400", "id sai UUID; thiếu/sai JSON hoặc reason trống/quá 500 ký tự.", "404", ORDER,
            "409", "Đơn không còn PENDING và chưa CANCELLED; khách không thể hủy khi nhà hàng đã nhận chuẩn bị hoặc ở trạng thái sau đó.");

        contract("RestaurantOrderController.list", "Trả body phân trang đơn của nhà hàng, theo createdAt giảm dần, lọc chính xác status nếu có; items có thể rỗng.", null,
            "400", "restaurantId sai UUID; status không thuộc enum OrderStatus; " + PAGING,
            "404", "Không tìm thấy nhà hàng restaurantId hoặc nhà hàng không thuộc MERCHANT hiện tại.");
        contract("RestaurantOrderController.detail", "Trả body chi tiết gồm order, deliveryStatus và driver; dữ liệu chuyến/tài xế có thể null khi chưa được tạo hoặc phân công.", null,
            "400", "restaurantId hoặc orderId không phải UUID hợp lệ.", "404", RESTAURANT);
        contract("RestaurantOrderController.accept", "Trả body OrderResponse PREPARING, lưu estimatedReadyAt và tạo chuyến PENDING_ASSIGNMENT. Đơn đã PREPARING được trả lại, không đổi thời gian chuẩn bị.",
            "JSON gồm estimatedPreparationMinutes bắt buộc, là số nguyên 1–180 phút.",
            "400", "restaurantId/orderId sai UUID; thiếu/sai JSON hoặc estimatedPreparationMinutes thiếu/ngoài 1–180.", "404", RESTAURANT,
            "409", "Đơn không ở PENDING và chưa PREPARING nên không thể nhận chuẩn bị.");
        contract("RestaurantOrderController.reject", "Trả body OrderResponse REJECTED với lý do từ chối; đơn đã REJECTED được trả lại không xử lý lần nữa.",
            "JSON gồm reason không trắng, tối đa 500 ký tự, nêu lý do nhà hàng từ chối đơn mới.",
            "400", "restaurantId/orderId sai UUID; thiếu/sai JSON hoặc reason trống/quá 500 ký tự.", "404", RESTAURANT,
            "409", "Đơn không ở PENDING và chưa REJECTED nên không thể từ chối đơn mới.");
        contract("RestaurantOrderController.ready", "Trả body OrderResponse READY cùng readyAt; đơn đã READY được trả lại không xử lý lần nữa.", null,
            "400", "restaurantId hoặc orderId không phải UUID hợp lệ.", "404", RESTAURANT,
            "409", "Đơn không ở PREPARING và chưa READY nên không thể đánh dấu món sẵn sàng.");
        contract("RestaurantOrderController.cancel", "Trả body OrderResponse CANCELLED; hủy chuyến và lời mời OFFERED/ACCEPTED liên quan nếu có. Đơn đã CANCELLED được trả lại không hủy lần nữa.",
            "JSON gồm reason không trắng, tối đa 500 ký tự, nêu lý do nhà hàng hủy đơn trước READY.",
            "400", "restaurantId/orderId sai UUID; thiếu/sai JSON hoặc reason trống/quá 500 ký tự.", "404", RESTAURANT,
            "409", "Đơn không ở PENDING/PREPARING và chưa CANCELLED; không cho nhà hàng hủy từ READY trở đi.");
    }

    private static Contract get(String key) {
        Contract result = CONTRACTS.get(key);
        if (result == null) throw new IllegalStateException("Thiếu tài liệu endpoint: " + key);
        return result;
    }

    static String success(String key, boolean writingSettings) {
        return (key.equals("DriverAccountController.settings") || key.equals("DriverAccountController.appSettings")) && writingSettings
            ? "Đã lưu thiết lập. " + get(key).success() : get(key).success();
    }

    static String request(String key) { return get(key).request(); }

    static Map<String, String> errors(String key, boolean writingSettings) {
        Map<String, String> errors = new LinkedHashMap<>(get(key).errors());
        if (!writingSettings && (key.equals("DriverAccountController.settings") || key.equals("DriverAccountController.appSettings"))) errors.remove("400");
        return errors;
    }
}
