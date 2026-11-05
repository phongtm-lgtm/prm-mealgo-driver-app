package com.mealgo.monolith.restaurant.repository;
import com.mealgo.monolith.restaurant.entity.Restaurant;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
public interface RestaurantRepository extends JpaRepository<Restaurant, UUID> {
    Optional<Restaurant> findFirstByOwnerIdAndNameOrderById(UUID ownerId, String name);
    List<Restaurant> findByNameIgnoreCaseAndAcceptingOrdersTrueOrderById(String name);
}
