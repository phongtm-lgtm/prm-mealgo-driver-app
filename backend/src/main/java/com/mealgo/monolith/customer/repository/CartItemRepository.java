package com.mealgo.monolith.customer.repository;

import com.mealgo.monolith.customer.entity.CartItem;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface CartItemRepository extends JpaRepository<CartItem,UUID> {
    List<CartItem> findByCustomerIdOrderById(UUID customerId);
    Optional<CartItem> findByCustomerIdAndMenuItemId(UUID customerId, UUID menuItemId);
    void deleteByCustomerId(UUID customerId);
}
