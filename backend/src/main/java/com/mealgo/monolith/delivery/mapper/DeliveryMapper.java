package com.mealgo.monolith.delivery.mapper;
import com.mealgo.monolith.delivery.dto.DeliveryDtos.*;
import com.mealgo.monolith.delivery.entity.*;
import com.mealgo.monolith.delivery.enums.AssignmentStatus;
import com.mealgo.monolith.delivery.enums.DeliveryStatus;
import com.mealgo.monolith.order.entity.Order;
import com.mealgo.monolith.order.mapper.OrderMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import java.time.Instant;
import java.math.BigDecimal;
@Component @RequiredArgsConstructor
public class DeliveryMapper {
    private final OrderMapper orders;
    public Current current(Delivery d,Order o) {
        var r = orders.toResponse(o);
        return new Current(d.getId(),d.getAssignmentId(),o.getId(),d.getStatus(),
                new RestaurantInfo(o.getRestaurantName(),o.getRestaurantPhone()),r.pickup(),r.dropoff(),r.recipient(),
                r.deliveryNote(),r.items(),new Payment(o.getPaymentMethod(),
                        d.getStatus() == DeliveryStatus.CANCELLED ? BigDecimal.ZERO : o.getTotal(),o.getCurrency()),
                d.getUpdatedAt(),d.getPickedUpAt(),d.getDeliveredAt(),d.getFailedAt(),o.getStatus(),o.getCancellationCode());
    }
    public Offer offer(Assignment a,Order o) {
        return new Offer(a.getId(),a.getDeliveryId(),a.getStatus(),a.getOfferedAt(),a.getExpiresAt(),a.getRespondedAt(),
                a.getStatus()==AssignmentStatus.OFFERED && a.getExpiresAt().isAfter(Instant.now()),
                new com.mealgo.monolith.order.dto.OrderResponse.Stop(o.getPickupAddress(),o.getPickupLatitude(),o.getPickupLongitude()),
                new com.mealgo.monolith.order.dto.OrderResponse.Stop(o.getDropoffAddress(),o.getDropoffLatitude(),o.getDropoffLongitude()),
                o.getId(),o.getRestaurantName());
    }
    public Report report(FailureReport r) {
        return new Report(r.getId(),r.getDeliveryId(),r.getAssignmentId(),r.getReason(),r.getNote(),r.getCreatedAt(),
                new Evidence(r.getContentType(),r.getSizeBytes(),"/api/v1/drivers/me/deliveries/"+r.getDeliveryId()+"/failure-report/evidence"));
    }
}
