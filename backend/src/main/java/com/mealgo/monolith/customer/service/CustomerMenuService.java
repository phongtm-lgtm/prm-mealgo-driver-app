package com.mealgo.monolith.customer.service;

import com.mealgo.monolith.common.exception.ApiException;
import com.mealgo.monolith.customer.dto.RestaurantMenu;
import com.mealgo.monolith.restaurant.repository.MenuItemRepository;
import com.mealgo.monolith.restaurant.repository.RestaurantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
@RequiredArgsConstructor
public class CustomerMenuService {
    private final RestaurantRepository restaurants;
    private final MenuItemRepository menu;

    @Transactional(readOnly = true)
    public List<RestaurantMenu> byRestaurantName(String restaurantName) {
        if (restaurantName.isBlank() || restaurantName.length() > 255) {
            throw ApiException.badRequest("Restaurant name must be 1 to 255 characters");
        }
        return restaurants.findByNameIgnoreCaseAndAcceptingOrdersTrueOrderById(restaurantName.strip()).stream()
                .map(r -> new RestaurantMenu(r.getId(), r.getName(), r.getLatitude(), r.getLongitude(),
                        menu.findByRestaurantIdAndAvailableTrueOrderByNameAscIdAsc(r.getId()).stream()
                                .map(i -> new RestaurantMenu.Dish(i.getId(), i.getName(), i.getPrice())).toList()))
                .toList();
    }
}
