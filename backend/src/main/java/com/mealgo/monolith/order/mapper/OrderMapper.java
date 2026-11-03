package com.mealgo.monolith.order.mapper;
import com.mealgo.monolith.order.entity.Order;
import com.mealgo.monolith.order.dto.OrderResponse;
import org.springframework.stereotype.Component;
@Component
public class OrderMapper {
    public OrderResponse toResponse(Order o) {
        return new OrderResponse(o.getId(),o.getRestaurantId(),o.getStatus(),o.getItems().stream().map(i ->
                new OrderResponse.Item(i.getMenuItemId(),i.getName(),i.getQuantity(),i.getUnitPrice(),i.getNote())).toList(),
                new OrderResponse.Recipient(o.getRecipientName(),o.getRecipientPhone()),
                new OrderResponse.Stop(o.getPickupAddress(),o.getPickupLatitude(),o.getPickupLongitude()),
                new OrderResponse.Stop(o.getDropoffAddress(),o.getDropoffLatitude(),o.getDropoffLongitude()),
                o.getDeliveryNote(),o.getPaymentMethod(),o.getSubtotal(),o.getDeliveryFee(),o.getTotal(),o.getCurrency(),
                o.getCreatedAt(),o.getUpdatedAt(),o.getEstimatedReadyAt(),o.getReadyAt(),o.getCancellationReason());
    }
}
