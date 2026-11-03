package com.mealgo.monolith.customer.dto.request;
import jakarta.validation.constraints.*;
public record CancelOrderRequest(@NotBlank @Size(max=500) String reason) {}
