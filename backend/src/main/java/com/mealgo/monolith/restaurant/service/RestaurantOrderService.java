package com.mealgo.monolith.restaurant.service;
import com.mealgo.monolith.common.dto.PageResponse;
import com.mealgo.monolith.common.exception.ApiException;
import com.mealgo.monolith.common.security.CurrentUser;
import com.mealgo.monolith.order.enums.OrderStatus;
import com.mealgo.monolith.order.dto.OrderResponse;
import com.mealgo.monolith.order.entity.Order;
import com.mealgo.monolith.order.mapper.OrderMapper;
import com.mealgo.monolith.order.repository.OrderRepository;
import com.mealgo.monolith.order.service.OrderService;
import com.mealgo.monolith.restaurant.dto.RestaurantOrderDtos.*;
import com.mealgo.monolith.restaurant.repository.RestaurantRepository;
import com.mealgo.monolith.delivery.service.DeliveryService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.util.UUID;
@Service @RequiredArgsConstructor
public class RestaurantOrderService {
    private final RestaurantRepository restaurants;
    private final OrderRepository repository;
    private final OrderService orders;
    private final DeliveryService deliveries;
    private final OrderMapper mapper;
    private final CurrentUser current;
    @Transactional(readOnly=true) public PageResponse<OrderResponse> list(UUID restaurantId,OrderStatus status,int page,int size) {
        authorize(restaurantId); PageResponse.validate(page,size);
        var pageable = PageRequest.of(page,size,Sort.by("createdAt").descending());
        var result = status==null ? repository.findByRestaurantId(restaurantId,pageable) : repository.findByRestaurantIdAndStatus(restaurantId,status,pageable);
        return PageResponse.from(result.map(mapper::toResponse));
    }
    @Transactional(readOnly=true) public Detail detail(UUID restaurantId,UUID orderId) {
        authorize(restaurantId); var o = orders.get(orderId); belongs(o,restaurantId);
        return deliveries.restaurantDetail(o);
    }
    @Transactional public OrderResponse accept(UUID restaurantId,UUID orderId,Accept r) {
        authorize(restaurantId); var o = orders.lock(orderId); belongs(o,restaurantId);
        if (o.getStatus()==OrderStatus.PREPARING) return mapper.toResponse(o);
        orders.require(o,OrderStatus.PENDING); o.setStatus(OrderStatus.PREPARING);
        o.setEstimatedReadyAt(Instant.now().plusSeconds(r.estimatedPreparationMinutes()*60L)); o.setUpdatedAt(Instant.now());
        deliveries.create(o);
        return mapper.toResponse(o);
    }
    @Transactional public OrderResponse reject(UUID restaurantId,UUID orderId,Reject r) {
        authorize(restaurantId); var o = orders.lock(orderId); belongs(o,restaurantId);
        if (o.getStatus()==OrderStatus.REJECTED) return mapper.toResponse(o);
        orders.require(o,OrderStatus.PENDING); o.setStatus(OrderStatus.REJECTED); o.setCancellationReason(r.reason()); o.setUpdatedAt(Instant.now());
        return mapper.toResponse(o);
    }
    @Transactional public OrderResponse ready(UUID restaurantId,UUID orderId) {
        authorize(restaurantId); var o = orders.lock(orderId); belongs(o,restaurantId);
        if (o.getStatus()==OrderStatus.READY) return mapper.toResponse(o);
        orders.require(o,OrderStatus.PREPARING); o.setStatus(OrderStatus.READY); o.setReadyAt(Instant.now()); o.setUpdatedAt(Instant.now());
        return mapper.toResponse(o);
    }
    private void authorize(UUID id) {
        var r = restaurants.findById(id).orElseThrow(() -> ApiException.notFound("Restaurant not found"));
        if (!r.getOwnerId().equals(current.id())) throw ApiException.notFound("Restaurant not found");
    }
    private void belongs(Order o,UUID restaurantId) {
        if (!o.getRestaurantId().equals(restaurantId)) throw ApiException.notFound("Order not found");
    }
}
