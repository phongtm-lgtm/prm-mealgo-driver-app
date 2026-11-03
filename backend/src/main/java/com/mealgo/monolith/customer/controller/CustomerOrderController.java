package com.mealgo.monolith.customer.controller;
import com.mealgo.monolith.customer.dto.request.*;
import com.mealgo.monolith.order.dto.OrderResponse;
import com.mealgo.monolith.order.service.OrderService;
import com.mealgo.monolith.delivery.dto.DeliveryDtos.Tracking;
import com.mealgo.monolith.delivery.service.DeliveryService;
import com.mealgo.monolith.common.dto.PageResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.UUID;
@RestController @RequestMapping("/api/v1/customers/me/orders") @RequiredArgsConstructor @PreAuthorize("hasRole('CUSTOMER')")
public class CustomerOrderController {
    private final OrderService orders;
    private final DeliveryService deliveries;
    @PostMapping @ResponseStatus(HttpStatus.CREATED)
    public OrderResponse place(@RequestHeader("Idempotency-Key") String key,@Valid @RequestBody PlaceOrderRequest r) { return orders.place(key,r); }
    @GetMapping public PageResponse<OrderResponse> list(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return orders.mine(page,size); }
    @GetMapping("/{id}") public OrderResponse detail(@PathVariable UUID id) { return orders.detail(id); }
    @GetMapping("/{id}/tracking") public Tracking tracking(@PathVariable UUID id) { return deliveries.track(id); }
    @PostMapping("/{id}/cancel") public OrderResponse cancel(@PathVariable UUID id,@Valid @RequestBody CancelOrderRequest r) { return orders.cancel(id,r); }
}
