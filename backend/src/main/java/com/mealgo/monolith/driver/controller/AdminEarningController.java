package com.mealgo.monolith.driver.controller;
import com.mealgo.monolith.driver.service.DriverAccountService;
import com.mealgo.monolith.driver.entity.PendingDriverEarning;
import com.mealgo.monolith.common.dto.PageResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/admin/driver-earnings") @RequiredArgsConstructor @PreAuthorize("hasRole('ADMIN')")
public class AdminEarningController {
    private final DriverAccountService service;
    public record Resolution(@NotNull @DecimalMin("1") @Digits(integer=12,fraction=0) BigDecimal amount) {}
    @GetMapping("/pending") public PageResponse<PendingDriverEarning> pending(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return service.pending(page,size); }
    @PostMapping("/{deliveryId}/reconcile") public void reconcile(@PathVariable UUID deliveryId,@Valid @RequestBody Resolution r) { service.reconcile(deliveryId,r.amount()); }
}
