package com.mealgo.monolith.restaurant.repository;
import com.mealgo.monolith.restaurant.entity.Restaurant;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.UUID;
public interface RestaurantRepository extends JpaRepository<Restaurant, UUID> {}
