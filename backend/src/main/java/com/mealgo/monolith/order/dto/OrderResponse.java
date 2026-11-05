package com.mealgo.monolith.order.dto;
import com.mealgo.monolith.order.enums.OrderStatus;
import com.mealgo.monolith.order.enums.CancellationCode;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
public record OrderResponse(UUID orderId, UUID restaurantId, OrderStatus status, List<Item> items,
        Recipient recipient, Stop pickup, Stop dropoff, String deliveryNote, String paymentMethod,
        BigDecimal subtotal, BigDecimal deliveryFee, BigDecimal total, String currency,
        Instant createdAt, Instant updatedAt, Instant estimatedReadyAt, Instant readyAt, String cancellationReason,
        CancellationCode cancellationCode) {
    public record Item(UUID menuItemId,String name,int quantity,BigDecimal unitPrice,String note) {}
    public record Recipient(String name,String phone) {}
    public record Stop(String address,double latitude,double longitude) {}
}
