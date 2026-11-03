package com.mealgo.monolith.restaurant.dto;
import com.mealgo.monolith.order.dto.OrderResponse;
import com.mealgo.monolith.delivery.dto.DeliveryDtos.DriverInfo;
import jakarta.validation.constraints.*;
import java.time.Instant;
public final class RestaurantOrderDtos {
    private RestaurantOrderDtos() {}
    public record Accept(@NotNull @Min(1) @Max(180) Integer estimatedPreparationMinutes) {}
    public record Reject(@NotBlank @Size(max=500) String reason) {}
    public record Detail(OrderResponse order,DriverInfo driver,String deliveryStatus,Instant pickedUpAt) {}
}
