package com.mealgo.monolith.customer.service;

import com.mealgo.monolith.common.exception.ApiException;
import com.mealgo.monolith.common.security.CurrentUser;
import com.mealgo.monolith.customer.dto.CartDtos.*;
import com.mealgo.monolith.customer.entity.CartItem;
import com.mealgo.monolith.customer.repository.CartItemRepository;
import com.mealgo.monolith.restaurant.repository.MenuItemRepository;
import com.mealgo.monolith.restaurant.repository.RestaurantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.util.*;

@Service @RequiredArgsConstructor
public class CartService {
    private final CartItemRepository carts;
    private final MenuItemRepository menu;
    private final RestaurantRepository restaurants;
    private final CurrentUser current;
    private final com.mealgo.monolith.auth.repository.UserAccountRepository users;

    private void lock() { users.findLockedById(current.id()).orElseThrow(() -> ApiException.notFound("Customer not found")); }

    @Transactional(readOnly=true)
    public Cart get() {
        var items = new ArrayList<Item>();
        UUID restaurantId = null;
        BigDecimal subtotal = BigDecimal.ZERO;
        for (var row : carts.findByCustomerIdOrderById(current.id())) {
            var product = menu.findById(row.getMenuItemId()).orElseThrow(() -> ApiException.conflict("Cart contains a removed menu item; remove it before ordering"));
            restaurantId = product.getRestaurantId();
            var line = product.getPrice().multiply(BigDecimal.valueOf(row.getQuantity()));
            subtotal = subtotal.add(line);
            items.add(new Item(product.getId(), product.getName(), row.getQuantity(), row.getNote(), product.getPrice(), line, product.isAvailable()));
        }
        var fee = items.isEmpty() ? BigDecimal.ZERO : new BigDecimal("15000");
        return new Cart(restaurantId, items, subtotal, fee, subtotal.add(fee));
    }

    @Transactional
    public Cart add(AddItem request) {
        lock();
        var product = menu.findById(request.menuItemId()).orElseThrow(() -> ApiException.notFound("Menu item not found"));
        var restaurant = restaurants.findById(product.getRestaurantId()).orElseThrow(() -> ApiException.notFound("Restaurant not found"));
        if (!product.isAvailable() || !restaurant.isAcceptingOrders()) throw ApiException.conflict("Menu item or restaurant unavailable");
        var existing = carts.findByCustomerIdOrderById(current.id());
        for (var row : existing) {
            var other = menu.findById(row.getMenuItemId()).orElseThrow(() -> ApiException.conflict("Remove unavailable cart items first"));
            if (!other.getRestaurantId().equals(product.getRestaurantId())) throw ApiException.conflict("Cart supports one restaurant; clear it before adding items from another restaurant");
        }
        var row = carts.findByCustomerIdAndMenuItemId(current.id(), product.getId()).orElseGet(CartItem::new);
        if (row.getId() == null && existing.size() >= 50) throw ApiException.conflict("Cart supports at most 50 items");
        int quantity = row.getQuantity() + request.quantity();
        if (quantity > 100) throw ApiException.badRequest("Maximum quantity is 100 per item");
        row.setCustomerId(current.id()); row.setMenuItemId(product.getId()); row.setQuantity(quantity); row.setNote(request.note());
        carts.saveAndFlush(row);
        return get();
    }

    @Transactional
    public Cart update(UUID menuItemId, UpdateItem request) {
        lock();
        var row = carts.findByCustomerIdAndMenuItemId(current.id(),menuItemId).orElseThrow(() -> ApiException.notFound("Cart item not found"));
        row.setQuantity(request.quantity()); row.setNote(request.note());
        return get();
    }

    @Transactional
    public void remove(UUID menuItemId) {
        lock();
        carts.findByCustomerIdAndMenuItemId(current.id(),menuItemId).ifPresent(carts::delete);
    }

    @Transactional
    public void clear() { lock(); carts.deleteByCustomerId(current.id()); }
}
