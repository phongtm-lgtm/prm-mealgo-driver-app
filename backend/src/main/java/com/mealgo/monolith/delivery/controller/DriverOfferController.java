package com.mealgo.monolith.delivery.controller;
import com.mealgo.monolith.delivery.dto.DeliveryDtos.Offer;
import com.mealgo.monolith.delivery.dto.DeliveryDtos.RefreshOffers;
import jakarta.validation.Valid;
import com.mealgo.monolith.delivery.service.DeliveryService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.*;
@RestController @RequestMapping("/api/v1/drivers/me/offers") @RequiredArgsConstructor @PreAuthorize("hasRole('DRIVER')")
public class DriverOfferController {
    private final DeliveryService service;
    @GetMapping public List<Offer> list() { return service.offers(); }
    @PostMapping("/refresh") public List<Offer> refresh(@Valid @RequestBody RefreshOffers request) {
        return service.refreshOffers(request.skippedAssignmentIds());
    }
    @GetMapping("/{id}") public Offer get(@PathVariable UUID id) { return service.offer(id); }
    @PostMapping("/{id}/accept") public Offer accept(@PathVariable UUID id) { return service.respond(id,true); }
    @PostMapping("/{id}/reject") public Offer reject(@PathVariable UUID id) { return service.respond(id,false); }
}
