package com.mealgo.monolith.customer.dto;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.util.*;

public final class CartDtos {
    private CartDtos() {}
    public record AddItem(@NotNull UUID menuItemId, @Min(1) @Max(100) int quantity, @Size(max=500) String note) {}
    public record UpdateItem(@Min(1) @Max(100) int quantity, @Size(max=500) String note) {}
    public record Item(UUID menuItemId, String name, int quantity, String note, BigDecimal unitPrice, BigDecimal lineTotal, boolean available) {}
    public record Cart(UUID restaurantId, List<Item> items, BigDecimal subtotal, BigDecimal deliveryFee, BigDecimal total) {}
}
