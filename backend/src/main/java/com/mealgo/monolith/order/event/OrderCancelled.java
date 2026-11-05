package com.mealgo.monolith.order.event;

import com.mealgo.monolith.order.enums.CancellationCode;
import java.util.UUID;

public record OrderCancelled(UUID orderId, UUID deliveryId, CancellationCode code) {}
