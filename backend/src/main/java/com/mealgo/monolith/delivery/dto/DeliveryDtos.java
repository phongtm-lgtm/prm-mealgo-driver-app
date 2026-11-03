package com.mealgo.monolith.delivery.dto;
import com.mealgo.monolith.delivery.enums.*;
import com.mealgo.monolith.order.dto.OrderResponse;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
public final class DeliveryDtos {
    private DeliveryDtos() {}
    public record RestaurantInfo(String name,String phone) {}
    public record Payment(String method,BigDecimal amountToCollect,String currency) {}
    public record Current(UUID deliveryId,UUID assignmentId,UUID orderId,DeliveryStatus status,
            RestaurantInfo restaurant,OrderResponse.Stop pickup,OrderResponse.Stop dropoff,
            OrderResponse.Recipient recipient,String deliveryNote,List<OrderResponse.Item> items,Payment payment,
            Instant updatedAt,Instant pickedUpAt,Instant deliveredAt,Instant failedAt) {}
    public record Offer(UUID assignmentId,UUID deliveryId,AssignmentStatus status,Instant offeredAt,
            Instant expiresAt,Instant respondedAt,boolean canRespond,OrderResponse.Stop pickup,OrderResponse.Stop dropoff) {}
    public record DriverInfo(UUID driverId,String name,String phone) {}
    public record Location(double latitude,double longitude,Instant recordedAt) {}
    public record Tracking(UUID orderId,String orderStatus,UUID deliveryId,DeliveryStatus deliveryStatus,
            DriverInfo driver,Location driverLocation,OrderResponse.Stop pickup,OrderResponse.Stop dropoff) {}
    public record Evidence(String contentType,long sizeBytes,String url) {}
    public record Report(UUID reportId,UUID deliveryId,UUID assignmentId,FailureReason reason,String note,Instant createdAt,Evidence evidence) {}
    public record EvidenceContent(byte[] bytes,String contentType) {}
}
