package com.mealgo.monolith.restaurant.repository;
import com.mealgo.monolith.restaurant.entity.MenuItem;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;
public interface MenuItemRepository extends JpaRepository<MenuItem, UUID> {
    List<MenuItem> findByRestaurantId(UUID restaurantId);
    List<MenuItem> findByRestaurantIdAndAvailableTrueOrderByNameAscIdAsc(UUID restaurantId);
}
