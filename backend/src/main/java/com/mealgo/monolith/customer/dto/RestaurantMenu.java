package com.mealgo.monolith.customer.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record RestaurantMenu(UUID restaurantId, String restaurantName, double latitude, double longitude,
                             List<Dish> items) {
    public record Dish(UUID menuItemId, String name, BigDecimal price) {}
}
