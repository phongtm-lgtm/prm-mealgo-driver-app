package com.mealgo.monolith.order.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mealgo.monolith.common.dto.PageResponse;
import com.mealgo.monolith.common.exception.ApiException;
import com.mealgo.monolith.common.security.CurrentUser;
import com.mealgo.monolith.customer.dto.request.*;
import com.mealgo.monolith.order.dto.OrderResponse;
import com.mealgo.monolith.order.entity.*;
import com.mealgo.monolith.order.enums.OrderStatus;
import com.mealgo.monolith.order.mapper.OrderMapper;
import com.mealgo.monolith.order.repository.OrderRepository;
import com.mealgo.monolith.restaurant.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.Instant;
import java.util.*;

@Service @RequiredArgsConstructor
public class OrderService {
    private final OrderRepository orders;
    private final RestaurantRepository restaurants;
    private final MenuItemRepository menu;
    private final CurrentUser current;
    private final OrderMapper mapper;
    private final ObjectMapper json;

    @Transactional
    public OrderResponse place(String key, PlaceOrderRequest request) {
        if (key == null || key.isBlank() || key.length()>100) throw ApiException.badRequest("Idempotency-Key is required, maximum 100 characters");
        String hash = hash(request);
        var existing = orders.findByCustomerIdAndIdempotencyKey(current.id(),key);
        if (existing.isPresent()) {
            if (!hash.equals(existing.get().getRequestHash())) throw ApiException.conflict("Idempotency-Key was used with different data");
            return mapper.toResponse(existing.get());
        }
        var restaurant = restaurants.findById(request.restaurantId()).orElseThrow(() -> ApiException.notFound("Restaurant not found"));
        if (!restaurant.isAcceptingOrders()) throw ApiException.conflict("Restaurant is not accepting orders");
        var o = new Order();
        o.setCustomerId(current.id()); o.setRestaurantId(restaurant.getId()); o.setIdempotencyKey(key); o.setRequestHash(hash);
        o.setRecipientName(request.recipient().name()); o.setRecipientPhone(request.recipient().phone());
        o.setDropoffAddress(request.dropoff().address()); o.setDropoffLatitude(request.dropoff().latitude()); o.setDropoffLongitude(request.dropoff().longitude());
        o.setPickupAddress(restaurant.getAddress()); o.setPickupLatitude(restaurant.getLatitude()); o.setPickupLongitude(restaurant.getLongitude());
        o.setRestaurantName(restaurant.getName()); o.setRestaurantPhone(restaurant.getPhone());
        o.setDeliveryNote(request.deliveryNote()); o.setPaymentMethod(request.paymentMethod().name());
        BigDecimal subtotal = BigDecimal.ZERO;
        for (var requested : request.items()) {
            var product = menu.findById(requested.menuItemId()).orElseThrow(() -> ApiException.notFound("Menu item not found"));
            if (!product.getRestaurantId().equals(restaurant.getId()) || !product.isAvailable())
                throw ApiException.conflict("Menu item unavailable or belongs to another restaurant");
            var item = new OrderItem(); item.setOrder(o); item.setMenuItemId(product.getId()); item.setName(product.getName());
            item.setQuantity(requested.quantity()); item.setUnitPrice(product.getPrice()); item.setNote(requested.note());
            o.getItems().add(item);
            subtotal = subtotal.add(product.getPrice().multiply(BigDecimal.valueOf(requested.quantity())));
        }
        o.setSubtotal(subtotal); o.setDeliveryFee(new BigDecimal("15000")); o.setTotal(subtotal.add(o.getDeliveryFee()));
        return mapper.toResponse(orders.save(o));
    }
    @Transactional(readOnly=true)
    public PageResponse<OrderResponse> mine(int page,int size) {
        PageResponse.validate(page,size);
        return PageResponse.from(orders.findByCustomerId(current.id(),PageRequest.of(page,size,Sort.by("createdAt").descending())).map(mapper::toResponse));
    }
    @Transactional(readOnly=true) public OrderResponse detail(UUID id) { return mapper.toResponse(myOrder(id)); }
    @Transactional(readOnly=true) public Order myOrder(UUID id) {
        var o = get(id);
        if (!o.getCustomerId().equals(current.id())) throw ApiException.notFound("Order not found");
        return o;
    }
    @Transactional public OrderResponse cancel(UUID id,CancelOrderRequest r) {
        var o = lock(id);
        if (!o.getCustomerId().equals(current.id())) throw ApiException.notFound("Order not found");
        if (o.getStatus()==OrderStatus.CANCELLED) return mapper.toResponse(o);
        require(o,OrderStatus.PENDING);
        o.setStatus(OrderStatus.CANCELLED); o.setCancellationReason(r.reason()); o.setUpdatedAt(Instant.now());
        return mapper.toResponse(o);
    }
    @Transactional(readOnly=true) public Order get(UUID id) { return orders.findById(id).orElseThrow(() -> ApiException.notFound("Order not found")); }
    @Transactional public Order lock(UUID id) { return orders.findLockedById(id).orElseThrow(() -> ApiException.notFound("Order not found")); }
    public void require(Order o,OrderStatus status) {
        if (o.getStatus()!=status) throw ApiException.conflict("Expected order status "+status+", actual "+o.getStatus());
    }
    private String hash(PlaceOrderRequest r) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(json.writeValueAsString(r).getBytes(StandardCharsets.UTF_8))); }
        catch (JsonProcessingException | NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }
}
