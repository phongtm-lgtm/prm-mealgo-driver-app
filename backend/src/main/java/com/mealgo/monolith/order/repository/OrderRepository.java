package com.mealgo.monolith.order.repository;
import com.mealgo.monolith.order.entity.Order;
import com.mealgo.monolith.order.enums.OrderStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.*;
import java.util.*;
public interface OrderRepository extends JpaRepository<Order,UUID> {
    Optional<Order> findByCustomerIdAndIdempotencyKey(UUID customerId,String key);
    Page<Order> findByCustomerId(UUID customerId, Pageable pageable);
    Page<Order> findByRestaurantId(UUID restaurantId, Pageable pageable);
    Page<Order> findByRestaurantIdAndStatus(UUID restaurantId, OrderStatus status, Pageable pageable);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select o from Order o where o.id = :id")
    Optional<Order> findLockedById(UUID id);
}
