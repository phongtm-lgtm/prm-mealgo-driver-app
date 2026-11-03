package com.mealgo.monolith.driver.dto;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;

public final class DriverAccountDtos {
    private DriverAccountDtos() {}
    public record OrderSettings(boolean autoAcceptEnabled,
        @NotNull @DecimalMin("0.1") @DecimalMax("100") Double maxDeliveryDistanceKm,
        @NotNull @Min(1) @Max(5000) Integer maxItemQuantity,
        @NotNull @DecimalMin("0") @DecimalMax("100000000") BigDecimal maxRestaurantAdvanceAmount) {}
    public record AppSettings(@NotNull Boolean inAppNotificationsEnabled) {}
    public record Wallet(BigDecimal balance,String currency,boolean earningsConfigured) {}
    public record Transaction(UUID id,String type,BigDecimal amount,BigDecimal balanceAfter,UUID deliveryId,String description,Instant createdAt) {}
    public record Notification(UUID id,String type,String title,String message,UUID referenceId,boolean read,Instant createdAt) {}
    public record UnreadCount(long count) {}
    public enum Period { DAY, WEEK, MONTH }
    public record ChartPoint(LocalDate date,long completedDeliveries,BigDecimal earnings) {}
    public record Earnings(Period period,LocalDate fromDate,LocalDate toDate,String timezone,long completedDeliveries,
        BigDecimal totalEarnings,String currency,boolean earningsConfigured,List<ChartPoint> chart) {}
}
