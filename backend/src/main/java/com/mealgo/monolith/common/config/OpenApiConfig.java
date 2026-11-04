package com.mealgo.monolith.common.config;

import com.mealgo.monolith.common.docs.ApiDocumentation;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springdoc.core.customizers.OperationCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Chỉ bổ sung tài liệu, không can thiệp hợp đồng hay quyền truy cập API. */
@Configuration
public class OpenApiConfig {
    @Bean OpenAPI mealgoOpenApi() {
        return new OpenAPI().info(new Info().title("MealGo — Tài liệu API")
                .version("v1").description("""
                    API khách hàng, nhà hàng, tài xế và quản trị MealGo. Mô tả bằng tiếng Việt;
                    tên trường, đường dẫn và giá trị enum giữ nguyên hợp đồng API.

                    **Xác thực:** gọi đăng nhập, sao chép `accessToken` vào nút Authorize (không cần thêm Bearer).
                    Quyền CUSTOMER / MERCHANT / DRIVER / ADMIN được kiểm tra trên máy chủ.
                    Tài nguyên không thuộc người gọi thường trả 404 để tránh lộ dữ liệu.
                    Các nút Try it out thực thi thao tác thật trên môi trường đang chọn, kể cả duyệt hồ sơ và cộng tiền công.
                    Ví dụ dữ liệu chỉ để minh họa, không phải tài khoản, số dư hay mức tiền công thực tế.

                    **Quy ước:** JSON dùng UTF-8; UUID là mã định danh; Instant là ISO-8601 có múi giờ (ví dụ
                    `2026-11-04T03:07:00Z`); LocalDate là `yyyy-MM-dd`. Tiền là số thập phân đơn vị VND.
                    Phân trang từ 0, mặc định page=0, size=20; size từ 1 đến 100.
                    Kết quả gồm items, page, size, hasNext, không có tổng số bản ghi.

                    **Luồng tài xế mới:** register/start → register/verify → lưu application → tải đủ 4 giấy tờ
                    → submit → ADMIN approve → online-status → tracking-session → location → nhận chuyến.
                    OTP giả lập cố định 12345, chỉ local/docker/test và phải bật cấu hình; không gửi SMS thật.
                    Phiên OTP nằm trong RAM và mất sau khi khởi động lại.

                    **Tiền công:** phí giao hàng khách trả và tiền COD thu hộ KHÔNG phải thu nhập tài xế.
                    Ví chỉ ghi nhận tiền công đã xác định; chưa có API rút tiền hoặc thưởng.
                    Khi chưa cấu hình tiền công dương, hệ thống ghi nghĩa vụ chờ xử lý, không cộng 0 đồng vào ví.
                    Quản trị phải xác nhận số tiền thực tế qua reconcile.

                    **Lỗi:** lỗi nghiệp vụ/validation do ứng dụng xử lý dùng application/problem+json
                    (type, title, status, detail; validation có thể thêm errors).
                    Lỗi tại bộ lọc bảo mật 401/403 không bảo đảm cùng cấu trúc ProblemDetail.
                    Thông báo lỗi thực tế có thể là tiếng Anh; tài liệu tiếng Việt không thay đổi response.
                    """))
                .components(new Components().addSecuritySchemes("bearerAuth", new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP).scheme("bearer").bearerFormat("JWT")
                        .description("Nhập accessToken, không nhập refreshToken. Không chia sẻ token hoặc lưu token trong tài liệu.")));
    }

    @Bean OperationCustomizer vietnameseOperations() { return ApiDocumentation::describeOperation; }
    @Bean OpenApiCustomizer vietnameseSchemas() { return ApiDocumentation::describeSchemas; }
}
