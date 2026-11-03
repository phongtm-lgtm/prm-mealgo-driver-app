package com.mealgo.monolith.restaurant.controller;
import com.mealgo.monolith.common.dto.PageResponse;
import com.mealgo.monolith.order.dto.OrderResponse;
import com.mealgo.monolith.order.enums.OrderStatus;
import com.mealgo.monolith.restaurant.dto.RestaurantOrderDtos.*;
import com.mealgo.monolith.restaurant.service.RestaurantOrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.UUID;
@RestController @RequestMapping("/api/v1/merchant/restaurants/{restaurantId}/orders")
@RequiredArgsConstructor @PreAuthorize("hasRole('MERCHANT')")
public class RestaurantOrderController {
    private final RestaurantOrderService service;
    @GetMapping public PageResponse<OrderResponse> list(@PathVariable UUID restaurantId,@RequestParam(required=false) OrderStatus status,
            @RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return service.list(restaurantId,status,page,size); }
    @GetMapping("/{orderId}") public Detail detail(@PathVariable UUID restaurantId,@PathVariable UUID orderId) { return service.detail(restaurantId,orderId); }
    @PostMapping("/{orderId}/accept") public OrderResponse accept(@PathVariable UUID restaurantId,@PathVariable UUID orderId,@Valid @RequestBody Accept r) { return service.accept(restaurantId,orderId,r); }
    @PostMapping("/{orderId}/reject") public OrderResponse reject(@PathVariable UUID restaurantId,@PathVariable UUID orderId,@Valid @RequestBody Reject r) { return service.reject(restaurantId,orderId,r); }
    @PostMapping("/{orderId}/ready") public OrderResponse ready(@PathVariable UUID restaurantId,@PathVariable UUID orderId) { return service.ready(restaurantId,orderId); }
}
