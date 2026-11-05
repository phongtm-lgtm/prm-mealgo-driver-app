package com.mealgo.monolith.customer.controller;

import com.mealgo.monolith.customer.dto.RestaurantMenu;
import com.mealgo.monolith.customer.service.CustomerMenuService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/v1/customers/menu")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerMenuController {
    private final CustomerMenuService menus;

    @GetMapping
    public List<RestaurantMenu> list(@RequestParam String restaurantName) {
        return menus.byRestaurantName(restaurantName);
    }
}
