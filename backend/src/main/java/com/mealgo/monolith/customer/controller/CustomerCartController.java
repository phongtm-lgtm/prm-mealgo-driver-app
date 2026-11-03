package com.mealgo.monolith.customer.controller;

import com.mealgo.monolith.customer.dto.CartDtos.*;
import com.mealgo.monolith.customer.service.CartService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.UUID;

@RestController @RequestMapping("/api/v1/customers/me/cart")
@RequiredArgsConstructor @PreAuthorize("hasRole('CUSTOMER')")
public class CustomerCartController {
    private final CartService carts;
    @GetMapping public Cart get() { return carts.get(); }
    @PostMapping("/items") public Cart add(@Valid @RequestBody AddItem r) { return carts.add(r); }
    @PutMapping("/items/{menuItemId}") public Cart update(@PathVariable UUID menuItemId,@Valid @RequestBody UpdateItem r) { return carts.update(menuItemId,r); }
    @DeleteMapping("/items/{menuItemId}") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remove(@PathVariable UUID menuItemId) { carts.remove(menuItemId); }
    @DeleteMapping @ResponseStatus(HttpStatus.NO_CONTENT) public void clear() { carts.clear(); }
}
