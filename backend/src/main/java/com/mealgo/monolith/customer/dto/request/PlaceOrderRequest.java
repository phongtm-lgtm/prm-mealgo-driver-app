package com.mealgo.monolith.customer.dto.request;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
public record PlaceOrderRequest(
        @NotNull UUID restaurantId,
        @NotEmpty @Size(max=50) List<@NotNull @Valid Item> items,
        @NotNull @Valid Recipient recipient,
        @NotNull @Valid Dropoff dropoff,
        @Size(max=1000) String deliveryNote,
        @NotNull PaymentMethod paymentMethod) {
    public enum PaymentMethod { COD }
    public record Item(@NotNull UUID menuItemId, @Min(1) @Max(100) int quantity, @Size(max=500) String note) {}
    public record Recipient(@NotBlank @Size(max=150) String name, @NotBlank @Size(max=20) String phone) {}
    public record Dropoff(@NotBlank @Size(max=500) String address,
                          @NotNull @DecimalMin("-90") @DecimalMax("90") Double latitude,
                          @NotNull @DecimalMin("-180") @DecimalMax("180") Double longitude) {}
}
